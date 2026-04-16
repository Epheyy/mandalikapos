// Package database manages the PostgreSQL connection pool.
// We use pgxpool which maintains multiple connections for concurrent requests,
// which is critical for a POS system where multiple cashiers may hit the API simultaneously.
package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// DB wraps the connection pool with helper methods.
type DB struct {
	Pool *pgxpool.Pool
}

// Connect creates a new PostgreSQL connection pool.
// It retries a few times in case the database container is still starting.
func Connect(databaseURL string) (*DB, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse database URL: %w", err)
	}

	// Connection pool tuning:
	// MaxConns: maximum number of database connections.
	// For a POS system, 10 is plenty for multiple cashiers.
	config.MaxConns = 10

	// MinConns: connections to keep open even when idle.
	// Keeps the app responsive for sudden bursts of traffic.
	config.MinConns = 2

	// MaxConnLifetime: close and reopen connections after 1 hour
	// to prevent stale connections.
	config.MaxConnLifetime = time.Hour

	// MaxConnIdleTime: close idle connections after 30 minutes.
	config.MaxConnIdleTime = 30 * time.Minute

	// Attempt to connect with retries (useful when Docker starts both
	// the app and database at the same time)
	var pool *pgxpool.Pool
	maxRetries := 5
	for attempt := 1; attempt <= maxRetries; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		pool, err = pgxpool.NewWithConfig(ctx, config)
		cancel()

		if err == nil {
			// Verify the connection actually works
			pingCtx, pingCancel := context.WithTimeout(context.Background(), 5*time.Second)
			err = pool.Ping(pingCtx)
			pingCancel()
			if err == nil {
				break
			}
		}

		if attempt == maxRetries {
			return nil, fmt.Errorf("failed to connect to database after %d attempts: %w", maxRetries, err)
		}

		fmt.Printf("Database not ready, retrying in 2 seconds (attempt %d/%d)...\n", attempt, maxRetries)
		time.Sleep(2 * time.Second)
	}

	fmt.Println("✅ Connected to PostgreSQL successfully")
	return &DB{Pool: pool}, nil
}

// Close cleanly shuts down the connection pool.
// Always call this when the application is shutting down.
func (db *DB) Close() {
	db.Pool.Close()
	fmt.Println("PostgreSQL connection pool closed")
}

// HealthCheck verifies the database is still reachable.
// Used by the /health endpoint to monitor the application.
func (db *DB) HealthCheck(ctx context.Context) error {
	return db.Pool.Ping(ctx)
}
