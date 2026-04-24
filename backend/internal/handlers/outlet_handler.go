package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

type OutletHandler struct {
	outletService *services.OutletService
}

func NewOutletHandler(s *services.OutletService) *OutletHandler {
	return &OutletHandler{outletService: s}
}

func (h *OutletHandler) ListOutlets(w http.ResponseWriter, r *http.Request) {
	outlets, err := h.outletService.GetOutlets(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, outlets)
}

func (h *OutletHandler) CreateOutlet(w http.ResponseWriter, r *http.Request) {
	var req models.CreateOutletRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	o, err := h.outletService.CreateOutlet(r.Context(), &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, o)
}

func (h *OutletHandler) UpdateOutlet(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid outlet ID")
		return
	}
	var req models.UpdateOutletRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	o, err := h.outletService.UpdateOutlet(r.Context(), id, &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, o)
}

func (h *OutletHandler) DeleteOutlet(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid outlet ID")
		return
	}
	if err := h.outletService.DeleteOutlet(r.Context(), id); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "outlet deactivated"})
}
