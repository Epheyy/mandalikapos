package services

import (
	"context"
	"fmt"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

type OutletService struct {
	db *database.DB
}

func NewOutletService(db *database.DB) *OutletService {
	return &OutletService{db: db}
}

func (s *OutletService) GetOutlets(ctx context.Context) ([]*models.Outlet, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, name, address, phone, is_active, created_at, updated_at
		FROM outlets ORDER BY name ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query outlets: %w", err)
	}
	defer rows.Close()

	var outlets []*models.Outlet
	for rows.Next() {
		o := &models.Outlet{}
		if err := rows.Scan(&o.ID, &o.Name, &o.Address, &o.Phone, &o.IsActive, &o.CreatedAt, &o.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan outlet: %w", err)
		}
		outlets = append(outlets, o)
	}
	return outlets, nil
}

func (s *OutletService) GetOutletByID(ctx context.Context, id uuid.UUID) (*models.Outlet, error) {
	o := &models.Outlet{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, name, address, phone, is_active, created_at, updated_at
		FROM outlets WHERE id=$1
	`, id).Scan(&o.ID, &o.Name, &o.Address, &o.Phone, &o.IsActive, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("outlet not found: %w", err)
	}
	return o, nil
}

func (s *OutletService) CreateOutlet(ctx context.Context, req *models.CreateOutletRequest) (*models.Outlet, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("outlet name is required")
	}
	isActive := true
	if req.IsActive != nil {
		isActive = *req.IsActive
	}

	o := &models.Outlet{}
	err := s.db.Pool.QueryRow(ctx, `
		INSERT INTO outlets (name, address, phone, is_active)
		VALUES ($1, $2, $3, $4)
		RETURNING id, name, address, phone, is_active, created_at, updated_at
	`, req.Name, req.Address, req.Phone, isActive).Scan(
		&o.ID, &o.Name, &o.Address, &o.Phone, &o.IsActive, &o.CreatedAt, &o.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create outlet: %w", err)
	}
	return o, nil
}

func (s *OutletService) UpdateOutlet(ctx context.Context, id uuid.UUID, req *models.UpdateOutletRequest) (*models.Outlet, error) {
	existing, err := s.GetOutletByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Address != nil {
		existing.Address = req.Address
	}
	if req.Phone != nil {
		existing.Phone = req.Phone
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}

	o := &models.Outlet{}
	err = s.db.Pool.QueryRow(ctx, `
		UPDATE outlets SET name=$1, address=$2, phone=$3, is_active=$4, updated_at=NOW()
		WHERE id=$5
		RETURNING id, name, address, phone, is_active, created_at, updated_at
	`, existing.Name, existing.Address, existing.Phone, existing.IsActive, id).Scan(
		&o.ID, &o.Name, &o.Address, &o.Phone, &o.IsActive, &o.CreatedAt, &o.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to update outlet: %w", err)
	}
	return o, nil
}

func (s *OutletService) DeleteOutlet(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.Pool.Exec(ctx, `UPDATE outlets SET is_active=false, updated_at=NOW() WHERE id=$1`, id)
	if err != nil {
		return fmt.Errorf("failed to deactivate outlet: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("outlet not found")
	}
	return nil
}
