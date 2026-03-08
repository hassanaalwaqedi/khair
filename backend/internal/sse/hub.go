package sse

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
)

// Event represents an SSE event to broadcast
type Event struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

// Hub manages connected SSE clients and broadcasts events
type Hub struct {
	mu      sync.RWMutex
	clients map[chan Event]struct{}
}

// NewHub creates a new SSE hub
func NewHub() *Hub {
	return &Hub{
		clients: make(map[chan Event]struct{}),
	}
}

// Register adds a new client channel
func (h *Hub) Register() chan Event {
	ch := make(chan Event, 10) // buffered to avoid blocking
	h.mu.Lock()
	h.clients[ch] = struct{}{}
	h.mu.Unlock()
	return ch
}

// Unregister removes a client channel
func (h *Hub) Unregister(ch chan Event) {
	h.mu.Lock()
	delete(h.clients, ch)
	close(ch)
	h.mu.Unlock()
}

// Broadcast sends an event to all connected clients
func (h *Hub) Broadcast(eventType string, data interface{}) {
	event := Event{Type: eventType, Data: data}
	h.mu.RLock()
	defer h.mu.RUnlock()

	for ch := range h.clients {
		select {
		case ch <- event:
		default:
			// Client channel full, skip to avoid blocking
			log.Printf("SSE: dropping event for slow client")
		}
	}
}

// ServeHTTP is a Gin handler that keeps an SSE connection open
func (h *Hub) ServeHTTP(c *gin.Context) {
	// Set SSE headers
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("Access-Control-Allow-Origin", "*")

	// Register this client
	ch := h.Register()
	defer h.Unregister(ch)

	// Flush the headers
	c.Writer.Flush()

	// Get the request context for detecting client disconnects
	ctx := c.Request.Context()

	// Send a heartbeat to confirm connection
	fmt.Fprintf(c.Writer, "event: connected\ndata: {\"status\":\"connected\"}\n\n")
	c.Writer.(http.Flusher).Flush()

	for {
		select {
		case <-ctx.Done():
			// Client disconnected
			return
		case event, ok := <-ch:
			if !ok {
				return
			}
			data, err := json.Marshal(event.Data)
			if err != nil {
				continue
			}
			fmt.Fprintf(c.Writer, "event: %s\ndata: %s\n\n", event.Type, string(data))
			c.Writer.(http.Flusher).Flush()
		}
	}
}
