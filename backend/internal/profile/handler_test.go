package profile

import "testing"

func TestProfileCompletion(t *testing.T) {
	name, avatar, country, city := "Amina", "https://cdn/avatar.webp", "Turkey", "Istanbul"
	if got := profileCompletion(&name, &avatar, &country, &city, "tr"); got != 100 {
		t.Fatalf("profileCompletion() = %d, want 100", got)
	}
	if got := profileCompletion(nil, nil, nil, nil, "en"); got != 20 {
		t.Fatalf("profileCompletion() = %d, want 20 for the persisted language", got)
	}
}

func TestAccountTypeLabel(t *testing.T) {
	for input, want := range map[string]string{"user": "Member", "organizer": "Organizer", "admin": "Administrator"} {
		if got := accountTypeLabel(input); got != want {
			t.Errorf("accountTypeLabel(%q) = %q, want %q", input, got, want)
		}
	}
}
