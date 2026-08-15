package registration

type Suggestion struct {
	Field    string `json:"field"`
	Type     string `json:"type"`
	Message  string `json:"message"`
	Priority int    `json:"priority"`
}
type PasswordStrength struct {
	Score int      `json:"score"`
	Label string   `json:"label"`
	Tips  []string `json:"tips"`
}

func CalculatePasswordStrength(password string) *PasswordStrength {
	score, tips := 0, []string{}
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
	upper, lower, digit, special := false, false, false, false
	for _, c := range password {
		switch {
		case c >= 'A' && c <= 'Z':
			upper = true
		case c >= 'a' && c <= 'z':
			lower = true
		case c >= '0' && c <= '9':
			digit = true
		default:
			special = true
		}
	}
	if upper && lower {
		score++
	} else {
		tips = append(tips, "Mix uppercase and lowercase letters")
	}
	if digit && special {
		score++
	} else {
		tips = append(tips, "Add a number and special character")
	}
	return &PasswordStrength{Score: score, Label: map[int]string{0: "Weak", 1: "Fair", 2: "Good", 3: "Strong", 4: "Very Strong"}[score], Tips: tips}
}

func CalculateProfileCompletion(_ string, data map[string]interface{}) int {
	fields := map[string]int{"display_name": 30, "email": 20, "city": 15, "country": 15, "preferred_language": 10, "bio": 10}
	earned := 0
	for field, weight := range fields {
		if !isEmpty(data, field) {
			earned += weight
		}
	}
	return earned
}

func GetSuggestionsForRole(_ string, data map[string]interface{}) []Suggestion {
	items := []Suggestion{}
	for _, item := range []Suggestion{
		{Field: "display_name", Type: "missing", Message: "Add your name so people can recognize you", Priority: 1},
		{Field: "city", Type: "improvement", Message: "Add your city to discover nearby events", Priority: 2},
		{Field: "preferred_language", Type: "improvement", Message: "Set your preferred language", Priority: 3},
	} {
		if isEmpty(data, item.Field) {
			items = append(items, item)
		}
	}
	return items
}

func isEmpty(data map[string]interface{}, key string) bool {
	value, ok := data[key]
	if !ok || value == nil {
		return true
	}
	text, ok := value.(string)
	return ok && text == ""
}
