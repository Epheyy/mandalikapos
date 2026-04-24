package models

import (
	"time"

	"github.com/google/uuid"
)

type Shift struct {
	ID            uuid.UUID  `json:"id"`
	OutletID      uuid.UUID  `json:"outlet_id"`
	OutletName    *string    `json:"outlet_name,omitempty"`
	CashierID     uuid.UUID  `json:"cashier_id"`
	CashierName   string     `json:"cashier_name"`
	Status        string     `json:"status"`
	OpenedAt      time.Time  `json:"opened_at"`
	ClosedAt      *time.Time `json:"closed_at,omitempty"`
	StartingCash  int64      `json:"starting_cash"`
	ClosingCash   *int64     `json:"closing_cash,omitempty"`
	TotalSales    int64      `json:"total_sales"`
	TotalOrders   int        `json:"total_orders"`
	TotalRefunds  int64      `json:"total_refunds"`
	CashSales     int64      `json:"cash_sales"`
	CardSales     int64      `json:"card_sales"`
	TransferSales int64      `json:"transfer_sales"`
	QrisSales     int64      `json:"qris_sales"`
}

type OpenShiftRequest struct {
	OutletID     string `json:"outlet_id"`
	StartingCash int64  `json:"starting_cash"`
}

type CloseShiftRequest struct {
	ClosingCash int64 `json:"closing_cash"`
}
