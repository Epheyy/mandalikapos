package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

type CustomerHandler struct {
	customerService *services.CustomerService
}

func NewCustomerHandler(s *services.CustomerService) *CustomerHandler {
	return &CustomerHandler{customerService: s}
}

// GET /api/v1/customers?phone=xxx
func (h *CustomerHandler) ListCustomers(w http.ResponseWriter, r *http.Request) {
	phone := r.URL.Query().Get("phone")
	if phone != "" {
		c, err := h.customerService.GetCustomerByPhone(r.Context(), phone)
		if err != nil {
			middleware.WriteNotFound(w, "customer not found")
			return
		}
		middleware.WriteSuccess(w, c)
		return
	}
	customers, err := h.customerService.GetCustomers(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, customers)
}

// POST /api/v1/customers
func (h *CustomerHandler) CreateCustomer(w http.ResponseWriter, r *http.Request) {
	var req models.CreateCustomerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	c, err := h.customerService.CreateCustomer(r.Context(), &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, c)
}

// PUT /api/v1/admin/customers/{id}
func (h *CustomerHandler) UpdateCustomer(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid customer ID")
		return
	}
	var req models.UpdateCustomerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	c, err := h.customerService.UpdateCustomer(r.Context(), id, &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, c)
}

// DELETE /api/v1/admin/customers/{id}
func (h *CustomerHandler) DeleteCustomer(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid customer ID")
		return
	}
	if err := h.customerService.DeleteCustomer(r.Context(), id); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "customer deleted"})
}

// GET /api/v1/admin/customers/{id}/orders
func (h *CustomerHandler) GetCustomerOrders(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid customer ID")
		return
	}
	orders, err := h.customerService.GetCustomerOrders(r.Context(), id)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, orders)
}
