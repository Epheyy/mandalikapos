package services

import (
	"context"
	"fmt"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	redisclient "github.com/Epheyy/mandalikapos/backend/internal/redis"
	"github.com/google/uuid"
)

// Cache key constants — centralised so they're consistent everywhere.
// If we change a key name, we only change it in one place.
const (
	cacheKeyAllProducts    = "products:all"
	cacheKeyActiveProducts = "products:active"
	cacheKeyAllCategories  = "categories:all"
	cacheTTLProducts       = 5 * time.Minute
	cacheTTLCategories     = 10 * time.Minute
)

// ProductService handles all product and category database operations.
type ProductService struct {
	db    *database.DB
	cache *redisclient.Client
}

// NewProductService creates a new ProductService.
func NewProductService(db *database.DB, cache *redisclient.Client) *ProductService {
	return &ProductService{db: db, cache: cache}
}

// ── CATEGORIES ──────────────────────────────────────────────────

// GetAllCategories returns all categories, using Redis cache when available.
func (s *ProductService) GetAllCategories(ctx context.Context) ([]*models.Category, error) {
	// Try cache first
	var cached []*models.Category
	if err := s.cache.Get(ctx, cacheKeyAllCategories, &cached); err == nil {
		return cached, nil // cache hit — return immediately without touching DB
	}

	// Cache miss — fetch from database
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, name, description, sort_order, created_at
		FROM categories
		ORDER BY sort_order ASC, name ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query categories: %w", err)
	}
	defer rows.Close()

	var categories []*models.Category
	for rows.Next() {
		c := &models.Category{}
		if err := rows.Scan(&c.ID, &c.Name, &c.Description, &c.SortOrder, &c.CreatedAt); err != nil {
			return nil, err
		}
		categories = append(categories, c)
	}

	// Store in cache for next time
	_ = s.cache.Set(ctx, cacheKeyAllCategories, categories, cacheTTLCategories)

	return categories, nil
}

// CreateCategory adds a new category and clears the category cache.
func (s *ProductService) CreateCategory(ctx context.Context, req *models.CreateCategoryRequest) (*models.Category, error) {
	if req.Name == "" {
		return nil, fmt.Errorf("category name is required")
	}

	cat := &models.Category{
		ID:        uuid.New(),
		Name:      req.Name,
		SortOrder: req.SortOrder,
		CreatedAt: time.Now(),
	}
	if req.Description != "" {
		cat.Description = &req.Description
	}

	_, err := s.db.Pool.Exec(ctx, `
		INSERT INTO categories (id, name, description, sort_order, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`, cat.ID, cat.Name, cat.Description, cat.SortOrder, cat.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create category: %w", err)
	}

	// Clear cache so next read gets fresh data
	_ = s.cache.Delete(ctx, cacheKeyAllCategories)

	return cat, nil
}

// UpdateCategory modifies an existing category.
func (s *ProductService) UpdateCategory(ctx context.Context, id uuid.UUID, req *models.CreateCategoryRequest) (*models.Category, error) {
	_, err := s.db.Pool.Exec(ctx, `
		UPDATE categories SET name = $1, description = $2, sort_order = $3
		WHERE id = $4
	`, req.Name, req.Description, req.SortOrder, id)
	if err != nil {
		return nil, fmt.Errorf("failed to update category: %w", err)
	}

	_ = s.cache.Delete(ctx, cacheKeyAllCategories)

	return s.getCategoryByID(ctx, id)
}

