package models

type SalesReport struct {
	From     string           `json:"from"`
	To       string           `json:"to"`
	GroupBy  string           `json:"group_by"`
	Total    int64            `json:"total"`
	Orders   int              `json:"orders"`
	Periods  []ReportPeriod   `json:"periods"`
	Products []TopProduct     `json:"top_products"`
	Payment  []PaymentBreakdownItem `json:"payment_breakdown"`
}

type ReportPeriod struct {
	Label  string `json:"label"`
	Sales  int64  `json:"sales"`
	Orders int    `json:"orders"`
}
