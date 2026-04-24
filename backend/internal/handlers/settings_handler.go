package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

type SettingsHandler struct {
	settingsService *services.SettingsService
}

func NewSettingsHandler(s *services.SettingsService) *SettingsHandler {
	return &SettingsHandler{settingsService: s}
}

func (h *SettingsHandler) GetSettings(w http.ResponseWriter, r *http.Request) {
	settings, err := h.settingsService.GetSettings(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, settings)
}

func (h *SettingsHandler) UpdateSettings(w http.ResponseWriter, r *http.Request) {
	var req models.AppSettings
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	settings, err := h.settingsService.UpdateSettings(r.Context(), &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, settings)
}
