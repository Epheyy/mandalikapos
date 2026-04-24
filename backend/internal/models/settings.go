package models

type PaymentMethodConfig struct {
	ID        string `json:"id"`
	Label     string `json:"label"`
	IsEnabled bool   `json:"is_enabled"`
}

type ReceiptSettings struct {
	HeaderText          string `json:"header_text"`
	FooterText          string `json:"footer_text"`
	ShowTax             bool   `json:"show_tax"`
	ShowCashier         bool   `json:"show_cashier"`
	Copies              int    `json:"copies"`
	AutoPrint           bool   `json:"auto_print"`
	ShowOrderNumber     bool   `json:"show_order_number"`
	ShowCustomerName    bool   `json:"show_customer_name"`
	ShowDiscount        bool   `json:"show_discount"`
	ShowSubtotal        bool   `json:"show_subtotal"`
	ShowChange          bool   `json:"show_change"`
}

type AppSettings struct {
	TaxEnabled       bool                  `json:"tax_enabled"`
	TaxRate          float64               `json:"tax_rate"`
	RoundingEnabled  bool                  `json:"rounding_enabled"`
	RoundingType     string                `json:"rounding_type"`
	PaymentMethods   []PaymentMethodConfig `json:"payment_methods"`
	Receipt          ReceiptSettings       `json:"receipt"`
	AutoOpenShift    bool                  `json:"auto_open_shift"`
}

func DefaultAppSettings() AppSettings {
	return AppSettings{
		TaxEnabled:  false,
		TaxRate:     11.0,
		RoundingEnabled: false,
		RoundingType:    "none",
		PaymentMethods: []PaymentMethodConfig{
			{ID: "cash", Label: "Tunai", IsEnabled: true},
			{ID: "card", Label: "Kartu", IsEnabled: true},
			{ID: "transfer", Label: "Transfer", IsEnabled: true},
			{ID: "qris", Label: "QRIS", IsEnabled: true},
		},
		Receipt: ReceiptSettings{
			HeaderText:       "Mandalika Perfume",
			FooterText:       "Terima kasih telah berbelanja!",
			ShowTax:          false,
			ShowCashier:      true,
			Copies:           1,
			AutoPrint:        false,
			ShowOrderNumber:  true,
			ShowCustomerName: true,
			ShowDiscount:     true,
			ShowSubtotal:     true,
			ShowChange:       true,
		},
		AutoOpenShift: false,
	}
}
