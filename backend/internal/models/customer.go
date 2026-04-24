package models

import (
	"time"

	"github.com/google/uuid"
)

type Customer struct {
	ID         uuid.UUID  `json:"id"`
	Name       string     `json:"name"`
	Phone      string     `json:"phone"`
	Email      *string    `json:"email,omitempty"`
	Points     int        `json:"points"`
	TotalSpent int64      `json:"total_spent"`
	VisitCount int        `json:"visit_count"`
	LastVisit  *time.Time `json:"last_visit,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

type CreateCustomerRequest struct {
	Name  string  `json:"name"`
	Phone string  `json:"phone"`
	Email *string `json:"email,omitempty"`
}

type UpdateCustomerRequest struct {
	Name   *string `json:"name,omitempty"`
	Phone  *string `json:"phone,omitempty"`
	Email  *string `json:"email,omitempty"`
	Points *int    `json:"points,omitempty"`
}
