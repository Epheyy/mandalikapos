package models

import (
	"time"

	"github.com/google/uuid"
)

type StockCount struct {
	ID          uuid.UUID        `json:"id"`
	Name        string           `json:"name"`
	Status      string           `json:"status"`
	OutletID    uuid.UUID        `json:"outlet_id"`
	CreatedBy   uuid.UUID        `json:"created_by"`
	PlannedDate string           `json:"planned_date"`
	StartedAt   *time.Time       `json:"started_at,omitempty"`
	CompletedAt *time.Time       `json:"completed_at,omitempty"`
	Notes       *string          `json:"notes,omitempty"`
	Items       []StockCountItem `json:"items,omitempty"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
}

type StockCountItem struct {
	ID           uuid.UUID `json:"id"`
	StockCountID uuid.UUID `json:"stock_count_id"`
	ProductID    uuid.UUID `json:"product_id"`
	VariantID    uuid.UUID `json:"variant_id"`
	ProductName  string    `json:"product_name"`
	VariantSize  string    `json:"variant_size"`
	SKU          *string   `json:"sku,omitempty"`
	FrozenQty    int       `json:"frozen_qty"`
	ActualQty    *int      `json:"actual_qty,omitempty"`
	Difference   *int      `json:"difference,omitempty"`
}

type CreateStockCountRequest struct {
	Name        string  `json:"name"`
	OutletID    string  `json:"outlet_id"`
	PlannedDate string  `json:"planned_date"`
	Notes       *string `json:"notes,omitempty"`
}

type UpdateStockCountItemRequest struct {
	ActualQty int `json:"actual_qty"`
}
