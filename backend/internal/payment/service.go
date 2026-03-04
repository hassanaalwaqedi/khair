package payment

import (
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// ── Models ──

// Ticket represents a ticket type for an event
type Ticket struct {
	ID          uuid.UUID  `json:"id"`
	EventID     uuid.UUID  `json:"event_id"`
	Name        string     `json:"name"`
	Description *string    `json:"description,omitempty"`
	Price       float64    `json:"price"`
	Currency    string     `json:"currency"`
	Quantity    int        `json:"quantity"`
	SoldCount   int        `json:"sold_count"`
	IsFree      bool       `json:"is_free"`
	SaleStart   *time.Time `json:"sale_start,omitempty"`
	SaleEnd     *time.Time `json:"sale_end,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

// Order represents a ticket purchase
type Order struct {
	ID                      uuid.UUID  `json:"id"`
	UserID                  uuid.UUID  `json:"user_id"`
	EventID                 uuid.UUID  `json:"event_id"`
	TicketID                uuid.UUID  `json:"ticket_id"`
	Quantity                int        `json:"quantity"`
	TotalAmount             float64    `json:"total_amount"`
	PlatformFee             float64    `json:"platform_fee"`
	OrganizerPayout         float64    `json:"organizer_payout"`
	Currency                string     `json:"currency"`
	Status                  string     `json:"status"`
	StripePaymentIntentID   *string    `json:"stripe_payment_intent_id,omitempty"`
	StripeCheckoutSessionID *string    `json:"stripe_checkout_session_id,omitempty"`
	RefundID                *string    `json:"refund_id,omitempty"`
	RefundReason            *string    `json:"refund_reason,omitempty"`
	RefundedAt              *time.Time `json:"refunded_at,omitempty"`
	CreatedAt               time.Time  `json:"created_at"`
	UpdatedAt               time.Time  `json:"updated_at"`
}

// PaymentSettings stores Stripe Connect settings for an organizer
type PaymentSettings struct {
	ID              uuid.UUID `json:"id"`
	OrganizerID     uuid.UUID `json:"organizer_id"`
	StripeAccountID *string   `json:"stripe_account_id,omitempty"`
	StripeOnboarded bool      `json:"stripe_onboarded"`
	PayoutEnabled   bool      `json:"payout_enabled"`
	CommissionRate  float64   `json:"commission_rate"`
	Currency        string    `json:"currency"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// Payout represents a payout to an organizer
type Payout struct {
	ID               uuid.UUID  `json:"id"`
	OrganizerID      uuid.UUID  `json:"organizer_id"`
	Amount           float64    `json:"amount"`
	Currency         string     `json:"currency"`
	Status           string     `json:"status"`
	StripeTransferID *string    `json:"stripe_transfer_id,omitempty"`
	PeriodStart      time.Time  `json:"period_start"`
	PeriodEnd        time.Time  `json:"period_end"`
	CreatedAt        time.Time  `json:"created_at"`
	CompletedAt      *time.Time `json:"completed_at,omitempty"`
}

// ── Repository ──

// Repository handles payment database operations
type Repository struct {
	db *sql.DB
}

// NewRepository creates a new payment repository
func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// CreateTicket creates a new ticket type for an event
func (r *Repository) CreateTicket(t *Ticket) error {
	query := `
		INSERT INTO tickets (id, event_id, name, description, price, currency, quantity, sold_count, is_free, sale_start, sale_end, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 0, $8, $9, $10, NOW(), NOW())
	`
	_, err := r.db.Exec(query, t.ID, t.EventID, t.Name, t.Description, t.Price, t.Currency, t.Quantity, t.IsFree, t.SaleStart, t.SaleEnd)
	return err
}

// GetTicketsByEvent returns all tickets for an event
func (r *Repository) GetTicketsByEvent(eventID uuid.UUID) ([]Ticket, error) {
	query := `SELECT id, event_id, name, description, price, currency, quantity, sold_count, is_free, sale_start, sale_end, created_at, updated_at
		FROM tickets WHERE event_id = $1 ORDER BY price ASC`
	rows, err := r.db.Query(query, eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tickets []Ticket
	for rows.Next() {
		var t Ticket
		if err := rows.Scan(&t.ID, &t.EventID, &t.Name, &t.Description, &t.Price, &t.Currency, &t.Quantity, &t.SoldCount, &t.IsFree, &t.SaleStart, &t.SaleEnd, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, err
		}
		tickets = append(tickets, t)
	}
	return tickets, nil
}

// GetTicketByID returns a ticket by ID
func (r *Repository) GetTicketByID(id uuid.UUID) (*Ticket, error) {
	query := `SELECT id, event_id, name, description, price, currency, quantity, sold_count, is_free, sale_start, sale_end, created_at, updated_at
		FROM tickets WHERE id = $1`
	t := &Ticket{}
	err := r.db.QueryRow(query, id).Scan(&t.ID, &t.EventID, &t.Name, &t.Description, &t.Price, &t.Currency, &t.Quantity, &t.SoldCount, &t.IsFree, &t.SaleStart, &t.SaleEnd, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return t, nil
}

// CreateOrder creates a new order
func (r *Repository) CreateOrder(o *Order) error {
	query := `
		INSERT INTO orders (id, user_id, event_id, ticket_id, quantity, total_amount, platform_fee, organizer_payout, currency, status, stripe_checkout_session_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW())
	`
	_, err := r.db.Exec(query, o.ID, o.UserID, o.EventID, o.TicketID, o.Quantity, o.TotalAmount, o.PlatformFee, o.OrganizerPayout, o.Currency, o.Status, o.StripeCheckoutSessionID)
	return err
}

// UpdateOrderStatus updates the status of an order
func (r *Repository) UpdateOrderStatus(orderID uuid.UUID, status string, paymentIntentID *string) error {
	query := `UPDATE orders SET status = $1, stripe_payment_intent_id = $2, updated_at = NOW() WHERE id = $3`
	_, err := r.db.Exec(query, status, paymentIntentID, orderID)
	return err
}

// GetOrderByCheckoutSession retrieves an order by Stripe checkout session ID
func (r *Repository) GetOrderByCheckoutSession(sessionID string) (*Order, error) {
	query := `SELECT id, user_id, event_id, ticket_id, quantity, total_amount, platform_fee, organizer_payout, currency, status, stripe_payment_intent_id, stripe_checkout_session_id, refund_id, refund_reason, refunded_at, created_at, updated_at
		FROM orders WHERE stripe_checkout_session_id = $1`
	o := &Order{}
	err := r.db.QueryRow(query, sessionID).Scan(&o.ID, &o.UserID, &o.EventID, &o.TicketID, &o.Quantity, &o.TotalAmount, &o.PlatformFee, &o.OrganizerPayout, &o.Currency, &o.Status, &o.StripePaymentIntentID, &o.StripeCheckoutSessionID, &o.RefundID, &o.RefundReason, &o.RefundedAt, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// GetOrderByID retrieves an order by ID
func (r *Repository) GetOrderByID(id uuid.UUID) (*Order, error) {
	query := `SELECT id, user_id, event_id, ticket_id, quantity, total_amount, platform_fee, organizer_payout, currency, status, stripe_payment_intent_id, stripe_checkout_session_id, refund_id, refund_reason, refunded_at, created_at, updated_at
		FROM orders WHERE id = $1`
	o := &Order{}
	err := r.db.QueryRow(query, id).Scan(&o.ID, &o.UserID, &o.EventID, &o.TicketID, &o.Quantity, &o.TotalAmount, &o.PlatformFee, &o.OrganizerPayout, &o.Currency, &o.Status, &o.StripePaymentIntentID, &o.StripeCheckoutSessionID, &o.RefundID, &o.RefundReason, &o.RefundedAt, &o.CreatedAt, &o.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return o, nil
}

// GetUserOrders returns all orders for a user
func (r *Repository) GetUserOrders(userID uuid.UUID) ([]Order, error) {
	query := `SELECT id, user_id, event_id, ticket_id, quantity, total_amount, platform_fee, organizer_payout, currency, status, stripe_payment_intent_id, stripe_checkout_session_id, refund_id, refund_reason, refunded_at, created_at, updated_at
		FROM orders WHERE user_id = $1 ORDER BY created_at DESC`
	rows, err := r.db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.UserID, &o.EventID, &o.TicketID, &o.Quantity, &o.TotalAmount, &o.PlatformFee, &o.OrganizerPayout, &o.Currency, &o.Status, &o.StripePaymentIntentID, &o.StripeCheckoutSessionID, &o.RefundID, &o.RefundReason, &o.RefundedAt, &o.CreatedAt, &o.UpdatedAt); err != nil {
			return nil, err
		}
		orders = append(orders, o)
	}
	return orders, nil
}

// RefundOrder marks an order as refunded
func (r *Repository) RefundOrder(orderID uuid.UUID, refundID, reason string) error {
	query := `UPDATE orders SET status = 'refunded', refund_id = $1, refund_reason = $2, refunded_at = NOW(), updated_at = NOW() WHERE id = $3`
	_, err := r.db.Exec(query, refundID, reason, orderID)
	return err
}

// IncrementTicketSold increments the sold count for a ticket (atomic)
func (r *Repository) IncrementTicketSold(ticketID uuid.UUID, qty int) error {
	query := `UPDATE tickets SET sold_count = sold_count + $1, updated_at = NOW()
		WHERE id = $2 AND (quantity - sold_count) >= $1`
	result, err := r.db.Exec(query, qty, ticketID)
	if err != nil {
		return err
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return errors.New("insufficient ticket availability")
	}
	return nil
}

// ── Service ──

// Config holds payment configuration
type Config struct {
	StripeSecretKey  string
	StripeWebhookKey string
	CommissionRate   float64 // e.g., 0.10 for 10%
	SuccessURL       string
	CancelURL        string
}

// Service handles payment business logic
type Service struct {
	repo   *Repository
	config Config
}

// NewService creates a new payment service
func NewService(repo *Repository, cfg Config) *Service {
	if cfg.CommissionRate == 0 {
		cfg.CommissionRate = 0.10 // 10% default
	}
	return &Service{repo: repo, config: cfg}
}

// CreateTicket creates a new ticket type for an event
func (s *Service) CreateTicket(eventID uuid.UUID, name string, price float64, currency string, quantity int, description *string) (*Ticket, error) {
	isFree := price == 0

	t := &Ticket{
		ID:          uuid.New(),
		EventID:     eventID,
		Name:        name,
		Description: description,
		Price:       price,
		Currency:    currency,
		Quantity:    quantity,
		IsFree:      isFree,
	}

	if err := s.repo.CreateTicket(t); err != nil {
		return nil, fmt.Errorf("failed to create ticket: %w", err)
	}
	return t, nil
}

// GetEventTickets returns all tickets for an event
func (s *Service) GetEventTickets(eventID uuid.UUID) ([]Ticket, error) {
	return s.repo.GetTicketsByEvent(eventID)
}

// CreateCheckout initiates a checkout for a paid ticket
func (s *Service) CreateCheckout(userID, eventID, ticketID uuid.UUID, quantity int) (*Order, string, error) {
	// Get ticket
	ticket, err := s.repo.GetTicketByID(ticketID)
	if err != nil {
		return nil, "", errors.New("ticket not found")
	}

	// Verify availability
	available := ticket.Quantity - ticket.SoldCount
	if available < quantity {
		return nil, "", fmt.Errorf("only %d tickets available", available)
	}

	// Calculate amounts
	totalAmount := ticket.Price * float64(quantity)
	platformFee := totalAmount * s.config.CommissionRate
	organizerPayout := totalAmount - platformFee

	// For free tickets, complete immediately
	if ticket.IsFree {
		order := &Order{
			ID:              uuid.New(),
			UserID:          userID,
			EventID:         eventID,
			TicketID:        ticketID,
			Quantity:        quantity,
			TotalAmount:     0,
			PlatformFee:     0,
			OrganizerPayout: 0,
			Currency:        ticket.Currency,
			Status:          "completed",
		}

		if err := s.repo.CreateOrder(order); err != nil {
			return nil, "", errors.New("failed to create order")
		}
		if err := s.repo.IncrementTicketSold(ticketID, quantity); err != nil {
			return nil, "", errors.New("failed to reserve tickets")
		}
		return order, "", nil
	}

	// For paid tickets, create a pending order
	// In production, this would create a Stripe Checkout Session
	checkoutSessionID := "cs_placeholder_" + uuid.New().String()
	order := &Order{
		ID:                      uuid.New(),
		UserID:                  userID,
		EventID:                 eventID,
		TicketID:                ticketID,
		Quantity:                quantity,
		TotalAmount:             totalAmount,
		PlatformFee:             platformFee,
		OrganizerPayout:         organizerPayout,
		Currency:                ticket.Currency,
		Status:                  "pending",
		StripeCheckoutSessionID: &checkoutSessionID,
	}

	if err := s.repo.CreateOrder(order); err != nil {
		return nil, "", errors.New("failed to create order")
	}

	// TODO: Replace with actual Stripe Checkout Session creation
	// session, err := stripe.CheckoutSessions.New(&stripe.CheckoutSessionParams{...})
	checkoutURL := fmt.Sprintf("/checkout/placeholder?session=%s", checkoutSessionID)

	return order, checkoutURL, nil
}

// HandlePaymentSuccess processes a successful payment (called from webhook)
func (s *Service) HandlePaymentSuccess(checkoutSessionID string) error {
	order, err := s.repo.GetOrderByCheckoutSession(checkoutSessionID)
	if err != nil {
		return errors.New("order not found")
	}

	if order.Status != "pending" {
		return nil // Already processed, idempotent
	}

	// Reserve tickets atomically
	if err := s.repo.IncrementTicketSold(order.TicketID, order.Quantity); err != nil {
		return err
	}

	return s.repo.UpdateOrderStatus(order.ID, "completed", nil)
}

// RequestRefund initiates a refund for an order
func (s *Service) RequestRefund(orderID uuid.UUID, userID uuid.UUID, reason string) error {
	order, err := s.repo.GetOrderByID(orderID)
	if err != nil {
		return errors.New("order not found")
	}

	if order.UserID != userID {
		return errors.New("you can only refund your own orders")
	}

	if order.Status != "completed" {
		return errors.New("only completed orders can be refunded")
	}

	// TODO: Create actual Stripe refund
	// refund, err := stripe.Refunds.New(&stripe.RefundParams{...})
	refundID := "re_placeholder_" + uuid.New().String()

	return s.repo.RefundOrder(orderID, refundID, reason)
}

// GetUserOrders returns all orders for the authenticated user
func (s *Service) GetUserOrders(userID uuid.UUID) ([]Order, error) {
	return s.repo.GetUserOrders(userID)
}
