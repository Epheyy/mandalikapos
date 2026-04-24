package services

import (
	"context"
	"fmt"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

type CustomerService struct {
	db *database.DB
}

func NewCustomerService(db *database.DB) *CustomerService {
	return &CustomerService{db: db}
}

func (s *CustomerService) GetCustomers(ctx context.Context) ([]*models.Customer, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, name, phone, email, points, total_spent, visit_count, last_visit, created_at, updated_at
		FROM customers ORDER BY name ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query customers: %w", err)
	}
	defer rows.Close()

	var customers []*models.Customer
	for rows.Next() {
		c := &models.Customer{}
		if err := rows.Scan(&c.ID, &c.Name, &c.Phone, &c.Email, &c.Points, &c.TotalSpent,
			&c.VisitCount, &c.LastVisit, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan customer: %w", err)
		}
		customers = append(customers, c)
	}
	return customers, nil
}

func (s *CustomerService) GetCustomerByPhone(ctx context.Context, phone string) (*models.Customer, error) {
	c := &models.Customer{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, name, phone, email, points, total_spent, visit_count, last_visit, created_at, updated_at
		FROM customers WHERE phone = $1
	`, phone).Scan(&c.ID, &c.Name, &c.Phone, &c.Email, &c.Points, &c.TotalSpent,
		&c.VisitCount, &c.LastVisit, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("customer not found: %w", err)
	}
	return c, nil
}

func (s *CustomerService) GetCustomerByID(ctx context.Context, id uuid.UUID) (*models.Customer, error) {
	c := &models.Customer{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, name, phone, email, points, total_spent, visit_count, last_visit, created_at, updated_at
		FROM customers WHERE id = $1
	`, id).Scan(&c.ID, &c.Name, &c.Phone, &c.Email, &c.Points, &c.TotalSpent,
		&c.VisitCount, &c.LastVisit, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("customer not found: %w", err)
	}
	return c, nil
}

func (s *CustomerService) CreateCustomer(ctx context.Context, req *models.CreateCustomerRequest) (*models.Customer, error) {
	if req.Name == "" || req.Phone == "" {
		return nil, fmt.Errorf("name and phone are required")
	}

	c := &models.Customer{}
	err := s.db.Pool.QueryRow(ctx, `
		INSERT INTO customers (name, phone, email)
		VALUES ($1, $2, $3)
		RETURNING id, name, phone, email, points, total_spent, visit_count, last_visit, created_at, updated_at
	`, req.Name, req.Phone, req.Email).Scan(
		&c.ID, &c.Name, &c.Phone, &c.Email, &c.Points, &c.TotalSpent,
		&c.VisitCount, &c.LastVisit, &c.CreatedAt, &c.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create customer: %w", err)
	}
	return c, nil
}

func (s *CustomerService) UpdateCustomer(ctx context.Context, id uuid.UUID, req *models.UpdateCustomerRequest) (*models.Customer, error) {
	existing, err := s.GetCustomerByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Phone != nil {
		existing.Phone = *req.Phone
	}
	if req.Email != nil {
		existing.Email = req.Email
	}
	if req.Points != nil {
		existing.Points = *req.Points
	}

	c := &models.Customer{}
	err = s.db.Pool.QueryRow(ctx, `
		UPDATE customers SET name=$1, phone=$2, email=$3, points=$4, updated_at=NOW()
		WHERE id=$5
		RETURNING id, name, phone, email, points, total_spent, visit_count, last_visit, created_at, updated_at
	`, existing.Name, existing.Phone, existing.Email, existing.Points, id).Scan(
		&c.ID, &c.Name, &c.Phone, &c.Email, &c.Points, &c.TotalSpent,
		&c.VisitCount, &c.LastVisit, &c.CreatedAt, &c.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to update customer: %w", err)
	}
	return c, nil
}

func (s *CustomerService) DeleteCustomer(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.Pool.Exec(ctx, `DELETE FROM customers WHERE id=$1`, id)
	if err != nil {
		return fmt.Errorf("failed to delete customer: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("customer not found")
	}
	return nil
}

func (s *CustomerService) GetCustomerOrders(ctx context.Context, customerID uuid.UUID) ([]*models.Order, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT o.id, o.order_number, o.total, o.payment_method, o.status, o.created_at
		FROM orders o
		WHERE o.customer_id = $1
		ORDER BY o.created_at DESC
		LIMIT 50
	`, customerID)
	if err != nil {
		return nil, fmt.Errorf("failed to query customer orders: %w", err)
	}
	defer rows.Close()

	var orders []*models.Order
	for rows.Next() {
		o := &models.Order{}
		if err := rows.Scan(&o.ID, &o.OrderNumber, &o.Total, &o.PaymentMethod, &o.Status, &o.CreatedAt); err != nil {
			return nil, err
		}
		orders = append(orders, o)
	}
	return orders, nil
}
