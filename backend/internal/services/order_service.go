package services

import (
	"context"
	"fmt"
	"math/rand"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

type OrderService struct {
	db *database.DB
}

func NewOrderService(db *database.DB) *OrderService {
	return &OrderService{db: db}
}

// CreateOrder saves a completed order and decrements stock atomically.
func (s *OrderService) CreateOrder(
	ctx context.Context,
	req *models.CreateOrderRequest,
	cashierID uuid.UUID,
	cashierName string,
) (*models.Order, error) {

	// Validate payment method
	validMethods := map[string]bool{
		"cash": true, "card": true, "transfer": true, "qris": true,
	}
	if !validMethods[req.PaymentMethod] {
		return nil, fmt.Errorf("invalid payment method: %s", req.PaymentMethod)
	}
	if len(req.Items) == 0 {
		return nil, fmt.Errorf("order must have at least one item")
	}

	// Parse outlet ID — use default if empty
	outletID := uuid.New() // will be replaced below
	if req.OutletID != "" {
		parsed, err := uuid.Parse(req.OutletID)
		if err == nil {
			outletID = parsed
		}
	}

	// Find or create default outlet
	var outletExists bool
	err := s.db.Pool.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM outlets WHERE id = $1)", outletID,
	).Scan(&outletExists)
	if err != nil || !outletExists {
		// Use first available outlet
		err = s.db.Pool.QueryRow(ctx,
			"SELECT id FROM outlets LIMIT 1",
		).Scan(&outletID)
		if err != nil {
			// Create a default outlet
			outletID = uuid.New()
			_, err = s.db.Pool.Exec(ctx, `
				INSERT INTO outlets (id, name, is_active, created_at, updated_at)
				VALUES ($1, 'Default Outlet', true, NOW(), NOW())
			`, outletID)
			if err != nil {
				return nil, fmt.Errorf("failed to create default outlet: %w", err)
			}
		}
	}

	orderID := uuid.New()
	orderNumber := generateOrderNumber()
	now := time.Now()

	// Parse optional customer ID
	var customerID *uuid.UUID
	if req.CustomerID != nil && *req.CustomerID != "" {
		parsed, err := uuid.Parse(*req.CustomerID)
		if err == nil {
			customerID = &parsed
		}
	}

	// Use a transaction — order + items + stock decrement must all succeed or all fail
	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Insert the order
	_, err = tx.Exec(ctx, `
		INSERT INTO orders (
			id, order_number, outlet_id, cashier_id, customer_id,
			subtotal, discount_amount, tax_amount, surcharge_amount,
			total, payment_method, amount_paid, change_amount,
			status, notes, created_at
		) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
	`,
		orderID, orderNumber, outletID, cashierID, customerID,
		req.Subtotal, req.DiscountAmount, req.TaxAmount, 0,
		req.Total, req.PaymentMethod, req.AmountPaid, req.ChangeAmount,
		"completed", req.Notes, now,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert order: %w", err)
	}

	// Insert order items and decrement stock
	for _, item := range req.Items {
		productID, err := uuid.Parse(item.ProductID)
		if err != nil {
			return nil, fmt.Errorf("invalid product_id: %s", item.ProductID)
		}
		variantID, err := uuid.Parse(item.VariantID)
		if err != nil {
			return nil, fmt.Errorf("invalid variant_id: %s", item.VariantID)
		}

		// Insert order item
		_, err = tx.Exec(ctx, `
			INSERT INTO order_items (id, order_id, product_id, variant_id,
				product_name, variant_size, price, quantity, subtotal, created_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		`,
			uuid.New(), orderID, productID, variantID,
			item.ProductName, item.VariantSize, item.Price,
			item.Quantity, item.Subtotal, now,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to insert order item: %w", err)
		}

		// Decrement stock — fail if not enough stock
		result, err := tx.Exec(ctx, `
			UPDATE product_variants
			SET stock = stock - $1, updated_at = NOW()
			WHERE id = $2 AND stock >= $1
		`, item.Quantity, variantID)
		if err != nil {
			return nil, fmt.Errorf("failed to update stock: %w", err)
		}
		if result.RowsAffected() == 0 {
			return nil, fmt.Errorf(
				"insufficient stock for %s %s", item.ProductName, item.VariantSize,
			)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Clear product cache so stock counts refresh
	return s.GetOrderByID(ctx, orderID)
}

// GetOrderByID returns a single order with its items.
func (s *OrderService) GetOrderByID(ctx context.Context, id uuid.UUID) (*models.Order, error) {
	order := &models.Order{}
	var customerID *uuid.UUID

	err := s.db.Pool.QueryRow(ctx, `
		SELECT o.id, o.order_number, o.outlet_id, o.cashier_id,
		       u.display_name, o.customer_id,
		       o.subtotal, o.discount_amount, o.tax_amount, o.surcharge_amount,
		       o.total, o.payment_method, o.amount_paid, o.change_amount,
		       o.status, o.notes, o.created_at
		FROM orders o
		JOIN users u ON u.id = o.cashier_id
		WHERE o.id = $1
	`, id).Scan(
		&order.ID, &order.OrderNumber, &order.OutletID, &order.CashierID,
		&order.CashierName, &customerID,
		&order.Subtotal, &order.DiscountAmount, &order.TaxAmount, &order.SurchargeAmount,
		&order.Total, &order.PaymentMethod, &order.AmountPaid, &order.ChangeAmount,
		&order.Status, &order.Notes, &order.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("order not found: %w", err)
	}
	order.CustomerID = customerID

	// Load items
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, order_id, product_id, variant_id,
		       product_name, variant_size, price, quantity, subtotal
		FROM order_items WHERE order_id = $1
	`, id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		item := models.OrderItem{}
		if err := rows.Scan(
			&item.ID, &item.OrderID, &item.ProductID, &item.VariantID,
			&item.ProductName, &item.VariantSize, &item.Price,
			&item.Quantity, &item.Subtotal,
		); err != nil {
			return nil, err
		}
		order.Items = append(order.Items, item)
	}
	return order, nil
}

// GetOrdersByDateRange returns orders within a date range for reporting.
func (s *OrderService) GetOrdersByDateRange(
	ctx context.Context,
	cashierID uuid.UUID,
	from, to time.Time,
) ([]*models.Order, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT o.id, o.order_number, o.total, o.payment_method,
		       o.status, o.created_at
		FROM orders o
		WHERE o.cashier_id = $1
		  AND o.created_at >= $2
		  AND o.created_at <= $3
		ORDER BY o.created_at DESC
	`, cashierID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []*models.Order
	for rows.Next() {
		o := &models.Order{}
		if err := rows.Scan(
			&o.ID, &o.OrderNumber, &o.Total, &o.PaymentMethod,
			&o.Status, &o.CreatedAt,
		); err != nil {
			return nil, err
		}
		orders = append(orders, o)
	}
	return orders, nil
}

func generateOrderNumber() string {
	return fmt.Sprintf("MND-%06d", rand.Intn(900000)+100000)
}
