package services

import (
	"context"
	"fmt"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

type ShiftService struct {
	db *database.DB
}

func NewShiftService(db *database.DB) *ShiftService {
	return &ShiftService{db: db}
}

func (s *ShiftService) GetCurrentShift(ctx context.Context, cashierID uuid.UUID) (*models.Shift, error) {
	sh := &models.Shift{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT s.id, s.outlet_id, o.name, s.cashier_id, u.display_name,
		       s.status, s.opened_at, s.closed_at, s.starting_cash, s.closing_cash,
		       s.total_sales, s.total_orders, s.total_refunds,
		       s.cash_sales, s.card_sales, s.transfer_sales, s.qris_sales
		FROM shifts s
		JOIN outlets o ON o.id = s.outlet_id
		JOIN users u ON u.id = s.cashier_id
		WHERE s.cashier_id = $1 AND s.status = 'open'
		ORDER BY s.opened_at DESC LIMIT 1
	`, cashierID).Scan(
		&sh.ID, &sh.OutletID, &sh.OutletName, &sh.CashierID, &sh.CashierName,
		&sh.Status, &sh.OpenedAt, &sh.ClosedAt, &sh.StartingCash, &sh.ClosingCash,
		&sh.TotalSales, &sh.TotalOrders, &sh.TotalRefunds,
		&sh.CashSales, &sh.CardSales, &sh.TransferSales, &sh.QrisSales,
	)
	if err != nil {
		return nil, fmt.Errorf("no open shift found: %w", err)
	}
	return sh, nil
}

func (s *ShiftService) OpenShift(ctx context.Context, cashierID uuid.UUID, req *models.OpenShiftRequest) (*models.Shift, error) {
	// Prevent double-opening
	existing, _ := s.GetCurrentShift(ctx, cashierID)
	if existing != nil {
		return existing, nil
	}

	outletID, err := uuid.Parse(req.OutletID)
	if err != nil {
		// Use first outlet
		err = s.db.Pool.QueryRow(ctx, `SELECT id FROM outlets LIMIT 1`).Scan(&outletID)
		if err != nil {
			return nil, fmt.Errorf("no outlet found: %w", err)
		}
	}

	sh := &models.Shift{}
	err = s.db.Pool.QueryRow(ctx, `
		INSERT INTO shifts (outlet_id, cashier_id, starting_cash)
		VALUES ($1, $2, $3)
		RETURNING id, outlet_id, cashier_id, status, opened_at, starting_cash,
		    total_sales, total_orders, total_refunds, cash_sales, card_sales, transfer_sales, qris_sales
	`, outletID, cashierID, req.StartingCash).Scan(
		&sh.ID, &sh.OutletID, &sh.CashierID, &sh.Status, &sh.OpenedAt, &sh.StartingCash,
		&sh.TotalSales, &sh.TotalOrders, &sh.TotalRefunds,
		&sh.CashSales, &sh.CardSales, &sh.TransferSales, &sh.QrisSales,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to open shift: %w", err)
	}
	return sh, nil
}

func (s *ShiftService) CloseShift(ctx context.Context, cashierID uuid.UUID, req *models.CloseShiftRequest) (*models.Shift, error) {
	existing, err := s.GetCurrentShift(ctx, cashierID)
	if err != nil {
		return nil, fmt.Errorf("no open shift to close: %w", err)
	}

	// Aggregate order totals for this shift
	var totalSales int64
	var totalOrders int
	var cashSales, cardSales, transferSales, qrisSales int64
	s.db.Pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(total),0), COUNT(*),
		       COALESCE(SUM(CASE WHEN payment_method='cash' THEN total ELSE 0 END),0),
		       COALESCE(SUM(CASE WHEN payment_method='card' THEN total ELSE 0 END),0),
		       COALESCE(SUM(CASE WHEN payment_method='transfer' THEN total ELSE 0 END),0),
		       COALESCE(SUM(CASE WHEN payment_method='qris' THEN total ELSE 0 END),0)
		FROM orders WHERE shift_id=$1 AND status='completed'
	`, existing.ID).Scan(&totalSales, &totalOrders, &cashSales, &cardSales, &transferSales, &qrisSales)

	sh := &models.Shift{}
	err = s.db.Pool.QueryRow(ctx, `
		UPDATE shifts SET
		    status='closed', closed_at=NOW(), closing_cash=$1,
		    total_sales=$2, total_orders=$3,
		    cash_sales=$4, card_sales=$5, transfer_sales=$6, qris_sales=$7
		WHERE id=$8
		RETURNING id, outlet_id, cashier_id, status, opened_at, closed_at,
		    starting_cash, closing_cash, total_sales, total_orders, total_refunds,
		    cash_sales, card_sales, transfer_sales, qris_sales
	`, req.ClosingCash, totalSales, totalOrders, cashSales, cardSales, transferSales, qrisSales, existing.ID,
	).Scan(
		&sh.ID, &sh.OutletID, &sh.CashierID, &sh.Status, &sh.OpenedAt, &sh.ClosedAt,
		&sh.StartingCash, &sh.ClosingCash, &sh.TotalSales, &sh.TotalOrders, &sh.TotalRefunds,
		&sh.CashSales, &sh.CardSales, &sh.TransferSales, &sh.QrisSales,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to close shift: %w", err)
	}
	return sh, nil
}

func (s *ShiftService) GetShifts(ctx context.Context) ([]*models.Shift, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT s.id, s.outlet_id, o.name, s.cashier_id, u.display_name,
		       s.status, s.opened_at, s.closed_at, s.starting_cash, s.closing_cash,
		       s.total_sales, s.total_orders, s.total_refunds,
		       s.cash_sales, s.card_sales, s.transfer_sales, s.qris_sales
		FROM shifts s
		JOIN outlets o ON o.id = s.outlet_id
		JOIN users u ON u.id = s.cashier_id
		ORDER BY s.opened_at DESC
		LIMIT 100
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query shifts: %w", err)
	}
	defer rows.Close()

	var shifts []*models.Shift
	for rows.Next() {
		sh := &models.Shift{}
		if err := rows.Scan(
			&sh.ID, &sh.OutletID, &sh.OutletName, &sh.CashierID, &sh.CashierName,
			&sh.Status, &sh.OpenedAt, &sh.ClosedAt, &sh.StartingCash, &sh.ClosingCash,
			&sh.TotalSales, &sh.TotalOrders, &sh.TotalRefunds,
			&sh.CashSales, &sh.CardSales, &sh.TransferSales, &sh.QrisSales,
		); err != nil {
			return nil, err
		}
		shifts = append(shifts, sh)
	}
	return shifts, nil
}
