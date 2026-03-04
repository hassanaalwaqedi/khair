package payment

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/khair/backend/pkg/response"
)

// Handler handles payment HTTP requests
type Handler struct {
	service *Service
}

// NewHandler creates a new payment handler
func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes registers payment routes
func (h *Handler) RegisterRoutes(r *gin.RouterGroup, authMiddleware gin.HandlerFunc) {
	// Public routes — ticket listing (uses /tickets/event/:id to avoid conflict with /events/:id)
	r.GET("/tickets/event/:id", h.ListTickets)

	// Authenticated routes
	pay := r.Group("/payments")
	pay.Use(authMiddleware)
	{
		pay.POST("/checkout", h.CreateCheckout)
		pay.GET("/orders", h.MyOrders)
		pay.POST("/orders/:id/refund", h.RequestRefund)
	}

	// Organizer routes (ticket management)
	orgTickets := r.Group("/organizer/tickets")
	orgTickets.Use(authMiddleware)
	{
		orgTickets.POST("/:id", h.CreateTicket) // :id = event ID
	}

	// Webhook (no auth — Stripe signs it)
	r.POST("/webhooks/stripe", h.StripeWebhook)
}

// ── Request/Response Types ──

// CreateTicketRequest is the request body for creating a ticket
type CreateTicketRequest struct {
	Name        string  `json:"name" binding:"required"`
	Description *string `json:"description"`
	Price       float64 `json:"price"`
	Currency    string  `json:"currency"`
	Quantity    int     `json:"quantity" binding:"required,min=1"`
}

// CheckoutRequest is the request body for creating a checkout
type CheckoutRequest struct {
	EventID  string `json:"event_id" binding:"required"`
	TicketID string `json:"ticket_id" binding:"required"`
	Quantity int    `json:"quantity" binding:"required,min=1"`
}

// RefundRequest is the request body for requesting a refund
type RefundRequest struct {
	Reason string `json:"reason" binding:"required"`
}

// ── Handlers ──

// ListTickets returns all tickets for an event
// @Summary List event tickets
// @Tags payments
// @Produce json
// @Param eventId path string true "Event ID"
// @Success 200 {array} Ticket
// @Router /events/{eventId}/tickets [get]
func (h *Handler) ListTickets(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	tickets, err := h.service.GetEventTickets(eventID)
	if err != nil {
		response.InternalServerError(c, "Failed to get tickets")
		return
	}

	response.Success(c, tickets)
}

// CreateTicket creates a new ticket type for an event
// @Summary Create event ticket
// @Tags payments
// @Accept json
// @Produce json
// @Param eventId path string true "Event ID"
// @Param request body CreateTicketRequest true "Ticket details"
// @Success 201 {object} Ticket
// @Router /organizer/events/{eventId}/tickets [post]
func (h *Handler) CreateTicket(c *gin.Context) {
	eventID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}

	var req CreateTicketRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	if req.Currency == "" {
		req.Currency = "USD"
	}

	ticket, err := h.service.CreateTicket(eventID, req.Name, req.Price, req.Currency, req.Quantity, req.Description)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Created(c, ticket)
}

// CreateCheckout starts the checkout flow for a paid ticket
// @Summary Start checkout
// @Tags payments
// @Accept json
// @Produce json
// @Param request body CheckoutRequest true "Checkout details"
// @Success 200 {object} map[string]interface{}
// @Router /payments/checkout [post]
func (h *Handler) CreateCheckout(c *gin.Context) {
	var req CheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	eventID, err := uuid.Parse(req.EventID)
	if err != nil {
		response.BadRequest(c, "Invalid event ID")
		return
	}
	ticketID, err := uuid.Parse(req.TicketID)
	if err != nil {
		response.BadRequest(c, "Invalid ticket ID")
		return
	}

	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	order, checkoutURL, err := h.service.CreateCheckout(uid, eventID, ticketID, req.Quantity)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	result := map[string]interface{}{
		"order": order,
	}
	if checkoutURL != "" {
		result["checkout_url"] = checkoutURL
	}

	response.Success(c, result)
}

// MyOrders returns the authenticated user's orders
// @Summary My orders
// @Tags payments
// @Produce json
// @Success 200 {array} Order
// @Router /payments/orders [get]
func (h *Handler) MyOrders(c *gin.Context) {
	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	orders, err := h.service.GetUserOrders(uid)
	if err != nil {
		response.InternalServerError(c, "Failed to get orders")
		return
	}

	response.Success(c, orders)
}

// RequestRefund initiates a refund for an order
// @Summary Request refund
// @Tags payments
// @Accept json
// @Produce json
// @Param id path string true "Order ID"
// @Param request body RefundRequest true "Refund details"
// @Success 200 {object} map[string]string
// @Router /payments/orders/{id}/refund [post]
func (h *Handler) RequestRefund(c *gin.Context) {
	orderID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		response.BadRequest(c, "Invalid order ID")
		return
	}

	var req RefundRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Invalid request: "+err.Error())
		return
	}

	userID, _ := c.Get("user_id")
	uid, _ := userID.(uuid.UUID)

	if err := h.service.RequestRefund(orderID, uid, req.Reason); err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.SuccessWithMessage(c, "Refund initiated", nil)
}

// StripeWebhook handles Stripe webhook events
// @Summary Stripe webhook
// @Tags payments
// @Accept json
// @Produce json
// @Router /webhooks/stripe [post]
func (h *Handler) StripeWebhook(c *gin.Context) {
	// TODO: Verify Stripe signature using webhook secret
	// sig := c.GetHeader("Stripe-Signature")
	// event, err := webhook.ConstructEvent(body, sig, h.service.config.StripeWebhookKey)

	var event struct {
		Type string                 `json:"type"`
		Data map[string]interface{} `json:"data"`
	}

	if err := c.ShouldBindJSON(&event); err != nil {
		response.BadRequest(c, "Invalid webhook payload")
		return
	}

	switch event.Type {
	case "checkout.session.completed":
		if obj, ok := event.Data["object"].(map[string]interface{}); ok {
			if sessionID, ok := obj["id"].(string); ok {
				if err := h.service.HandlePaymentSuccess(sessionID); err != nil {
					response.InternalServerError(c, "Failed to process payment")
					return
				}
			}
		}
	// TODO: Handle other event types (payment_intent.payment_failed, refund.created, etc.)
	default:
		// Acknowledge unhandled events
	}

	c.JSON(200, map[string]string{"status": "ok"})
}
