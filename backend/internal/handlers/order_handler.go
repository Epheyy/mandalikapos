package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

type OrderHandler struct {
	orderService *services.OrderService
	userService  *services.UserService
}

func NewOrderHandler(orderService *services.OrderService, userService *services.UserService) *OrderHandler {
	return &OrderHandler{orderService: orderService, userService: userService}
}

// CreateOrder processes a new sale.
// POST /api/v1/orders
func (h *OrderHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	// Get the cashier from auth context
	verifiedUser := middleware.GetUserFromContext(r)
	if verifiedUser == nil {
		middleware.WriteError(w, http.StatusUnauthorized, "not authenticated")
		return
	}

	// Look up their database record
	dbUser, err := h.userService.GetOrCreateByFirebaseUID(
		r.Context(),
		verifiedUser.UID,
		verifiedUser.Email,
		verifiedUser.DisplayName,
		verifiedUser.PhotoURL,
	)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}

	var req models.CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	order, err := h.orderService.CreateOrder(
		r.Context(), &req, dbUser.ID, dbUser.DisplayName,
	)
	if err != nil {
		// Return the specific error message (e.g. "insufficient stock")
		middleware.WriteJSON(w, http.StatusUnprocessableEntity,
			map[string]string{"error": err.Error()})
		return
	}

	middleware.WriteCreated(w, order)
}

// ListOrders returns orders for the admin panel with optional filters.
// GET /api/v1/admin/orders?from=2024-01-01&to=2024-01-31&status=completed&paymentMethod=cash
func (h *OrderHandler) ListOrders(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	filter := &models.ListOrdersFilter{Limit: 50}

	if v := q.Get("from"); v != "" {
		if t, err := time.Parse("2006-01-02", v); err == nil {
			filter.From = &t
		}
	}
	if v := q.Get("to"); v != "" {
		if t, err := time.Parse("2006-01-02", v); err == nil {
			end := t.Add(24*time.Hour - time.Second)
			filter.To = &end
		}
	}
	filter.Status = q.Get("status")
	filter.PaymentMethod = q.Get("paymentMethod")

	orders, err := h.orderService.ListOrders(r.Context(), filter)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, orders)
}

// RefundOrder marks an order as refunded and restores stock.
// PUT /api/v1/admin/orders/{id}/refund
func (h *OrderHandler) RefundOrder(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid order ID")
		return
	}

	var req models.RefundOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}

	order, err := h.orderService.RefundOrder(r.Context(), id, req.Reason)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteSuccess(w, order)
}
