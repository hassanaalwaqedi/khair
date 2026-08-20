package ws

import (
	"encoding/json"
	"testing"
)

func TestBroadcastToRolesOnlyDeliversToAuthorizedClients(t *testing.T) {
	hub := NewHub(nil, "test-secret")
	agent := &Client{
		userID: "agent",
		roles:  map[string]struct{}{"support_agent": {}},
		send:   make(chan []byte, 1),
	}
	member := &Client{
		userID: "member",
		roles:  map[string]struct{}{"user": {}},
		send:   make(chan []byte, 1),
	}
	hub.clients[agent] = struct{}{}
	hub.clients[member] = struct{}{}

	hub.BroadcastToRoles([]string{"support_agent", "admin"}, "support.message_created", map[string]string{"id": "message-1"})

	select {
	case raw := <-agent.send:
		var received Message
		if err := json.Unmarshal(raw, &received); err != nil {
			t.Fatalf("unmarshal targeted message: %v", err)
		}
		if received.Type != "support.message_created" {
			t.Fatalf("message type = %q", received.Type)
		}
	case <-member.send:
		t.Fatal("support event leaked to an ordinary user")
	default:
		t.Fatal("support agent did not receive the targeted event")
	}

	select {
	case <-member.send:
		t.Fatal("support event leaked to an ordinary user")
	default:
	}
}
