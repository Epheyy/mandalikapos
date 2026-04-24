package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

type PromotionHandler struct {
	promotionService *services.PromotionService
}

func NewPromotionHandler(s *services.PromotionService) *PromotionHandler {
	return &PromotionHandler{promotionService: s}
}

func (h *PromotionHandler) ListPromotions(w http.ResponseWriter, r *http.Request) {
	promos, err := h.promotionService.GetPromotions(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, promos)
}

func (h *PromotionHandler) ListActivePromotions(w http.ResponseWriter, r *http.Request) {
	promos, err := h.promotionService.GetActivePromotions(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, promos)
}

func (h *PromotionHandler) CreatePromotion(w http.ResponseWriter, r *http.Request) {
	var req models.CreatePromotionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	p, err := h.promotionService.CreatePromotion(r.Context(), &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, p)
}

func (h *PromotionHandler) DeletePromotion(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid promotion ID")
		return
	}
	if err := h.promotionService.DeletePromotion(r.Context(), id); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "promotion deactivated"})
}

func (h *PromotionHandler) ListDiscountCodes(w http.ResponseWriter, r *http.Request) {
	codes, err := h.promotionService.GetDiscountCodes(r.Context())
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, codes)
}

func (h *PromotionHandler) CreateDiscountCode(w http.ResponseWriter, r *http.Request) {
	var req models.CreateDiscountCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	c, err := h.promotionService.CreateDiscountCode(r.Context(), &req)
	if err != nil {
		middleware.WriteBadRequest(w, err.Error())
		return
	}
	middleware.WriteCreated(w, c)
}

func (h *PromotionHandler) DeleteDiscountCode(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUID(r, "id")
	if err != nil {
		middleware.WriteBadRequest(w, "invalid discount code ID")
		return
	}
	if err := h.promotionService.DeleteDiscountCode(r.Context(), id); err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, map[string]string{"message": "discount code deleted"})
}

func (h *PromotionHandler) ValidateDiscountCode(w http.ResponseWriter, r *http.Request) {
	var req models.ValidateDiscountCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		middleware.WriteBadRequest(w, "invalid request body")
		return
	}
	result, err := h.promotionService.ValidateDiscountCode(r.Context(), &req)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, result)
}
