package models

import (
	"time"

	"github.com/google/uuid"
)

type Order struct {
	ID              uuid.UUID   `json:"id"`
	OrderNumber     string      `json:"order_number"`
	OutletID        uuid.UUID   `json:"outlet_id"`
	CashierID       uuid.UUID   `json:"cashier_id"`
	CashierName     string      `json:"cashier_name"`
	CustomerID      *uuid.UUID  `json:"customer_id,omitempty"`
	CustomerName    *string     `json:"customer_name,omitempty"`
	Items           []OrderItem `json:"items"`
	Subtotal        int64       `json:"subtotal"`
	DiscountAmount  int64       `json:"discount_amount"`
	TaxAmount       int64       `json:"tax_amount"`
	SurchargeAmount int64       `json:"surcharge_amount"`
	Total           int64       `json:"total"`
	PaymentMethod   string      `json:"payment_method"`
	AmountPaid      int64       `json:"amount_paid"`
	ChangeAmount    int64       `json:"change_amount"`
	Status          string      `json:"status"`
	Notes           *string     `json:"notes,omitempty"`
	RefundReason    *string     `json:"refund_reason,omitempty"`
	RefundedAt      *time.Time  `json:"refunded_at,omitempty"`
	CreatedAt       time.Time   `json:"created_at"`
}

type OrderItem struct {
	ID          uuid.UUID `json:"id"`
	OrderID     uuid.UUID `json:"order_id"`
	ProductID   uuid.UUID `json:"product_id"`
	VariantID   uuid.UUID `json:"variant_id"`
	ProductName string    `json:"product_name"`
	VariantSize string    `json:"variant_size"`
	Price       int64     `json:"price"`
	Quantity    int       `json:"quantity"`
	Subtotal    int64     `json:"subtotal"`
}

type CreateOrderRequest struct {
	Items          []CreateOrderItemRequest `json:"items"`
	Subtotal       int64                    `json:"subtotal"`
	DiscountAmount int64                    `json:"discount_amount"`
	TaxAmount      int64                    `json:"tax_amount"`
	Total          int64                    `json:"total"`
	PaymentMethod  string                   `json:"payment_method"`
	AmountPaid     int64                    `json:"amount_paid"`
	ChangeAmount   int64                    `json:"change_amount"`
	CustomerID     *string                  `json:"customer_id,omitempty"`
	Notes          *string                  `json:"notes,omitempty"`
	OutletID       string                   `json:"outlet_id"`
}

type CreateOrderItemRequest struct {
	ProductID   string `json:"product_id"`
	VariantID   string `json:"variant_id"`
	ProductName string `json:"product_name"`
	VariantSize string `json:"variant_size"`
	Price       int64  `json:"price"`
	Quantity    int    `json:"quantity"`
	Subtotal    int64  `json:"subtotal"`
}
