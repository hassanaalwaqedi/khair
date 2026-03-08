package ws

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

const (
	// redisPubSubChannel is the channel used for cross-instance event fan-out.
	redisPubSubChannel = "khair:ws:broadcast"
)

// Message is a JSON envelope pushed to WebSocket clients.
type Message struct {
	Type string      `json:"type"`
	Data interface{} `json:"data"`
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins — CORS is handled at Gin level
	},
}

// Hub manages WebSocket clients and bridges Redis Pub/Sub for horizontal scaling.
type Hub struct {
	mu         sync.RWMutex
	clients    map[*Client]struct{}
	userIndex  map[string]map[*Client]struct{} // userID → set of clients
	register   chan *Client
	unregister chan *Client
	redis      *redis.Client
	jwtSecret  string
	ctx        context.Context
	cancel     context.CancelFunc
}

// NewHub creates a new WebSocket hub.
func NewHub(redisClient *redis.Client, jwtSecret string) *Hub {
	ctx, cancel := context.WithCancel(context.Background())
	h := &Hub{
		clients:    make(map[*Client]struct{}),
		userIndex:  make(map[string]map[*Client]struct{}),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		redis:      redisClient,
		jwtSecret:  jwtSecret,
		ctx:        ctx,
		cancel:     cancel,
	}
	return h
}

// Run starts the hub's event loop. Call in a goroutine.
func (h *Hub) Run() {
	// Subscribe to Redis Pub/Sub for cross-instance fan-out
	go h.subscribeRedis()

	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = struct{}{}
			if h.userIndex[client.userID] == nil {
				h.userIndex[client.userID] = make(map[*Client]struct{})
			}
			h.userIndex[client.userID][client] = struct{}{}
			count := len(h.clients)
			h.mu.Unlock()
			log.Printf("[WS] Client connected: user=%s total=%d", client.userID, count)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				if userClients, ok := h.userIndex[client.userID]; ok {
					delete(userClients, client)
					if len(userClients) == 0 {
						delete(h.userIndex, client.userID)
					}
				}
			}
			count := len(h.clients)
			h.mu.Unlock()
			log.Printf("[WS] Client disconnected: user=%s total=%d", client.userID, count)

		case <-h.ctx.Done():
			return
		}
	}
}

// Stop shuts down the hub.
func (h *Hub) Stop() {
	h.cancel()
}

// ActiveConnections returns the number of active WebSocket connections.
func (h *Hub) ActiveConnections() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// ── Broadcasting ──

// Broadcast publishes a message via Redis Pub/Sub so all instances receive it.
func (h *Hub) Broadcast(msgType string, data interface{}) {
	msg := Message{Type: msgType, Data: data}
	raw, err := json.Marshal(msg)
	if err != nil {
		log.Printf("[WS] Marshal broadcast error: %v", err)
		return
	}

	if h.redis != nil {
		if err := h.redis.Publish(h.ctx, redisPubSubChannel, raw).Err(); err != nil {
			log.Printf("[WS] Redis PUBLISH error: %v", err)
		}
	} else {
		// No Redis — local-only broadcast
		h.broadcastLocal(raw)
	}
}

// BroadcastToUser sends a message to all connections of a specific user.
func (h *Hub) BroadcastToUser(userID string, msgType string, data interface{}) {
	msg := Message{Type: msgType, Data: data}
	raw, err := json.Marshal(msg)
	if err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()
	if clients, ok := h.userIndex[userID]; ok {
		for client := range clients {
			select {
			case client.send <- raw:
			default:
				log.Printf("[WS] Dropping message for slow client user=%s", userID)
			}
		}
	}
}

// broadcastLocal sends a raw JSON message to all locally connected clients.
func (h *Hub) broadcastLocal(raw []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for client := range h.clients {
		select {
		case client.send <- raw:
		default:
			// slow client, drop
		}
	}
}

// subscribeRedis listens to the Redis Pub/Sub channel and fans out to local clients.
func (h *Hub) subscribeRedis() {
	if h.redis == nil {
		return
	}
	sub := h.redis.Subscribe(h.ctx, redisPubSubChannel)
	defer sub.Close()

	ch := sub.Channel()
	for {
		select {
		case msg, ok := <-ch:
			if !ok {
				return
			}
			h.broadcastLocal([]byte(msg.Payload))
		case <-h.ctx.Done():
			return
		}
	}
}

// ── HTTP Upgrade Handler ──

// HandleUpgrade is a Gin handler that upgrades HTTP to WebSocket.
// JWT is passed as a query parameter: /ws?token=JWT
func (h *Hub) HandleUpgrade(c *gin.Context) {
	tokenStr := c.Query("token")
	if tokenStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "token required"})
		return
	}

	// Parse JWT to extract user ID
	userID, err := h.parseJWT(tokenStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("[WS] Upgrade error: %v", err)
		return
	}

	client := &Client{
		hub:    h,
		conn:   conn,
		send:   make(chan []byte, 256),
		userID: userID,
	}

	h.register <- client

	go client.writePump()
	go client.readPump()
}

// parseJWT extracts the user ID from a JWT token string.
func (h *Hub) parseJWT(tokenStr string) (string, error) {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(h.jwtSecret), nil
	})
	if err != nil {
		return "", err
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok || !token.Valid {
		return "", jwt.ErrSignatureInvalid
	}

	// Check expiry
	if exp, ok := claims["exp"].(float64); ok {
		if time.Unix(int64(exp), 0).Before(time.Now()) {
			return "", jwt.ErrTokenExpired
		}
	}

	userID, ok := claims["sub"].(string)
	if !ok {
		return "", jwt.ErrTokenUnverifiable
	}

	return userID, nil
}
