package models

import (
	"time"

	"github.com/google/uuid"
)

// Category represents a product category (e.g. Floral, Woody, Oriental).
type Category struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description,omitempty"`
	SortOrder   int       `json:"sort_order"`
	CreatedAt   time.Time `json:"created_at"`
}

// ProductVariant represents one size/price/stock option of a product.
// e.g. Rose Elégante comes in 30ml, 50ml, 100ml — each is a variant.
type ProductVariant struct {
	ID        uuid.UUID `json:"id"`
	ProductID uuid.UUID `json:"product_id"`
	Size      string    `json:"size"`
	Price     int64     `json:"price"` // stored in IDR (e.g. 185000)
	Stock     int       `json:"stock"`
	SKU       string    `json:"sku"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Product represents a perfume product with its variants.
type Product struct {
	ID          uuid.UUID        `json:"id"`
	Name        string           `json:"name"`
	Brand       string           `json:"brand"`
	CategoryID  uuid.UUID        `json:"category_id"`
	Category    *Category        `json:"category,omitempty"`
	Description *string          `json:"description,omitempty"`
	ImageURL    *string          `json:"image_url,omitempty"`
	IsActive    bool             `json:"is_active"`
	IsFeatured  bool             `json:"is_featured"`
	IsFavourite bool             `json:"is_favourite"`
	Variants    []ProductVariant `json:"variants"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
}

// TotalStock returns the sum of stock across all variants.
// Used by the cashier to quickly know if a product is available.
func (p *Product) TotalStock() int {
	total := 0
	for _, v := range p.Variants {
		total += v.Stock
	}
	return total
}

// IsOutOfStock returns true if no variants have stock.
func (p *Product) IsOutOfStock() bool {
	return p.TotalStock() == 0
}

// ── Request bodies (what the API accepts) ──────────────────────

// CreateProductRequest is the JSON body for POST /products.
type CreateProductRequest struct {
	Name        string                 `json:"name"`
	Brand       string                 `json:"brand"`
	CategoryID  string                 `json:"category_id"`
	Description string                 `json:"description"`
	ImageURL    string                 `json:"image_url"`
	IsActive    bool                   `json:"is_active"`
	IsFeatured  bool                   `json:"is_featured"`
	Variants    []CreateVariantRequest `json:"variants"`
}

// CreateVariantRequest is the variant data inside CreateProductRequest.
type CreateVariantRequest struct {
	Size  string `json:"size"`
	Price int64  `json:"price"`
	Stock int    `json:"stock"`
	SKU   string `json:"sku"`
}

// UpdateProductRequest is the JSON body for PATCH /products/{id}.
// Pointer fields mean "only update if provided in the request".
type UpdateProductRequest struct {
	Name        *string `json:"name"`
	Brand       *string `json:"brand"`
	CategoryID  *string `json:"category_id"`
	Description *string `json:"description"`
	ImageURL    *string `json:"image_url"`
	IsActive    *bool   `json:"is_active"`
	IsFeatured  *bool   `json:"is_featured"`
	IsFavourite *bool   `json:"is_favourite"`
}

// CreateCategoryRequest is the JSON body for POST /categories.
type CreateCategoryRequest struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	SortOrder   int    `json:"sort_order"`
}
