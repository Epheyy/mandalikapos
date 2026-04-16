// Package config loads all environment variables and validates
// they are present before the application starts.
// This prevents the app from starting with missing configuration.
package config

import (
	"fmt"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config holds all application configuration loaded from environment variables.
// Using a struct instead of calling os.Getenv() everywhere keeps things organized
// and makes it easy to see what configuration the app needs at a glance.
type Config struct {
	// Server settings
	Port string
	Env  string

	// Database
	DatabaseURL string

	// Redis
	RedisURL string

	// Firebase
	FirebaseProjectID          string
	FirebaseServiceAccountPath string

	// Cloudinary
	CloudinaryCloudName    string
	CloudinaryUploadPreset string

	// Security
	JWTSecret      string
	AllowedOrigins string
}

// Load reads environment variables and returns a Config.
// It first tries to load a .env file (for local development),
// then reads from the system environment (for production on servers
// where environment variables are set directly).
func Load() (*Config, error) {
	// In development, load from .env file.
	// In production, this file won't exist — that's fine,
	// environment variables will be set by the platform.
	_ = godotenv.Load() // ignore error if .env doesn't exist

	cfg := &Config{
		Port:                       getEnv("PORT", "8080"),
		Env:                        getEnv("ENV", "development"),
		DatabaseURL:                requireEnv("DATABASE_URL"),
		RedisURL:                   requireEnv("REDIS_URL"),
		FirebaseProjectID:          requireEnv("FIREBASE_PROJECT_ID"),
		FirebaseServiceAccountPath: getEnv("FIREBASE_SERVICE_ACCOUNT_PATH", "internal/auth/firebase-service-account.json"),
		CloudinaryCloudName:        getEnv("CLOUDINARY_CLOUD_NAME", ""),
		CloudinaryUploadPreset:     getEnv("CLOUDINARY_UPLOAD_PRESET", ""),
		JWTSecret:                  requireEnv("JWT_SECRET"),
		AllowedOrigins:             getEnv("ALLOWED_ORIGINS", "http://localhost:3000"),
	}

	if err := cfg.validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

// validate checks that all required configuration is present and valid.
func (c *Config) validate() error {
	if len(c.JWTSecret) < 32 {
		return fmt.Errorf("JWT_SECRET must be at least 32 characters long for security")
	}
	return nil
}

// IsDevelopment returns true when running in development mode.
func (c *Config) IsDevelopment() bool {
	return c.Env == "development"
}

// getEnv returns the value of an environment variable,
// or a default value if the variable is not set.
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// requireEnv returns the value of an environment variable
// or panics with a clear message if it's not set.
// We panic at startup rather than silently running with missing config.
func requireEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		panic(fmt.Sprintf("required environment variable %q is not set — check your .env file", key))
	}
	return value
}

// getEnvInt returns an environment variable parsed as an integer.
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			return parsed
		}
	}
	return defaultValue
}
