package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
	"github.com/google/uuid"
)

// errUnauthorized is a sentinel used by resolveUser helpers.
var errUnauthorized = errors.New("unauthorized")

type StockCountHandler struct {
	stockCountService *services.StockCountService
	userService       *services.UserService
}

func NewStockCountHandler(s *services.StockCountService, u *services.UserService) *StockCountHandler {
	return &StockCountHandler{stockCountService: s, userService: u}
}

func (h *StockCountHandler) ListStockCounts(w http.ResponseWriter, r *http.Request) {
	counts, err := h.stockCountService.GetStockCounts(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, counts)
}

func (h *StockCountHandler) GetStockCount(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid stock count ID")
		return
	}
	sc, err := h.stockCountService.GetStockCountByID(r.Context(), id)
	if err != nil {
		middleware.WriteNotFound(w, "stock count not found")
		return
	}
	middleware.WriteSuccess(w, sc)
}

func (h *StockCountHandler) CreateStockCount(w http.ResponseWriter, r *http.Request) {
	v := middleware.GetUserFromContext(r)
	if v == nil {
		middleware.WriteError(w, http.StatusUnauthorized, "not authenticated")
		return
	}
	dbUser, err := h.userService.GetOrCreateByFirebaseUID(r.Context(), v.UID, v.Email, v.DisplayName, v.PhotoURL)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}

	var req models.CreateStockCountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	sc, err := h.stockCountService.CreateStockCount(r.Context(), dbUser.ID, &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, sc)
}

// PATCH /api/v1/admin/stock-counts/{id}/items/{itemId}
func (h *StockCountHandler) UpdateItemQty(w http.ResponseWriter, r *http.Request) {
	stockCountID, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid stock count ID")
		return
	}
	itemID, err := uuid.Parse(r.PathValue("itemId"))
	if err != nil {
		middleware.WriteBadRequest(w, "invalid item ID")
		return
	}

	var req models.UpdateStockCountItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	if err := h.stockCountService.UpdateItemActualQty(r.Context(), stockCountID, itemID, req.ActualQty); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "updated"})
}

// PATCH /api/v1/admin/stock-counts/{id}/status
func (h *StockCountHandler) UpdateStatus(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid stock count ID")
		return
	}
	var body struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	sc, err := h.stockCountService.UpdateStockCountStatus(r.Context(), id, body.Status)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, sc)
}
