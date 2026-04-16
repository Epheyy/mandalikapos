package database

import (
	"fmt"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres" // postgres driver
	_ "github.com/golang-migrate/migrate/v4/source/file"       // file source
)

// RunMigrations applies all pending SQL migration files.
// Migration files live in backend/migrations/ and are named:
//
//	001_initial_schema.sql
//	002_add_loyalty_conditions.sql
//	etc.
//
// Migrations are tracked in a special "schema_migrations" table in the database,
// so each migration runs only once — even if you restart the app many times.
func RunMigrations(databaseURL, migrationsPath string) error {
	m, err := migrate.New(
		fmt.Sprintf("file://%s", migrationsPath),
		databaseURL,
	)
	if err != nil {
		return fmt.Errorf("failed to create migrator: %w", err)
	}
	defer m.Close()

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return fmt.Errorf("migration failed: %w", err)
	}

	if err == migrate.ErrNoChange {
		fmt.Println("✅ Database schema is up to date")
	} else {
		fmt.Println("✅ Database migrations applied successfully")
	}

	return nil
}
