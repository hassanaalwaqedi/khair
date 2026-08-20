package support

import "testing"

func TestRequestsHumanRecognizesExplicitHumanHandoffPhrases(t *testing.T) {
	testCases := []string{
		"I want to talk to a person",
		"Can I speak with a human?",
		"أريد التحدث مع شخص",
		"أريد التحدث إلى شخص",
		"Bir kişiyle konuşmak istiyorum",
	}

	for _, message := range testCases {
		if !requestsHuman(message) {
			t.Fatalf("expected %q to request a human handoff", message)
		}
	}
}
