package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

// Note: errUnauthorized is defined in stock_count_handler.go (same package)

type ShiftHandler struct {
	shiftService *services.ShiftService
	userService  *services.UserService
}

func NewShiftHandler(s *services.ShiftService, u *services.UserService) *ShiftHandler {
	return &ShiftHandler{shiftService: s, userService: u}
}

// GET /api/v1/shifts/current
func (h *ShiftHandler) GetCurrentShift(w http.ResponseWriter, r *http.Request) {
	dbUser, err := h.resolveUser(w, r)
	if err != nil {
		return
	}
	sh, err := h.shiftService.GetCurrentShift(r.Context(), dbUser.ID)
	if err != nil {
		middleware.WriteNotFound(w, "no open shift")
		return
	}
	middleware.WriteSuccess(w, sh)
}

// POST /api/v1/shifts/open
func (h *ShiftHandler) OpenShift(w http.ResponseWriter, r *http.Request) {
	dbUser, err := h.resolveUser(w, r)
	if err != nil {
		return
	}
	var req models.OpenShiftRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	sh, err := h.shiftService.OpenShift(r.Context(), dbUser.ID, &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteCreated(w, sh)
}

// POST /api/v1/shifts/close
func (h *ShiftHandler) CloseShift(w http.ResponseWriter, r *http.Request) {
	dbUser, err := h.resolveUser(w, r)
	if err != nil {
		return
	}
	var req models.CloseShiftRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	sh, err := h.shiftService.CloseShift(r.Context(), dbUser.ID, &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteSuccess(w, sh)
}

// GET /api/v1/admin/shifts
func (h *ShiftHandler) ListShifts(w http.ResponseWriter, r *http.Request) {
	shifts, err := h.shiftService.GetShifts(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, shifts)
}

func (h *ShiftHandler) resolveUser(w http.ResponseWriter, r *http.Request) (*models.User, error) {
	v := middleware.GetUserFromContext(r)
	if v == nil {
		middleware.WriteError(w, http.StatusUnauthorized, "not authenticated")
		return nil, errUnauthorized
	}
	dbUser, err := h.userService.GetOrCreateByFirebaseUID(r.Context(), v.UID, v.Email, v.DisplayName, v.PhotoURL)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return nil, err
	}
	return dbUser, nil
}
