package ai

import (
	"testing"
	"github.com/stretchr/testify/assert"
)

// A mocked client could be passed to DescriptionService if we had an interface.
// For now, testing logic that doesn't hit network can check struct instantiation.

func TestNewDescriptionService(t *testing.T) {
	client := &Client{}
	service := NewDescriptionService(client)
	assert.NotNil(t, service)
	assert.Equal(t, client, service.client)
}

func TestEnhanceOptions_Language(t *testing.T) {
	opts := EnhanceOptions{
		Language: "Arabic",
	}
	assert.Equal(t, "Arabic", opts.Language)
}
