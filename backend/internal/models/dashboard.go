package models

type DashboardStats struct {
	TodaySales       int64        `json:"today_sales"`
	TodayOrders      int          `json:"today_orders"`
	TodayCustomers   int          `json:"today_customers"`
	WeekSales        int64        `json:"week_sales"`
	MonthSales       int64        `json:"month_sales"`
	TopProducts      []TopProduct `json:"top_products"`
	SalesByDay       []DaySales   `json:"sales_by_day"`
	PaymentBreakdown []PaymentBreakdownItem `json:"payment_breakdown"`
}

type TopProduct struct {
	ProductName string `json:"product_name"`
	VariantSize string `json:"variant_size"`
	Quantity    int    `json:"quantity"`
	Revenue     int64  `json:"revenue"`
}

type DaySales struct {
	Date  string `json:"date"`
	Sales int64  `json:"sales"`
	Orders int   `json:"orders"`
}

type PaymentBreakdownItem struct {
	Method  string `json:"method"`
	Amount  int64  `json:"amount"`
	Count   int    `json:"count"`
}
