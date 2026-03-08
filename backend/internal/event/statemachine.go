package event

import "fmt"

// validTransitions defines the allowed event status transitions.
// Each key is a "from" status, and the value is the set of statuses it may
// transition to.
var validTransitions = map[string][]string{
	"draft":          {"pending", "approved", "rejected", "needs_revision"},
	"pending":        {"approved", "rejected", "needs_revision"},
	"needs_revision": {"pending"},
	"approved":       {"published"},
	"rejected":       {"pending"},
}

// ValidateTransition checks whether moving from → to is allowed.
// It returns nil if the transition is valid, or an error describing why it is
// not.
func ValidateTransition(from, to string) error {
	allowed, ok := validTransitions[from]
	if !ok {
		return fmt.Errorf("unknown event status %q", from)
	}
	for _, s := range allowed {
		if s == to {
			return nil
		}
	}
	return fmt.Errorf("invalid status transition from %q to %q", from, to)
}
