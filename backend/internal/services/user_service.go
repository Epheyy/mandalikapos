// Package services contains business logic — the "what should happen"
// layer between HTTP handlers and the database.
package services

import (
	"context"
	"fmt"
	"time"

	"github.com/Epheyy/mandalikapos/backend/internal/database"
	"github.com/Epheyy/mandalikapos/backend/internal/models"
	"github.com/google/uuid"
)

// UserService handles all user-related database operations.
type UserService struct {
	db *database.DB
}

// NewUserService creates a new UserService.
func NewUserService(db *database.DB) *UserService {
	return &UserService{db: db}
}

// GetOrCreateByFirebaseUID looks up a user by their Firebase UID.
// If the user doesn't exist yet (first login), it creates a new record.
// This is called every time the Flutter app verifies auth with the backend.
func (s *UserService) GetOrCreateByFirebaseUID(
	ctx context.Context,
	firebaseUID, email, displayName, photoURL string,
) (*models.User, error) {

	// First try to find an existing user
	user, err := s.getByFirebaseUID(ctx, firebaseUID)
	if err == nil {
		// User exists — update their display name and photo in case they changed it in Google
		if err := s.updateProfile(ctx, user.ID, displayName, photoURL); err != nil {
			return nil, fmt.Errorf("failed to update user profile: %w", err)
		}
		user.DisplayName = displayName
		if photoURL != "" {
			user.PhotoURL = &photoURL
		}
		return user, nil
	}

	// User doesn't exist — create them
	// Check if this is the admin email (bootstraps the first admin account)
	role := "cashier"
	if email == "mandalikareffy@gmail.com" {
		role = "admin"
	}

	newUser := &models.User{
		ID:          uuid.New(),
		FirebaseUID: firebaseUID,
		DisplayName: displayName,
		Email:       email,
		Role:        role,
		IsActive:    true,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	if photoURL != "" {
		newUser.PhotoURL = &photoURL
	}

	if err := s.create(ctx, newUser); err != nil {
		return nil, fmt.Errorf("failed to create user: %w", err)
	}

	return newUser, nil
}

// GetByID fetches a user by their internal UUID.
func (s *UserService) GetByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	user := &models.User{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, firebase_uid, display_name, email, role,
		       photo_url, outlet_id, is_active, created_at, updated_at
		FROM users
		WHERE id = $1 AND is_active = TRUE
	`, id).Scan(
		&user.ID, &user.FirebaseUID, &user.DisplayName, &user.Email,
		&user.Role, &user.PhotoURL, &user.OutletID, &user.IsActive,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// Load permissions
	user.Permissions, err = s.getPermissions(ctx, user.ID)
	if err != nil {
		return nil, err
	}

	return user, nil
}

// GetAllUsers returns all users for the admin panel.
func (s *UserService) GetAllUsers(ctx context.Context) ([]*models.User, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT id, firebase_uid, display_name, email, role,
		       photo_url, outlet_id, is_active, created_at, updated_at
		FROM users
		ORDER BY created_at DESC
	`)
	if err != nil {
		return nil, fmt.Errorf("failed to query users: %w", err)
	}
	defer rows.Close()

	var users []*models.User
	for rows.Next() {
		u := &models.User{}
		if err := rows.Scan(
			&u.ID, &u.FirebaseUID, &u.DisplayName, &u.Email,
			&u.Role, &u.PhotoURL, &u.OutletID, &u.IsActive,
			&u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		u.Permissions, _ = s.getPermissions(ctx, u.ID)
		users = append(users, u)
	}

	return users, nil
}

// UpdateUserRole changes a user's role and permissions.
func (s *UserService) UpdateUserRole(
	ctx context.Context,
	userID uuid.UUID,
	role string,
	permissions []string,
) error {
	// Validate role
	validRoles := map[string]bool{"admin": true, "manager": true, "cashier": true}
	if !validRoles[role] {
		return fmt.Errorf("invalid role: %s", role)
	}

	// Use a transaction — both operations must succeed or both fail
	tx, err := s.db.Pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx) // rolls back only if Commit() was never called

	// Update role
	if _, err := tx.Exec(ctx, `
		UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2
	`, role, userID); err != nil {
		return fmt.Errorf("failed to update role: %w", err)
	}

	// Replace all permissions — delete old ones first
	if _, err := tx.Exec(ctx, `
		DELETE FROM user_permissions WHERE user_id = $1
	`, userID); err != nil {
		return fmt.Errorf("failed to clear permissions: %w", err)
	}

	// Insert new permissions
	for _, perm := range permissions {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_permissions (user_id, permission) VALUES ($1, $2)
		`, userID, perm); err != nil {
			return fmt.Errorf("failed to insert permission %s: %w", perm, err)
		}
	}

	return tx.Commit(ctx)
}

// ── Private helpers ──────────────────────────────────────────

func (s *UserService) getByFirebaseUID(ctx context.Context, uid string) (*models.User, error) {
	user := &models.User{}
	err := s.db.Pool.QueryRow(ctx, `
		SELECT id, firebase_uid, display_name, email, role,
		       photo_url, outlet_id, is_active, created_at, updated_at
		FROM users WHERE firebase_uid = $1
	`, uid).Scan(
		&user.ID, &user.FirebaseUID, &user.DisplayName, &user.Email,
		&user.Role, &user.PhotoURL, &user.OutletID, &user.IsActive,
		&user.CreatedAt, &user.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return user, nil
}

func (s *UserService) create(ctx context.Context, u *models.User) error {
	_, err := s.db.Pool.Exec(ctx, `
		INSERT INTO users (id, firebase_uid, display_name, email, role, photo_url, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, u.ID, u.FirebaseUID, u.DisplayName, u.Email, u.Role, u.PhotoURL, u.IsActive, u.CreatedAt, u.UpdatedAt)
	return err
}

func (s *UserService) updateProfile(ctx context.Context, id uuid.UUID, displayName, photoURL string) error {
	_, err := s.db.Pool.Exec(ctx, `
		UPDATE users SET display_name = $1, photo_url = $2, updated_at = NOW() WHERE id = $3
	`, displayName, photoURL, id)
	return err
}

func (s *UserService) getPermissions(ctx context.Context, userID uuid.UUID) ([]string, error) {
	rows, err := s.db.Pool.Query(ctx, `
		SELECT permission FROM user_permissions WHERE user_id = $1
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var permissions []string
	for rows.Next() {
		var p string
		if err := rows.Scan(&p); err != nil {
			return nil, err
		}
		permissions = append(permissions, p)
	}
	return permissions, nil
}
