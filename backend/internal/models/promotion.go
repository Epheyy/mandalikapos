package models

import (
	"time"

	"github.com/google/uuid"
)

type Promotion struct {
	ID              uuid.UUID `json:"id"`
	Name            string    `json:"name"`
	Description     *string   `json:"description,omitempty"`
	Type            string    `json:"type"`
	Value           int64     `json:"value"`
	MinPurchase     int64     `json:"min_purchase"`
	Combinable      bool      `json:"combinable"`
	ActiveFromHour  *string   `json:"active_from_hour,omitempty"`
	ActiveToHour    *string   `json:"active_to_hour,omitempty"`
	ActiveDays      []int     `json:"active_days,omitempty"`
	ProductIDs      []string  `json:"product_ids,omitempty"`
	VariantSizes    []string  `json:"variant_sizes,omitempty"`
	IsActive        bool      `json:"is_active"`
	StartDate       *string   `json:"start_date,omitempty"`
	EndDate         *string   `json:"end_date,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

type CreatePromotionRequest struct {
	Name           string   `json:"name"`
	Description    *string  `json:"description,omitempty"`
	Type           string   `json:"type"`
	Value          int64    `json:"value"`
	MinPurchase    int64    `json:"min_purchase"`
	Combinable     bool     `json:"combinable"`
	ActiveFromHour *string  `json:"active_from_hour,omitempty"`
	ActiveToHour   *string  `json:"active_to_hour,omitempty"`
	ActiveDays     []int    `json:"active_days,omitempty"`
	ProductIDs     []string `json:"product_ids,omitempty"`
	VariantSizes   []string `json:"variant_sizes,omitempty"`
	IsActive       bool     `json:"is_active"`
	StartDate      *string  `json:"start_date,omitempty"`
	EndDate        *string  `json:"end_date,omitempty"`
}

type DiscountCode struct {
	ID          uuid.UUID `json:"id"`
	Code        string    `json:"code"`
	Type        string    `json:"type"`
	Value       int64     `json:"value"`
	MinPurchase int64     `json:"min_purchase"`
	UsageLimit  *int      `json:"usage_limit,omitempty"`
	UsageCount  int       `json:"usage_count"`
	IsActive    bool      `json:"is_active"`
	StartDate   *string   `json:"start_date,omitempty"`
	EndDate     *string   `json:"end_date,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type CreateDiscountCodeRequest struct {
	Code        string  `json:"code"`
	Type        string  `json:"type"`
	Value       int64   `json:"value"`
	MinPurchase int64   `json:"min_purchase"`
	UsageLimit  *int    `json:"usage_limit,omitempty"`
	IsActive    bool    `json:"is_active"`
	StartDate   *string `json:"start_date,omitempty"`
	EndDate     *string `json:"end_date,omitempty"`
}

type ValidateDiscountCodeRequest struct {
	Code     string `json:"code"`
	Subtotal int64  `json:"subtotal"`
}

type ValidateDiscountCodeResponse struct {
	Valid          bool   `json:"valid"`
	DiscountAmount int64  `json:"discount_amount"`
	Message        string `json:"message,omitempty"`
}
