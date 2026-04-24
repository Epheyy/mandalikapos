package services

import (
	"context"
	"fmt"
	"time"

	redisclient "github.com/Epheyy/mandalikapos/backend/internal/redis"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
)

const (
	cacheDashboard = "dashboard:stats"
	cacheDashboardTTL = 5 * time.Minute
)

type DashboardService struct {
	db    *database.DB
	cache *redisclient.Client
}

func NewDashboardService(db *database.DB, cache *redisclient.Client) *DashboardService {
	return &DashboardService{db: db, cache: cache}
}

func (s *DashboardService) GetStats(ctx context.Context) (*models.DashboardStats, error) {
	var cached models.DashboardStats
	if err := s.cache.Get(ctx, cacheDashboard, &cached); err == nil {
		return &cached, nil
	}

	stats := &models.DashboardStats{}
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	weekStart := todayStart.AddDate(0, 0, -6)
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	// Today stats
	s.db.Pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(total),0), COUNT(*), COUNT(DISTINCT customer_id)
		FROM orders WHERE status='completed' AND created_at >= $1
	`, todayStart).Scan(&stats.TodaySales, &stats.TodayOrders, &stats.TodayCustomers)

	// Week / month totals
	s.db.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(total),0) FROM orders WHERE status='completed' AND created_at >= $1`, weekStart).Scan(&stats.WeekSales)
	s.db.Pool.QueryRow(ctx, `SELECT COALESCE(SUM(total),0) FROM orders WHERE status='completed' AND created_at >= $1`, monthStart).Scan(&stats.MonthSales)

	// Top products (last 7 days)
	rows, err := s.db.Pool.Query(ctx, `
		SELECT oi.product_name, oi.variant_size, SUM(oi.quantity) AS qty, SUM(oi.subtotal) AS rev
		FROM order_items oi
		JOIN orders o ON o.id = oi.order_id
		WHERE o.status='completed' AND o.created_at >= $1
		GROUP BY oi.product_name, oi.variant_size
		ORDER BY qty DESC LIMIT 5
	`, weekStart)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			tp := models.TopProduct{}
			if rows.Scan(&tp.ProductName, &tp.VariantSize, &tp.Quantity, &tp.Revenue) == nil {
				stats.TopProducts = append(stats.TopProducts, tp)
			}
		}
	}

	// Sales by day (last 7 days)
	drows, err := s.db.Pool.Query(ctx, `
		SELECT to_char(DATE_TRUNC('day', created_at), 'YYYY-MM-DD') AS day,
		       COALESCE(SUM(total),0), COUNT(*)
		FROM orders
		WHERE status='completed' AND created_at >= $1
		GROUP BY day ORDER BY day ASC
	`, weekStart)
	if err == nil {
		defer drows.Close()
		for drows.Next() {
			ds := models.DaySales{}
			if drows.Scan(&ds.Date, &ds.Sales, &ds.Orders) == nil {
				stats.SalesByDay = append(stats.SalesByDay, ds)
			}
		}
	}

	// Payment breakdown (today)
	prows, err := s.db.Pool.Query(ctx, `
		SELECT payment_method, COALESCE(SUM(total),0), COUNT(*)
		FROM orders WHERE status='completed' AND created_at >= $1
		GROUP BY payment_method
	`, todayStart)
	if err == nil {
		defer prows.Close()
		for prows.Next() {
			pb := models.PaymentBreakdownItem{}
			if prows.Scan(&pb.Method, &pb.Amount, &pb.Count) == nil {
				stats.PaymentBreakdown = append(stats.PaymentBreakdown, pb)
			}
		}
	}

	if err := s.cache.Set(ctx, cacheDashboard, stats, cacheDashboardTTL); err != nil {
		fmt.Printf("warning: failed to cache dashboard stats: %v\n", err)
	}
	return stats, nil
}
