package handlers

import (
	"encoding/json"
	"net/http"

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
