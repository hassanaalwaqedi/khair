package eligibility

import "testing"

func TestEvaluatePolicyMatrix(t *testing.T) {
	tests := []struct {
		name   string
		policy string
		gender string
		code   string
	}{
		{name: "everyone without profile gender", policy: PolicyEveryone, gender: GenderNotSet},
		{name: "women accepts woman", policy: PolicyWomenOnly, gender: GenderWoman},
		{name: "men accepts man", policy: PolicyMenOnly, gender: GenderMan},
		{name: "women requires profile gender", policy: PolicyWomenOnly, gender: GenderNotSet, code: CodeProfileEligibilityRequired},
		{name: "men requires profile gender", policy: PolicyMenOnly, gender: "", code: CodeProfileEligibilityRequired},
		{name: "man cannot join women event", policy: PolicyWomenOnly, gender: GenderMan, code: CodeEventNotEligible},
		{name: "woman cannot join men event", policy: PolicyMenOnly, gender: GenderWoman, code: CodeEventNotEligible},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := Evaluate(tt.policy, tt.gender)
			if tt.code == "" {
				if err != nil {
					t.Fatalf("Evaluate returned unexpected error: %v", err)
				}
				return
			}
			if !IsError(err, tt.code) {
				t.Fatalf("Evaluate error = %v, want code %s", err, tt.code)
			}
		})
	}
}

func TestNormalizeLegacyValues(t *testing.T) {
	for input, want := range map[string]string{
		"mixed":       PolicyEveryone,
		"female_only": PolicyWomenOnly,
		"male_only":   PolicyMenOnly,
		"WOMEN_ONLY":  PolicyWomenOnly,
		"":            PolicyEveryone,
	} {
		got, err := NormalizePolicy(input)
		if err != nil || got != want {
			t.Fatalf("NormalizePolicy(%q) = %q, %v; want %q", input, got, err, want)
		}
	}
}
