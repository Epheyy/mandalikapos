package services

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
)

const settingsKey = "app_settings"

type SettingsService struct {
	db *database.DB
}

func NewSettingsService(db *database.DB) *SettingsService {
	return &SettingsService{db: db}
}

func (s *SettingsService) GetSettings(ctx context.Context) (*models.AppSettings, error) {
	var raw json.RawMessage
	err := s.db.Pool.QueryRow(ctx, `SELECT value FROM app_settings WHERE key=$1`, settingsKey).Scan(&raw)
	if err != nil {
		// Return defaults if not yet configured
		defaults := models.DefaultAppSettings()
		return &defaults, nil
	}

	var settings models.AppSettings
	if err := json.Unmarshal(raw, &settings); err != nil {
		return nil, fmt.Errorf("failed to parse settings: %w", err)
	}
	return &settings, nil
}

func (s *SettingsService) UpdateSettings(ctx context.Context, settings *models.AppSettings) (*models.AppSettings, error) {
	data, err := json.Marshal(settings)
	if err != nil {
		return nil, fmt.Errorf("failed to serialize settings: %w", err)
	}

	_, err = s.db.Pool.Exec(ctx, `
		INSERT INTO app_settings (key, value, updated_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (key) DO UPDATE SET value=$2, updated_at=NOW()
	`, settingsKey, data)
	if err != nil {
		return nil, fmt.Errorf("failed to save settings: %w", err)
	}
	return settings, nil
}
