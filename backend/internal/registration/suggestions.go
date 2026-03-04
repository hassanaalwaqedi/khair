package registration

// Suggestion represents a smart suggestion for improving registration data
type Suggestion struct {
	Field    string `json:"field"`
	Type     string `json:"type"` // missing, improvement, tip
	Message  string `json:"message"`
	Priority int    `json:"priority"` // 1=high, 2=medium, 3=low
}

// PasswordStrength represents password strength analysis
type PasswordStrength struct {
	Score int      `json:"score"` // 0-4
	Label string   `json:"label"` // Weak, Fair, Strong, Very Strong
	Tips  []string `json:"tips"`
}

// CalculatePasswordStrength analyzes password strength
func CalculatePasswordStrength(password string) *PasswordStrength {
	score := 0
	var tips []string

	if len(password) >= 8 {
		score++
	} else {
		tips = append(tips, "Use at least 8 characters")
	}
	if len(password) >= 12 {
		score++
	} else {
		tips = append(tips, "Use 12+ characters for better security")
	}

	hasUpper, hasLower, hasDigit, hasSpecial := false, false, false, false
	for _, c := range password {
		switch {
		case c >= 'A' && c <= 'Z':
			hasUpper = true
		case c >= 'a' && c <= 'z':
			hasLower = true
		case c >= '0' && c <= '9':
			hasDigit = true
		default:
			hasSpecial = true
		}
	}

	if hasUpper && hasLower {
		score++
	} else {
		tips = append(tips, "Mix uppercase and lowercase letters")
	}
	if hasDigit && hasSpecial {
		score++
	} else if !hasDigit {
		tips = append(tips, "Add numbers")
	} else if !hasSpecial {
		tips = append(tips, "Add special characters (!@#$%)")
	}

	labels := map[int]string{0: "Weak", 1: "Fair", 2: "Good", 3: "Strong", 4: "Very Strong"}

	return &PasswordStrength{
		Score: score,
		Label: labels[score],
		Tips:  tips,
	}
}

// CalculateProfileCompletion computes profile completion percentage
func CalculateProfileCompletion(role string, data map[string]interface{}) int {
	fields := map[string]int{
		"display_name": 15,
		"email":        15,
		"bio":          10,
		"location":     10,
		"avatar_url":   10,
	}

	// Role-specific fields
	switch role {
	case "organization":
		fields["org_name"] = 15
		fields["org_type"] = 10
		fields["org_city"] = 5
		fields["org_description"] = 10
	case "sheikh":
		fields["specialization"] = 15
		fields["certifications"] = 10
		fields["ijazah_info"] = 10
		fields["years_experience"] = 5
	case "student", "new_muslim":
		fields["interests"] = 15
		fields["preferred_language"] = 10
	case "community_organizer":
		fields["org_name"] = 15
		fields["community_focus"] = 10
		fields["org_city"] = 10
	}

	total := 0
	earned := 0
	for field, weight := range fields {
		total += weight
		if val, ok := data[field]; ok && val != nil && val != "" {
			earned += weight
		}
	}

	if total == 0 {
		return 0
	}
	return (earned * 100) / total
}

// GetSuggestionsForRole returns smart suggestions based on role and current data
func GetSuggestionsForRole(role string, data map[string]interface{}) []Suggestion {
	var suggestions []Suggestion

	// Universal suggestions
	if isEmpty(data, "display_name") {
		suggestions = append(suggestions, Suggestion{
			Field:    "display_name",
			Type:     "missing",
			Message:  "Add your name so the community can recognize you",
			Priority: 1,
		})
	}
	if isEmpty(data, "bio") {
		suggestions = append(suggestions, Suggestion{
			Field:    "bio",
			Type:     "missing",
			Message:  "A brief bio helps build trust within the Ummah",
			Priority: 2,
		})
	}
	if isEmpty(data, "location") {
		suggestions = append(suggestions, Suggestion{
			Field:    "location",
			Type:     "improvement",
			Message:  "Add your city to help people nearby find you",
			Priority: 2,
		})
	}

	// Role-specific suggestions
	switch role {
	case "organization":
		if isEmpty(data, "org_description") {
			suggestions = append(suggestions, Suggestion{
				Field:    "description",
				Type:     "missing",
				Message:  "Describe your organization's mission and activities",
				Priority: 1,
			})
		}
		if isEmpty(data, "logo_url") {
			suggestions = append(suggestions, Suggestion{
				Field:    "logo_url",
				Type:     "improvement",
				Message:  "Upload your logo for credibility and recognition",
				Priority: 2,
			})
		}
		if isEmpty(data, "registration_number") {
			suggestions = append(suggestions, Suggestion{
				Field:    "registration_number",
				Type:     "tip",
				Message:  "Mention official registration number if available for verification",
				Priority: 3,
			})
		}
		if isEmpty(data, "org_city") {
			suggestions = append(suggestions, Suggestion{
				Field:    "city",
				Type:     "improvement",
				Message:  "Add your city so nearby community members can find you",
				Priority: 2,
			})
		}

	case "sheikh":
		if isEmpty(data, "specialization") {
			suggestions = append(suggestions, Suggestion{
				Field:    "specialization",
				Type:     "missing",
				Message:  "Share your area of expertise (Quran, Fiqh, Hadith, etc.)",
				Priority: 1,
			})
		}
		if isEmpty(data, "ijazah_info") {
			suggestions = append(suggestions, Suggestion{
				Field:    "ijazah_info",
				Type:     "improvement",
				Message:  "Adding Ijazah information increases your verification chances",
				Priority: 2,
			})
		}
		if isEmpty(data, "certifications") {
			suggestions = append(suggestions, Suggestion{
				Field:    "certifications",
				Type:     "improvement",
				Message:  "List your certifications and qualifications",
				Priority: 2,
			})
		}
		suggestions = append(suggestions, Suggestion{
			Field:    "verification",
			Type:     "tip",
			Message:  "Submit verification documents to get the verified badge",
			Priority: 3,
		})

	case "new_muslim":
		suggestions = append(suggestions, Suggestion{
			Field:    "welcome",
			Type:     "tip",
			Message:  "Welcome to Islam! We're here to support your journey. Take your time filling out your profile.",
			Priority: 1,
		})
		if isEmpty(data, "preferred_language") {
			suggestions = append(suggestions, Suggestion{
				Field:    "preferred_language",
				Type:     "improvement",
				Message:  "Set your preferred language to get matched with the right resources",
				Priority: 2,
			})
		}

	case "student":
		if isEmpty(data, "interests") {
			suggestions = append(suggestions, Suggestion{
				Field:    "interests",
				Type:     "missing",
				Message:  "Share what you want to learn (Quran, Arabic, Fiqh, etc.)",
				Priority: 1,
			})
		}

	case "community_organizer":
		if isEmpty(data, "org_name") {
			suggestions = append(suggestions, Suggestion{
				Field:    "community_name",
				Type:     "missing",
				Message:  "Name your community group so members can find you",
				Priority: 1,
			})
		}
		if isEmpty(data, "community_focus") {
			suggestions = append(suggestions, Suggestion{
				Field:    "community_focus",
				Type:     "improvement",
				Message:  "Describe your community's focus area (e.g., youth, families, reverts)",
				Priority: 2,
			})
		}
	}

	return suggestions
}

func isEmpty(data map[string]interface{}, key string) bool {
	val, ok := data[key]
	if !ok {
		return true
	}
	if str, ok := val.(string); ok && str == "" {
		return true
	}
	return val == nil
}
