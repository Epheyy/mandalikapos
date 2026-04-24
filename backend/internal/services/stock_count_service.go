package services

import (
	"context"
	"fmt"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

type StockCountService struct {
	db *database.DB
}

func NewStockCountService(db *database.DB) *StockCountService {
	return &StockCountService{db: db}
}

func (s *StockCountService) GetStockCounts(ctx context.Context) ([]*models.StockCount, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, name, status, outlet_id, created_by, to_char(planned_date,'YYYY-MM-DD'),
		       started_at, completed_at, notes, created_at, updated_at
		FROM stock_counts ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query stock counts: %w", err)
	}
	defer rows.Close()

	var counts []*models.StockCount
	for rows.Next() {
		sc := &models.StockCount{}
		if err := rows.Scan(&sc.ID, &sc.Name, &sc.Status, &sc.OutletID, &sc.CreatedBy,
			&sc.PlannedDate, &sc.StartedAt, &sc.CompletedAt, &sc.Notes,
			&sc.CreatedAt, &sc.UpdatedAt); err != nil {
			return nil, err
		}
		counts = append(counts, sc)
	}
	return counts, nil
}

func (s *StockCountService) GetStockCountByID(ctx context.Context, id uuid.UUID) (*models.StockCount, error) {
	sc := &models.StockCount{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, name, status, outlet_id, created_by, to_char(planned_date,'YYYY-MM-DD'),
		       started_at, completed_at, notes, created_at, updated_at
		FROM stock_counts WHERE id=$1
	`, id).Scan(&sc.ID, &sc.Name, &sc.Status, &sc.OutletID, &sc.CreatedBy,
		&sc.PlannedDate, &sc.StartedAt, &sc.CompletedAt, &sc.Notes,
		&sc.CreatedAt, &sc.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("stock count not found: %w", err)
	}

	// Load items
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, stock_count_id, product_id, variant_id, product_name, variant_size,
		       sku, frozen_qty, actual_qty, difference
		FROM stock_count_items WHERE stock_count_id=$1 ORDER BY product_name, variant_size
	`, id)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			item := models.StockCountItem{}
			if err := rows.Scan(&item.ID, &item.StockCountID, &item.ProductID, &item.VariantID,
				&item.ProductName, &item.VariantSize, &item.SKU, &item.FrozenQty,
				&item.ActualQty, &item.Difference); err == nil {
				sc.Items = append(sc.Items, item)
			}
		}
	}
	return sc, nil
}

func (s *StockCountService) CreateStockCount(ctx context.Context, createdBy uuid.UUID, req *models.CreateStockCountRequest) (*models.StockCount, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("stock count name is required")
	}
	outletID, err := uuid.Parse(req.OutletID)
	if err != nil {
		return nil, fmt.Errorf("invalid outlet ID: %w", err)
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	sc := &models.StockCount{}
	err = tx.QueryRow(ctx, `
		INSERT INTO stock_counts (name, outlet_id, created_by, planned_date, notes)
		VALUES ($1, $2, $3, $4::date, $5)
		RETURNING id, name, status, outlet_id, created_by, to_char(planned_date,'YYYY-MM-DD'),
		    started_at, completed_at, notes, created_at, updated_at
	`, req.Name, outletID, createdBy, req.PlannedDate, req.Notes).Scan(
		&sc.ID, &sc.Name, &sc.Status, &sc.OutletID, &sc.CreatedBy,
		&sc.PlannedDate, &sc.StartedAt, &sc.CompletedAt, &sc.Notes,
		&sc.CreatedAt, &sc.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create stock count: %w", err)
	}

	// Snapshot current stock
	rows, err := tx.Query(ctx, `
		SELECT p.id, pv.id, p.name, pv.size, pv.sku, pv.stock
		FROM product_variants pv
		JOIN products p ON p.id = pv.product_id
		WHERE p.is_active = true
		ORDER BY p.name, pv.size
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to snapshot stock: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var productID, variantID uuid.UUID
		var productName, variantSize string
		var sku *string
		var frozenQty int
		if err := rows.Scan(&productID, &variantID, &productName, &variantSize, &sku, &frozenQty); err != nil {
			continue
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO stock_count_items (stock_count_id, product_id, variant_id, product_name, variant_size, sku, frozen_qty)
			VALUES ($1,$2,$3,$4,$5,$6,$7)
		`, sc.ID, productID, variantID, productName, variantSize, sku, frozenQty); err != nil {
			return nil, fmt.Errorf("failed to insert stock count item: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit: %w", err)
	}
	return s.GetStockCountByID(ctx, sc.ID)
}

func (s *StockCountService) UpdateItemActualQty(ctx context.Context, stockCountID, itemID uuid.UUID, actualQty int) error {
	diff := 0 // computed per item
	_, err := s.db.Pool.Exec(ctx, `
		UPDATE stock_count_items
		SET actual_qty=$1, difference=$1-frozen_qty, updated_at=NOW()
		WHERE id=$2 AND stock_count_id=$3
	`, actualQty, itemID, stockCountID)
	_ = diff
	if err != nil {
		return fmt.Errorf("failed to update item: %w", err)
	}
	return nil
}

func (s *StockCountService) UpdateStockCountStatus(ctx context.Context, id uuid.UUID, status string) (*models.StockCount, error) {
	var tsCol string
	switch status {
	case "in_progress":
		tsCol = ", started_at=NOW()"
	case "completed":
		tsCol = ", completed_at=NOW()"
	}

	_, err := s.db.Pool.Exec(ctx, fmt.Sprintf(`
		UPDATE stock_counts SET status=$1, updated_at=NOW()%s WHERE id=$2
	`, tsCol), status, id)
	if err != nil {
		return nil, fmt.Errorf("failed to update status: %w", err)
	}
	return s.GetStockCountByID(ctx, id)
}
