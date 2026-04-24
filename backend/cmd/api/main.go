package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/auth"
	"github.com/Epheyy/mandalikapos/backend/internal/config"
	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/handlers"
	appMiddleware "github.com/Epheyy/mandalikapos/backend/internal/middleware"
	redisclient "github.com/Epheyy/mandalikapos/backend/internal/redis"
	"github.com/Epheyy/mandalikapos/backend/internal/services"
	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("❌ Configuration error: %v", err)
	}
	fmt.Printf("🚀 Starting Mandalika POS Backend (env: %s)\n", cfg.Env)

	// ── Database ───────────────────────────────────────────────
	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("❌ Database connection failed: %v", err)
	}
	defer db.Close()

	if err := database.RunMigrations(cfg.DatabaseURL, "migrations"); err != nil {
		log.Fatalf("❌ Database migration failed: %v", err)
	}

	// ── Redis ──────────────────────────────────────────────────
	cache, err := redisclient.New(cfg.RedisURL)
	if err != nil {
		log.Fatalf("❌ Redis connection failed: %v", err)
	}
	defer cache.Close()

	// ── Firebase Auth ──────────────────────────────────────────
	firebaseClient, err := auth.NewFirebaseClient(cfg.FirebaseServiceAccountPath)
	if err != nil {
		log.Fatalf("❌ Firebase initialization failed: %v", err)
	}

	// ── Services ───────────────────────────────────────────────
	userService       := services.NewUserService(db)
	productService    := services.NewProductService(db, cache)
	orderService      := services.NewOrderService(db)
	customerService   := services.NewCustomerService(db)
	outletService     := services.NewOutletService(db)
	promotionService  := services.NewPromotionService(db)
	shiftService      := services.NewShiftService(db)
	settingsService   := services.NewSettingsService(db)
	dashboardService  := services.NewDashboardService(db, cache)
	reportService     := services.NewReportService(db, cache)
	stockCountService := services.NewStockCountService(db)

	// ── Handlers ───────────────────────────────────────────────
	userHandler       := handlers.NewUserHandler(userService)
	productHandler    := handlers.NewProductHandler(productService)
	orderHandler      := handlers.NewOrderHandler(orderService, userService)
	customerHandler   := handlers.NewCustomerHandler(customerService)
	outletHandler     := handlers.NewOutletHandler(outletService)
	promotionHandler  := handlers.NewPromotionHandler(promotionService)
	shiftHandler      := handlers.NewShiftHandler(shiftService, userService)
	settingsHandler   := handlers.NewSettingsHandler(settingsService)
	dashboardHandler  := handlers.NewDashboardHandler(dashboardService)
	reportHandler     := handlers.NewReportHandler(reportService)
	stockCountHandler := handlers.NewStockCountHandler(stockCountService, userService)

	// ── Router ────────────────────────────────────────────────
	r := chi.NewRouter()
	r.Use(chimiddleware.RequestID)
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.Timeout(60 * time.Second))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{cfg.AllowedOrigins},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-ID"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Public health check
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
		defer cancel()
		if err := db.HealthCheck(ctx); err != nil {
			http.Error(w, `{"status":"unhealthy"}`, http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"healthy","service":"mandalika-pos-backend"}`)
	})

	r.Route("/api/v1", func(r chi.Router) {

		// ── Authenticated routes (all roles) ──────────────────
		r.Group(func(r chi.Router) {
			r.Use(appMiddleware.RequireAuth(firebaseClient))

			// Auth
			r.Post("/auth/me", userHandler.Me)

			// Products & Categories (read)
			r.Get("/products", productHandler.ListActiveProducts)
			r.Get("/products/{id}", productHandler.GetProduct)
			r.Get("/categories", productHandler.ListCategories)

			// Orders
			r.Post("/orders", orderHandler.CreateOrder)

			// Customers (cashier can lookup and register)
			r.Get("/customers", customerHandler.ListCustomers)
			r.Post("/customers", customerHandler.CreateCustomer)

			// Shifts
			r.Get("/shifts/current", shiftHandler.GetCurrentShift)
			r.Post("/shifts/open", shiftHandler.OpenShift)
			r.Post("/shifts/close", shiftHandler.CloseShift)

			// Promotions (cashier reads active promotions)
			r.Get("/promotions/active", promotionHandler.ListActivePromotions)
			r.Post("/promotions/validate-code", promotionHandler.ValidateDiscountCode)

			// Settings (all users can read)
			r.Get("/settings", settingsHandler.GetSettings)
		})

		// ── Admin / Manager routes ─────────────────────────────
		r.Group(func(r chi.Router) {
			r.Use(appMiddleware.RequireAuth(firebaseClient))
			r.Use(appMiddleware.RequireRole(db, "admin", "manager"))

			// Products & Categories (write)
			r.Get("/admin/products", productHandler.ListAllProducts)
			r.Post("/admin/products", productHandler.CreateProduct)
			r.Patch("/admin/products/{id}", productHandler.UpdateProduct)
			r.Delete("/admin/products/{id}", productHandler.DeleteProduct)

			r.Post("/admin/categories", productHandler.CreateCategory)
			r.Put("/admin/categories/{id}", productHandler.UpdateCategory)
			r.Delete("/admin/categories/{id}", productHandler.DeleteCategory)

			// Users
			r.Get("/admin/users", userHandler.ListUsers)
			r.Patch("/admin/users/{id}", userHandler.UpdateUser)

			// Outlets
			r.Get("/admin/outlets", outletHandler.ListOutlets)
			r.Post("/admin/outlets", outletHandler.CreateOutlet)
			r.Put("/admin/outlets/{id}", outletHandler.UpdateOutlet)
			r.Delete("/admin/outlets/{id}", outletHandler.DeleteOutlet)

			// Customers (admin manages)
			r.Put("/admin/customers/{id}", customerHandler.UpdateCustomer)
			r.Delete("/admin/customers/{id}", customerHandler.DeleteCustomer)
			r.Get("/admin/customers/{id}/orders", customerHandler.GetCustomerOrders)

			// Promotions
			r.Get("/admin/promotions", promotionHandler.ListPromotions)
			r.Post("/admin/promotions", promotionHandler.CreatePromotion)
			r.Delete("/admin/promotions/{id}", promotionHandler.DeletePromotion)

			// Discount codes
			r.Get("/admin/discount-codes", promotionHandler.ListDiscountCodes)
			r.Post("/admin/discount-codes", promotionHandler.CreateDiscountCode)
			r.Delete("/admin/discount-codes/{id}", promotionHandler.DeleteDiscountCode)

			// Orders (admin view + refund)
			r.Get("/admin/orders", orderHandler.ListOrders)
			r.Put("/admin/orders/{id}/refund", orderHandler.RefundOrder)

			// Shifts
			r.Get("/admin/shifts", shiftHandler.ListShifts)

			// Settings
			r.Put("/admin/settings", settingsHandler.UpdateSettings)

			// Dashboard
			r.Get("/admin/dashboard/stats", dashboardHandler.GetStats)

			// Reports
			r.Get("/admin/reports/sales", reportHandler.GetSalesReport)

			// Stock counts
			r.Get("/admin/stock-counts", stockCountHandler.ListStockCounts)
			r.Post("/admin/stock-counts", stockCountHandler.CreateStockCount)
			r.Get("/admin/stock-counts/{id}", stockCountHandler.GetStockCount)
			r.Patch("/admin/stock-counts/{id}/items/{itemId}", stockCountHandler.UpdateItemQty)
			r.Patch("/admin/stock-counts/{id}/status", stockCountHandler.UpdateStatus)
		})
	})

	// ── Server with graceful shutdown ─────────────────────────
	server := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	serverErrors := make(chan error, 1)
	go func() {
		fmt.Printf("✅ Server listening on port %s\n", cfg.Port)
		serverErrors <- server.ListenAndServe()
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-serverErrors:
		log.Fatalf("❌ Server error: %v", err)
	case sig := <-quit:
		fmt.Printf("\n⚠️  Shutting down (%v)...\n", sig)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("❌ Forced shutdown: %v", err)
	}
	fmt.Println("✅ Server stopped cleanly")
}
