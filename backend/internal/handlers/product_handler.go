package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
	"github.com/google/uuid"
)

// ProductHandler handles HTTP requests for products and categories.
type ProductHandler struct {
	productService *services.ProductService
}

// NewProductHandler creates a new ProductHandler.
func NewProductHandler(productService *services.ProductService) *ProductHandler {
	return &ProductHandler{productService: productService}
}

// ── Category Handlers ───────────────────────────────────────────

// ListCategories returns all categories.
// GET /api/v1/categories
func (h *ProductHandler) ListCategories(w http.ResponseWriter, r *http.Request) {
	categories, err := h.productService.GetAllCategories(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, categories)
}

// CreateCategory adds a new category.
// POST /api/v1/categories
func (h *ProductHandler) CreateCategory(w http.ResponseWriter, r *http.Request) {
	var req models.CreateCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	cat, err := h.productService.CreateCategory(r.Context(), &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, cat)
}

// UpdateCategory modifies an existing category.
// PUT /api/v1/categories/{id}
func (h *ProductHandler) UpdateCategory(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid category ID")
		return
	}

	var req models.CreateCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	cat, err := h.productService.UpdateCategory(r.Context(), id, &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, cat)
}

// DeleteCategory removes a category.
// DELETE /api/v1/categories/{id}
func (h *ProductHandler) DeleteCategory(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid category ID")
		return
	}

	if err := h.productService.DeleteCategory(r.Context(), id); err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "category deleted"})
}

// ── Product Handlers ────────────────────────────────────────────

// ListActiveProducts returns active products for the cashier screen.
// GET /api/v1/products
func (h *ProductHandler) ListActiveProducts(w http.ResponseWriter, r *http.Request) {
	products, err := h.productService.GetActiveProducts(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, products)
}

// ListAllProducts returns all products including inactive (admin use).
// GET /api/v1/admin/products
func (h *ProductHandler) ListAllProducts(w http.ResponseWriter, r *http.Request) {
	products, err := h.productService.GetAllProducts(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, products)
}

// GetProduct returns a single product by ID.
// GET /api/v1/products/{id}
func (h *ProductHandler) GetProduct(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid product ID")
		return
	}

	product, err := h.productService.GetProductByID(r.Context(), id)
	if err != nil {
		middleware.WriteNotFound(w, "product not found")
		return
	}
	middleware.WriteSuccess(w, product)
}

// CreateProduct adds a new product with variants.
// POST /api/v1/admin/products
func (h *ProductHandler) CreateProduct(w http.ResponseWriter, r *http.Request) {
	var req models.CreateProductRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	product, err := h.productService.CreateProduct(r.Context(), &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, product)
}

// UpdateProduct modifies product fields.
// PATCH /api/v1/admin/products/{id}
func (h *ProductHandler) UpdateProduct(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid product ID")
		return
	}

	var req models.UpdateProductRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	product, err := h.productService.UpdateProduct(r.Context(), id, &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, product)
}

// DeleteProduct soft-deletes a product.
// DELETE /api/v1/admin/products/{id}
func (h *ProductHandler) DeleteProduct(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid product ID")
		return
	}

	if err := h.productService.DeleteProduct(r.Context(), id); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "product deactivated"})
}

// ── Shared helper ────────────────────────────────────────────────

// parseUUID extracts a UUID from the URL path parameter.
func parseUUID(r *http.Request, param string) (uuid.UUID, error) {
	return uuid.Parse(r.PathValue(param))
}
