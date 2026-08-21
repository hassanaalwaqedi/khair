// Package eligibility contains the canonical attendance-policy rules shared by
// event creation, profile changes, and seat reservations.
package eligibility

import (
	"fmt"
	"strings"
)

const (
	PolicyEveryone  = "EVERYONE"
	PolicyWomenOnly = "WOMEN_ONLY"
	PolicyMenOnly   = "MEN_ONLY"

	GenderMan    = "MAN"
	GenderWoman  = "WOMAN"
	GenderNotSet = "NOT_SET"

	CodeEventNotEligible           = "EVENT_NOT_ELIGIBLE"
	CodeProfileEligibilityRequired = "PROFILE_ELIGIBILITY_REQUIRED"
)

// Error is returned when a user cannot join an event because of its
// attendance policy. HTTPStatus is intentionally part of the domain error so
// every transport can preserve the API contract.
type Error struct {
	Code       string
	HTTPStatus int
	Message    string
	Policy     string
}

func (e *Error) Error() string { return e.Message }

// NormalizePolicy converts the legacy gender_restriction values into the
// stable policy enum. Empty legacy values are intentionally unrestricted so
// existing events remain joinable after migration.
func NormalizePolicy(value string) (string, error) {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "", "ANY", "ALL", "MIXED", PolicyEveryone:
		return PolicyEveryone, nil
	case "FEMALE_ONLY", "WOMEN_ONLY", "WOMEN", "FEMALE":
		return PolicyWomenOnly, nil
	case "MALE_ONLY", "MEN_ONLY", "MEN", "MALE":
		return PolicyMenOnly, nil
	default:
		return "", fmt.Errorf("unsupported attendance policy %q", value)
	}
}

// NormalizeGender converts historical lowercase values and new canonical
// values. Unknown or empty values are treated as not set, never as eligible.
func NormalizeGender(value string) string {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "MAN", "MALE":
		return GenderMan
	case "WOMAN", "WOMEN", "FEMALE":
		return GenderWoman
	default:
		return GenderNotSet
	}
}

// Evaluate applies the policy using only trusted, server-side values.
func Evaluate(policy, gender string) error {
	normalizedPolicy, err := NormalizePolicy(policy)
	if err != nil {
		return err
	}
	normalizedGender := NormalizeGender(gender)
	if normalizedPolicy == PolicyEveryone {
		return nil
	}
	if normalizedGender == GenderNotSet {
		return &Error{
			Code:       CodeProfileEligibilityRequired,
			HTTPStatus: 409,
			Message:    "Please complete your profile before joining this restricted event.",
			Policy:     normalizedPolicy,
		}
	}
	if (normalizedPolicy == PolicyWomenOnly && normalizedGender != GenderWoman) ||
		(normalizedPolicy == PolicyMenOnly && normalizedGender != GenderMan) {
		return &Error{
			Code:       CodeEventNotEligible,
			HTTPStatus: 403,
			Message:    "You are not eligible to join this event.",
			Policy:     normalizedPolicy,
		}
	}
	return nil
}

// LegacyGenderRestriction keeps older clients and filters compatible while
// attendance_policy becomes the authoritative field.
func LegacyGenderRestriction(policy string) string {
	normalized, err := NormalizePolicy(policy)
	if err != nil {
		normalized = PolicyEveryone
	}
	switch normalized {
	case PolicyWomenOnly:
		return "female_only"
	case PolicyMenOnly:
		return "male_only"
	default:
		return "mixed"
	}
}

func IsError(err error, code string) bool {
	eligibilityErr, ok := err.(*Error)
	return ok && eligibilityErr.Code == code
}
