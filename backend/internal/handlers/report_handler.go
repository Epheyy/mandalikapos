package handlers

import (
	"net/http"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/middleware"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
)

type ReportHandler struct {
	reportService *services.ReportService
}

func NewReportHandler(s *services.ReportService) *ReportHandler {
	return &ReportHandler{reportService: s}
}

// GET /api/v1/admin/reports/sales?from=2024-01-01&to=2024-01-31&groupBy=day
func (h *ReportHandler) GetSalesReport(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()

	fromStr := q.Get("from")
	toStr := q.Get("to")
	groupBy := q.Get("groupBy")
	if groupBy == "" {
		groupBy = "day"
	}

	now := time.Now()
	from := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	to := now

	if fromStr != "" {
		if t, err := time.Parse("2006-01-02", fromStr); err == nil {
			from = t
		}
	}
	if toStr != "" {
		if t, err := time.Parse("2006-01-02", toStr); err == nil {
			to = t.Add(24*time.Hour - time.Second)
		}
	}

	report, err := h.reportService.GetSalesReport(r.Context(), from, to, groupBy)
	if err != nil {
		middleware.WriteInternalError(w, err)
		return
	}
	middleware.WriteSuccess(w, report)
}