// DeleteCategory removes a category.
// Note: will fail if products still reference this category (FK constraint).
func (s *ProductService) DeleteCategory(ctx context.Context, id uuid.UUID) error {
	result, err := s.db.Pool.Exec(ctx, `DELETE FROM categories WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("failed to delete category: %w", err)
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("category not found")
	}

	_ = s.cache.Delete(ctx, cacheKeyAllCategories)
	return nil
}

// ── PRODUCTS ────────────────────────────────────────────────────

// GetActiveProducts returns all active products with their variants.
// This is what the cashier screen loads. Cached aggressively.
func (s *ProductService) GetActiveProducts(ctx context.Context) ([]*models.Product, error) {
	var cached []*models.Product
	if err := s.cache.Get(ctx, cacheKeyActiveProducts, &cached); err == nil {
		return cached, nil
	}

	products, err := s.queryProducts(ctx, `
		SELECT p.id, p.name, p.brand, p.category_id, p.description,
		       p.image_url, p.is_active, p.is_featured, p.is_favourite,
		       p.created_at, p.updated_at,
		       c.id, c.name
		FROM products p
		LEFT JOIN categories c ON c.id = p.category_id
		WHERE p.is_active = TRUE
		ORDER BY p.name ASC
	`)
	if err != nil {
		return nil, err
	}

	_ = s.cache.Set(ctx, cacheKeyActiveProducts, products, cacheTTLProducts)
	return products, nil
}

// GetAllProducts returns all products including inactive ones (admin use).
func (s *ProductService) GetAllProducts(ctx context.Context) ([]*models.Product, error) {
	return s.queryProducts(ctx, `
		SELECT p.id, p.name, p.brand, p.category_id, p.description,
		       p.image_url, p.is_active, p.is_featured, p.is_favourite,
		       p.created_at, p.updated_at,
		       c.id, c.name
		FROM products p
		LEFT JOIN categories c ON c.id = p.category_id
		ORDER BY p.created_at DESC
	`)
}

// GetProductByID returns a single product with its variants.
func (s *ProductService) GetProductByID(ctx context.Context, id uuid.UUID) (*models.Product, error) {
	products, err := s.queryProducts(ctx, `
		SELECT p.id, p.name, p.brand, p.category_id, p.description,
		       p.image_url, p.is_active, p.is_featured, p.is_favourite,
		       p.created_at, p.updated_at,
		       c.id, c.name
		FROM products p
		LEFT JOIN categories c ON c.id = p.category_id
		WHERE p.id = $1
	`, id)
	if err != nil {
		return nil, err
	}
	if len(products) == 0 {
		return nil, fmt.Errorf("product not found")
	}
	return products[0], nil
}

// CreateProduct adds a new product with its variants in a single transaction.
// If any variant fails to insert, the whole product is rolled back.
func (s *ProductService) CreateProduct(ctx context.Context, req *models.CreateProductRequest) (*models.Product, error) {
	// Validate required fields
	if req.Name == "" {
		return nil, fmt.Errorf("product name is required")
	}
	if req.CategoryID == "" {
		return nil, fmt.Errorf("category_id is required")
	}
	if len(req.Variants) == 0 {
		return nil, fmt.Errorf("at least one variant is required")
	}
	for _, v := range req.Variants {
		if v.Size == "" {
			return nil, fmt.Errorf("variant size is required")
		}
		if v.Price <= 0 {
			return nil, fmt.Errorf("variant price must be greater than 0")
		}
	}

	categoryID, err := uuid.Parse(req.CategoryID)
	if err != nil {
		return nil, fmt.Errorf("invalid category_id format")
	}

	productID := uuid.New()
	now := time.Now()

	// Use a transaction so product + variants are atomic
	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Insert product
	var descPtr, imagePtr *string
	if req.Description != "" {
		descPtr = &req.Description
	}
	if req.ImageURL != "" {
		imagePtr = &req.ImageURL
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO products (id, name, brand, category_id, description, image_url,
		                      is_active, is_featured, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
	`, productID, req.Name, req.Brand, categoryID, descPtr, imagePtr,
		req.IsActive, req.IsFeatured, now, now)
	if err != nil {
		return nil, fmt.Errorf("failed to insert product: %w", err)
	}

	// Insert all variants
	for _, v := range req.Variants {
		_, err = tx.Exec(ctx, `
			INSERT INTO product_variants (id, product_id, size, price, stock, sku, created_at, updated_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		`, uuid.New(), productID, v.Size, v.Price, v.Stock, v.SKU, now, now)
		if err != nil {
			return nil, fmt.Errorf("failed to insert variant %s: %w", v.Size, err)
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Clear product caches so next read is fresh
	_ = s.cache.DeleteByPattern(ctx, "products:*")

	return s.GetProductByID(ctx, productID)
}

// UpdateProduct modifies product fields. Only fields provided in the request are changed.
func (s *ProductService) UpdateProduct(ctx context.Context, id uuid.UUID, req *models.UpdateProductRequest) (*models.Product, error) {
	// Build dynamic UPDATE query based on which fields were provided
	// We use a simple approach: fetch current, apply changes, save
	product, err := s.GetProductByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if req.Name != nil {
		product.Name = *req.Name
	}
	if req.Brand != nil {
		product.Brand = *req.Brand
	}
	if req.CategoryID != nil {
		cid, err := uuid.Parse(*req.CategoryID)
		if err != nil {
			return nil, fmt.Errorf("invalid category_id")
		}
		product.CategoryID = cid
	}
	if req.Description != nil {
		product.Description = req.Description
	}
	if req.ImageURL != nil {
		product.ImageURL = req.ImageURL
	}
	if req.IsActive != nil {
		product.IsActive = *req.IsActive
	}
	if req.IsFeatured != nil {
		product.IsFeatured = *req.IsFeatured
	}
	if req.IsFavourite != nil {
		product.IsFavourite = *req.IsFavourite
	}

	_, err = s.db.Pool.Exec(ctx, `
		UPDATE products
		SET name=$1, brand=$2, category_id=$3, description=$4, image_url=$5,
		    is_active=$6, is_featured=$7, is_favourite=$8, updated_at=NOW()
		WHERE id=$9
	`, product.Name, product.Brand, product.CategoryID, product.Description,
		product.ImageURL, product.IsActive, product.IsFeatured, product.IsFavourite, id)
	if err != nil {
		return nil, fmt.Errorf("failed to update product: %w", err)
	}

	_ = s.cache.DeleteByPattern(ctx, "products:*")

	return s.GetProductByID(ctx, id)
}

// UpdateVariantStock updates the stock for a specific variant.
// Called after each sale to reduce stock, and after refunds to restore it.
func (s *ProductService) UpdateVariantStock(ctx context.Context, variantID uuid.UUID, newStock int) error {
	if newStock < 0 {
		return fmt.Errorf("stock cannot be negative")
	}
	_, err := s.db.Pool.Exec(ctx, `
		UPDATE product_variants SET stock = $1, updated_at = NOW() WHERE id = $2
	`, newStock, variantID)
	if err != nil {
		return fmt.Errorf("failed to update stock: %w", err)
	}

	_ = s.cache.DeleteByPattern(ctx, "products:*")
	return nil
}

// DeleteProduct soft-deletes a product by marking it inactive.
// We never hard-delete products because old orders reference them.
func (s *ProductService) DeleteProduct(ctx context.Context, id uuid.UUID) error {
	_, err := s.db.Pool.Exec(ctx, `
		UPDATE products SET is_active = FALSE, updated_at = NOW() WHERE id = $1
	`, id)
	if err != nil {
		return fmt.Errorf("failed to delete product: %w", err)
	}
	_ = s.cache.DeleteByPattern(ctx, "products:*")
	return nil
}

// ── Private helpers ─────────────────────────────────────────────

// queryProducts runs a product SELECT query and loads variants for each product.
func (s *ProductService) queryProducts(ctx context.Context, query string, args ...any) ([]*models.Product, error) {
	rows, err := s.db.Pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query products: %w", err)
	}
	defer rows.Close()

	// Use a map to collect products by ID (avoids duplicates)
	productMap := make(map[uuid.UUID]*models.Product)
	var productOrder []uuid.UUID // preserve query order

	for rows.Next() {
		p := &models.Product{}
		var catID uuid.UUID
		var catName string

		if err := rows.Scan(
			&p.ID, &p.Name, &p.Brand, &p.CategoryID, &p.Description,
			&p.ImageURL, &p.IsActive, &p.IsFeatured, &p.IsFavourite,
			&p.CreatedAt, &p.UpdatedAt,
			&catID, &catName,
		); err != nil {
			return nil, err
		}

		p.Category = &models.Category{ID: catID, Name: catName}
		p.Variants = []models.ProductVariant{}
		productMap[p.ID] = p
		productOrder = append(productOrder, p.ID)
	}

	if len(productMap) == 0 {
		return []*models.Product{}, nil
	}

	// Load variants for all products in a single query (more efficient than N+1 queries)
	variantRows, err := s.db.Pool.Query(ctx, `
		SELECT id, product_id, size, price, stock, sku, created_at, updated_at
		FROM product_variants
		WHERE product_id = ANY($1)
		ORDER BY price ASC
	`, productIDs(productOrder))
	if err != nil {
		return nil, fmt.Errorf("failed to query variants: %w", err)
	}
	defer variantRows.Close()

	for variantRows.Next() {
		v := models.ProductVariant{}
		if err := variantRows.Scan(
			&v.ID, &v.ProductID, &v.Size, &v.Price, &v.Stock, &v.SKU,
			&v.CreatedAt, &v.UpdatedAt,
		); err != nil {
			return nil, err
		}
		if p, ok := productMap[v.ProductID]; ok {
			p.Variants = append(p.Variants, v)
		}
	}

	// Return in original query order
	result := make([]*models.Product, 0, len(productOrder))
	seen := make(map[uuid.UUID]bool)
	for _, id := range productOrder {
		if !seen[id] {
			result = append(result, productMap[id])
			seen[id] = true
		}
	}
	return result, nil
}

func (s *ProductService) getCategoryByID(ctx context.Context, id uuid.UUID) (*models.Category, error) {
	c := &models.Category{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, name, description, sort_order, created_at FROM categories WHERE id = $1
	`, id).Scan(&c.ID, &c.Name, &c.Description, &c.SortOrder, &c.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("category not found: %w", err)
	}
	return c, nil
}

// productIDs converts a slice of UUIDs into a format PostgreSQL's ANY() accepts.
func productIDs(ids []uuid.UUID) []string {
	result := make([]string, len(ids))
	for i, id := range ids {
		result[i] = id.String()
	}
	return result
}
