// Package models defines Go structs that map to database tables.
// These are plain data structures — no database logic here.
package models

import (
	"time"

	"github.com/google/uuid"
)

// User represents a row in the users table.
type User struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	FirebaseUID string     `json:"firebase_uid" db:"firebase_uid"`
	DisplayName string     `json:"display_name" db:"display_name"`
	Email       string     `json:"email" db:"email"`
	Role        string     `json:"role" db:"role"`
	PhotoURL    *string    `json:"photo_url,omitempty" db:"photo_url"`
	OutletID    *uuid.UUID `json:"outlet_id,omitempty" db:"outlet_id"`
	IsActive    bool       `json:"is_active" db:"is_active"`
	Permissions []string   `json:"permissions,omitempty"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

// IsAdmin returns true if this user has the admin role.
func (u *User) IsAdmin() bool {
	return u.Role == "admin"
}

// HasPermission checks if this user has a specific permission.
// Admins always return true regardless of stored permissions.
func (u *User) HasPermission(permission string) bool {
	if u.IsAdmin() {
		return true
	}
	for _, p := range u.Permissions {
		if p == permission {
			return true
		}
	}
	return false
}
