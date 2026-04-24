package services

import (
	"context"
	"fmt"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	redisclient "github.com/Epheyy/mandalikapos/backend/internal/redis"
)

type ReportService struct {
	db    *database.DB
	cache *redisclient.Client
}

func NewReportService(db *database.DB, cache *redisclient.Client) *ReportService {
	return &ReportService{db: db, cache: cache}
}

func (s *ReportService) GetSalesReport(ctx context.Context, from, to time.Time, groupBy string) (*models.SalesReport, error) {
	cacheKey := fmt.Sprintf("report:sales:%s:%s:%s", from.Format("2006-01-02"), to.Format("2006-01-02"), groupBy)
	var cached models.SalesReport
	if s.cache.Get(ctx, cacheKey, &cached) == nil {
		return &cached, nil
	}

	report := &models.SalesReport{
		From:    from.Format("2006-01-02"),
		To:      to.Format("2006-01-02"),
		GroupBy: groupBy,
	}

	// Overall totals
	s.db.Pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(total),0), COUNT(*)
		FROM orders WHERE status='completed' AND created_at >= $1 AND created_at <= $2
	`, from, to).Scan(&report.Total, &report.Orders)

	// Group by period
	var truncExpr string
	var labelFmt string
	switch groupBy {
	case "week":
		truncExpr = "week"
		labelFmt = "IYYY-\"W\"IW"
	case "month":
		truncExpr = "month"
		labelFmt = "YYYY-MM"
	default: // day
		truncExpr = "day"
		labelFmt = "YYYY-MM-DD"
	}

	rows, err := s.db.Pool.Query(ctx, fmt.Sprintf(`
		SELECT to_char(DATE_TRUNC('%s', created_at), '%s'), COALESCE(SUM(total),0), COUNT(*)
		FROM orders WHERE status='completed' AND created_at >= $1 AND created_at <= $2
		GROUP BY DATE_TRUNC('%s', created_at)
		ORDER BY DATE_TRUNC('%s', created_at) ASC
	`, truncExpr, labelFmt, truncExpr, truncExpr), from, to)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			p := models.ReportPeriod{}
			if rows.Scan(&p.Label, &p.Sales, &p.Orders) == nil {
				report.Periods = append(report.Periods, p)
			}
		}
	}

	// Top products
	prows, err := s.db.Pool.Query(ctx, `
		SELECT oi.product_name, oi.variant_size, SUM(oi.quantity), SUM(oi.subtotal)
		FROM order_items oi
		JOIN orders o ON o.id = oi.order_id
		WHERE o.status='completed' AND o.created_at >= $1 AND o.created_at <= $2
		GROUP BY oi.product_name, oi.variant_size
		ORDER BY SUM(oi.quantity) DESC LIMIT 10
	`, from, to)
	if err == nil {
		defer prows.Close()
		for prows.Next() {
			tp := models.TopProduct{}
			if prows.Scan(&tp.ProductName, &tp.VariantSize, &tp.Quantity, &tp.Revenue) == nil {
				report.Products = append(report.Products, tp)
			}
		}
	}

	// Payment breakdown
	pmrows, err := s.db.Pool.Query(ctx, `
		SELECT payment_method, COALESCE(SUM(total),0), COUNT(*)
		FROM orders WHERE status='completed' AND created_at >= $1 AND created_at <= $2
		GROUP BY payment_method
	`, from, to)
	if err == nil {
		defer pmrows.Close()
		for pmrows.Next() {
			pb := models.PaymentBreakdownItem{}
			if pmrows.Scan(&pb.Method, &pb.Amount, &pb.Count) == nil {
				report.Payment = append(report.Payment, pb)
			}
		}
	}

	s.cache.Set(ctx, cacheKey, report, 15*time.Minute)
	return report, nil
}
