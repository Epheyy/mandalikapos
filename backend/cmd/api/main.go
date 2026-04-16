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

	// ── Firebase Auth ──────────────────────────────────────────
	firebaseClient, err := auth.NewFirebaseClient(cfg.FirebaseServiceAccountPath)
	if err != nil {
		log.Fatalf("❌ Firebase initialization failed: %v", err)
	}

	// ── Services ───────────────────────────────────────────────
	userService := services.NewUserService(db)

	// ── Handlers ───────────────────────────────────────────────
	userHandler := handlers.NewUserHandler(userService)

	// After: userHandler := handlers.NewUserHandler(userService)
	// Add these lines:

	// Redis cache
	cache, err := redisclient.New(cfg.RedisURL)
	if err != nil {
		log.Fatalf("❌ Redis connection failed: %v", err)
	}
	defer cache.Close()

	// Product service and handler
	productService := services.NewProductService(db, cache)
	productHandler := handlers.NewProductHandler(productService)

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

	// Public health check — no auth required
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

	// All routes under /api/v1
	r.Route("/api/v1", func(r chi.Router) {

		// Products — all authenticated users can read
		r.Group(func(r chi.Router) {
			r.Use(appMiddleware.RequireAuth(firebaseClient))

			r.Get("/products", productHandler.ListActiveProducts)
			r.Get("/products/{id}", productHandler.GetProduct)
			r.Get("/categories", productHandler.ListCategories)
		})

		// Admin product management
		r.Group(func(r chi.Router) {
			r.Use(appMiddleware.RequireAuth(firebaseClient))
			r.Use(appMiddleware.RequireRole(db, "admin", "manager"))

			r.Get("/admin/products", productHandler.ListAllProducts)
			r.Post("/admin/products", productHandler.CreateProduct)
			r.Patch("/admin/products/{id}", productHandler.UpdateProduct)
			r.Delete("/admin/products/{id}", productHandler.DeleteProduct)

			r.Post("/admin/categories", productHandler.CreateCategory)
			r.Put("/admin/categories/{id}", productHandler.UpdateCategory)
			r.Delete("/admin/categories/{id}", productHandler.DeleteCategory)
		})

		// ── Auth routes (require valid Firebase token) ─────────
		r.Group(func(r chi.Router) {
			r.Use(appMiddleware.RequireAuth(firebaseClient))

			// Called by Flutter immediately after login
			r.Post("/auth/me", userHandler.Me)

			// ── Admin-only routes ──────────────────────────────
			r.Group(func(r chi.Router) {
				r.Use(appMiddleware.RequireRole(db, "admin", "manager"))
				r.Get("/users", userHandler.ListUsers)
				r.Patch("/users/{id}", userHandler.UpdateUser)
			})
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
