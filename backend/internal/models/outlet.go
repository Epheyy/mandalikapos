package models

import (
	"time"

	"github.com/google/uuid"
)

type Outlet struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Address   *string   `json:"address,omitempty"`
	Phone     *string   `json:"phone,omitempty"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type CreateOutletRequest struct {
	Name     string  `json:"name"`
	Address  *string `json:"address,omitempty"`
	Phone    *string `json:"phone,omitempty"`
	IsActive *bool   `json:"is_active,omitempty"`
}

type UpdateOutletRequest struct {
	Name     *string `json:"name,omitempty"`
	Address  *string `json:"address,omitempty"`
	Phone    *string `json:"phone,omitempty"`
	IsActive *bool   `json:"is_active,omitempty"`
}
