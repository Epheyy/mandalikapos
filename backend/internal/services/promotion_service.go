package services

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

type PromotionService struct {
	db *database.DB
}

func NewPromotionService(db *database.DB) *PromotionService {
	return &PromotionService{db: db}
}

// ── Promotions ───────────────────────────────────────────────────

func (s *PromotionService) GetPromotions(ctx context.Context) ([]*models.Promotion, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, name, description, type, value, min_purchase, combinable,
		       active_from_hour, active_to_hour, is_active,
		       to_char(start_date,'YYYY-MM-DD'), to_char(end_date,'YYYY-MM-DD'), created_at
		FROM promotions ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query promotions: %w", err)
	}
	defer rows.Close()

	var promotions []*models.Promotion
	for rows.Next() {
		p := &models.Promotion{}
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.Type, &p.Value, &p.MinPurchase,
			&p.Combinable, &p.ActiveFromHour, &p.ActiveToHour, &p.IsActive,
			&p.StartDate, &p.EndDate, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan promotion: %w", err)
		}
		s.loadPromotionRelations(ctx, p)
		promotions = append(promotions, p)
	}
	return promotions, nil
}

func (s *PromotionService) GetActivePromotions(ctx context.Context) ([]*models.Promotion, error) {
	now := time.Now()
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, name, description, type, value, min_purchase, combinable,
		       active_from_hour, active_to_hour, is_active,
		       to_char(start_date,'YYYY-MM-DD'), to_char(end_date,'YYYY-MM-DD'), created_at
		FROM promotions
		WHERE is_active = true
		  AND (start_date IS NULL OR start_date <= $1)
		  AND (end_date IS NULL OR end_date >= $1)
		ORDER BY created_at DESC
	`, now)
	if err != nil {
		return nil, fmt.Errorf("failed to query active promotions: %w", err)
	}
	defer rows.Close()

	var promotions []*models.Promotion
	for rows.Next() {
		p := &models.Promotion{}
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.Type, &p.Value, &p.MinPurchase,
			&p.Combinable, &p.ActiveFromHour, &p.ActiveToHour, &p.IsActive,
			&p.StartDate, &p.EndDate, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan promotion: %w", err)
		}
		s.loadPromotionRelations(ctx, p)
		promotions = append(promotions, p)
	}
	return promotions, nil
}

func (s *PromotionService) loadPromotionRelations(ctx context.Context, p *models.Promotion) {
	// Load active days
	rows, err := s.db.Pool.Query(ctx, `SELECT day_of_week FROM promotion_active_days WHERE promotion_id=$1`, p.ID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var day int
			if rows.Scan(&day) == nil {
				p.ActiveDays = append(p.ActiveDays, day)
			}
		}
	}

	// Load product IDs
	prows, err := s.db.Pool.Query(ctx, `SELECT product_id::text FROM promotion_products WHERE promotion_id=$1`, p.ID)
	if err == nil {
		defer prows.Close()
		seen := map[string]bool{}
		for prows.Next() {
			var pid string
			if prows.Scan(&pid) == nil && !seen[pid] {
				p.ProductIDs = append(p.ProductIDs, pid)
				seen[pid] = true
			}
		}
	}
}

func (s *PromotionService) CreatePromotion(ctx context.Context, req *models.CreatePromotionRequest) (*models.Promotion, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("promotion name is required")
	}
	validTypes := map[string]bool{"percentage": true, "fixed": true, "bogo": true}
	if !validTypes[req.Type] {
		return nil, fmt.Errorf("invalid promotion type: %s", req.Type)
	}

	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	p := &models.Promotion{}
	err = tx.QueryRow(ctx, `
		INSERT INTO promotions (name, description, type, value, min_purchase, combinable,
		    active_from_hour, active_to_hour, is_active, start_date, end_date)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		RETURNING id, name, description, type, value, min_purchase, combinable,
		    active_from_hour, active_to_hour, is_active,
		    to_char(start_date,'YYYY-MM-DD'), to_char(end_date,'YYYY-MM-DD'), created_at
	`, req.Name, req.Description, req.Type, req.Value, req.MinPurchase, req.Combinable,
		req.ActiveFromHour, req.ActiveToHour, req.IsActive, req.StartDate, req.EndDate,
	).Scan(&p.ID, &p.Name, &p.Description, &p.Type, &p.Value, &p.MinPurchase, &p.Combinable,
		&p.ActiveFromHour, &p.ActiveToHour, &p.IsActive, &p.StartDate, &p.EndDate, &p.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create promotion: %w", err)
	}

	for _, day := range req.ActiveDays {
		if _, err := tx.Exec(ctx, `INSERT INTO promotion_active_days VALUES($1,$2) ON CONFLICT DO NOTHING`, p.ID, day); err != nil {
			return nil, fmt.Errorf("failed to insert active day: %w", err)
		}
	}

	for _, productID := range req.ProductIDs {
		variantSize := ""
		if len(req.VariantSizes) > 0 {
			variantSize = strings.Join(req.VariantSizes, ",")
		}
		if _, err := tx.Exec(ctx, `INSERT INTO promotion_products VALUES($1,$2,$3) ON CONFLICT DO NOTHING`,
			p.ID, productID, variantSize); err != nil {
			return nil, fmt.Errorf("failed to insert promotion product: %w", err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit: %w", err)
	}

	p.ActiveDays = req.ActiveDays
	p.ProductIDs = req.ProductIDs
	return p, nil
}

func (s *PromotionService) DeletePromotion(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.Pool.Exec(ctx, `UPDATE promotions SET is_active=false, updated_at=NOW() WHERE id=$1`, id)
	if err != nil {
		return fmt.Errorf("failed to deactivate promotion: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("promotion not found")
	}
	return nil
}

// ── Discount Codes ───────────────────────────────────────────────

func (s *PromotionService) GetDiscountCodes(ctx context.Context) ([]*models.DiscountCode, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, code, type, value, min_purchase, usage_limit, usage_count, is_active,
		       to_char(start_date,'YYYY-MM-DD'), to_char(end_date,'YYYY-MM-DD'), created_at
		FROM discount_codes ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query discount codes: %w", err)
	}
	defer rows.Close()

	var codes []*models.DiscountCode
	for rows.Next() {
		c := &models.DiscountCode{}
		if err := rows.Scan(&c.ID, &c.Code, &c.Type, &c.Value, &c.MinPurchase,
			&c.UsageLimit, &c.UsageCount, &c.IsActive, &c.StartDate, &c.EndDate, &c.CreatedAt); err != nil {
			return nil, err
		}
		codes = append(codes, c)
	}
	return codes, nil
}

func (s *PromotionService) CreateDiscountCode(ctx context.Context, req *models.CreateDiscountCodeRequest) (*models.DiscountCode, error) {
	if req.Code == "" {
		return nil, fmt.Errorf("code is required")
	}
	c := &models.DiscountCode{}
	err := s.db.Pool.QueryRow(ctx, `
		INSERT INTO discount_codes (code, type, value, min_purchase, usage_limit, is_active, start_date, end_date)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		RETURNING id, code, type, value, min_purchase, usage_limit, usage_count, is_active,
		    to_char(start_date,'YYYY-MM-DD'), to_char(end_date,'YYYY-MM-DD'), created_at
	`, req.Code, req.Type, req.Value, req.MinPurchase, req.UsageLimit, req.IsActive, req.StartDate, req.EndDate,
	).Scan(&c.ID, &c.Code, &c.Type, &c.Value, &c.MinPurchase,
		&c.UsageLimit, &c.UsageCount, &c.IsActive, &c.StartDate, &c.EndDate, &c.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create discount code: %w", err)
	}
	return c, nil
}

func (s *PromotionService) DeleteDiscountCode(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.Pool.Exec(ctx, `DELETE FROM discount_codes WHERE id=$1`, id)
	if err != nil {
		return fmt.Errorf("failed to delete discount code: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("discount code not found")
	}
	return nil
}

func (s *PromotionService) ValidateDiscountCode(ctx context.Context, req *models.ValidateDiscountCodeRequest) (*models.ValidateDiscountCodeResponse, error) {
	now := time.Now()
	c := &models.DiscountCode{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, code, type, value, min_purchase, usage_limit, usage_count, is_active
		FROM discount_codes WHERE code = $1
	`, strings.ToUpper(req.Code)).Scan(&c.ID, &c.Code, &c.Type, &c.Value, &c.MinPurchase,
		&c.UsageLimit, &c.UsageCount, &c.IsActive)
	if err != nil {
		return &models.ValidateDiscountCodeResponse{Valid: false, Message: "Kode tidak ditemukan"}, nil
	}

	if !c.IsActive {
		return &models.ValidateDiscountCodeResponse{Valid: false, Message: "Kode sudah tidak aktif"}, nil
	}
	if c.UsageLimit != nil && c.UsageCount >= *c.UsageLimit {
		return &models.ValidateDiscountCodeResponse{Valid: false, Message: "Kode sudah habis digunakan"}, nil
	}
	if req.Subtotal < c.MinPurchase {
		return &models.ValidateDiscountCodeResponse{Valid: false, Message: fmt.Sprintf("Minimum pembelian Rp %d", c.MinPurchase)}, nil
	}

	_ = now
	var discountAmount int64
	if c.Type == "percentage" {
		discountAmount = req.Subtotal * c.Value / 100
	} else {
		discountAmount = c.Value
		if discountAmount > req.Subtotal {
			discountAmount = req.Subtotal
		}
	}

	return &models.ValidateDiscountCodeResponse{Valid: true, DiscountAmount: discountAmount}, nil
}
