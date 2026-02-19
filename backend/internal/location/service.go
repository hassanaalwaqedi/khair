package location

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// LocationResult holds the resolved location data
type LocationResult struct {
	Country     string  `json:"country"`
	CountryCode string  `json:"country_code"`
	City        string  `json:"city"`
	Timezone    string  `json:"timezone"`
	Latitude    float64 `json:"latitude,omitempty"`
	Longitude   float64 `json:"longitude,omitempty"`
}

// Service handles location resolution
type Service struct {
	httpClient *http.Client
}

// NewService creates a new location service
func NewService() *Service {
	return &Service{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// nominatimResponse represents the Nominatim reverse geocode response
type nominatimResponse struct {
	Address struct {
		City        string `json:"city"`
		Town        string `json:"town"`
		Village     string `json:"village"`
		State       string `json:"state"`
		Country     string `json:"country"`
		CountryCode string `json:"country_code"`
	} `json:"address"`
}

// ipAPIResponse represents the ip-api.com response
type ipAPIResponse struct {
	Status      string  `json:"status"`
	Country     string  `json:"country"`
	CountryCode string  `json:"countryCode"`
	City        string  `json:"city"`
	Timezone    string  `json:"timezone"`
	Lat         float64 `json:"lat"`
	Lon         float64 `json:"lon"`
}

// ResolveByCoordinates uses Nominatim to reverse geocode lat/lng
func (s *Service) ResolveByCoordinates(lat, lng float64) (*LocationResult, error) {
	url := fmt.Sprintf(
		"https://nominatim.openstreetmap.org/reverse?format=json&lat=%f&lon=%f&zoom=10&addressdetails=1",
		lat, lng,
	)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	req.Header.Set("User-Agent", "KhairApp/1.0")

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("nominatim request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("nominatim returned status %d", resp.StatusCode)
	}

	var result nominatimResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding nominatim response: %w", err)
	}

	// Determine city name (Nominatim uses different fields)
	city := result.Address.City
	if city == "" {
		city = result.Address.Town
	}
	if city == "" {
		city = result.Address.Village
	}
	if city == "" {
		city = result.Address.State
	}

	countryCode := result.Address.CountryCode
	timezone := lookupTimezone(countryCode)

	return &LocationResult{
		Country:     result.Address.Country,
		CountryCode: fmt.Sprintf("%s", upperCase(countryCode)),
		City:        city,
		Timezone:    timezone,
		Latitude:    lat,
		Longitude:   lng,
	}, nil
}

// ResolveByIP uses ip-api.com to resolve location from IP
func (s *Service) ResolveByIP(ip string) (*LocationResult, error) {
	url := "http://ip-api.com/json/"
	if ip != "" && ip != "127.0.0.1" && ip != "::1" {
		url += ip
	}

	resp, err := s.httpClient.Get(url)
	if err != nil {
		return nil, fmt.Errorf("ip-api request failed: %w", err)
	}
	defer resp.Body.Close()

	var result ipAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decoding ip-api response: %w", err)
	}

	if result.Status != "success" {
		return nil, fmt.Errorf("ip-api returned status: %s", result.Status)
	}

	return &LocationResult{
		Country:     result.Country,
		CountryCode: result.CountryCode,
		City:        result.City,
		Timezone:    result.Timezone,
		Latitude:    result.Lat,
		Longitude:   result.Lon,
	}, nil
}

// upperCase converts a string to uppercase
func upperCase(s string) string {
	result := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'a' && c <= 'z' {
			c -= 32
		}
		result[i] = c
	}
	return string(result)
}

// lookupTimezone returns a common timezone for a country code
func lookupTimezone(countryCode string) string {
	timezones := map[string]string{
		"tr": "Europe/Istanbul",
		"sa": "Asia/Riyadh",
		"ae": "Asia/Dubai",
		"eg": "Africa/Cairo",
		"us": "America/New_York",
		"gb": "Europe/London",
		"de": "Europe/Berlin",
		"fr": "Europe/Paris",
		"jp": "Asia/Tokyo",
		"cn": "Asia/Shanghai",
		"in": "Asia/Kolkata",
		"br": "America/Sao_Paulo",
		"au": "Australia/Sydney",
		"ca": "America/Toronto",
		"mx": "America/Mexico_City",
		"kr": "Asia/Seoul",
		"id": "Asia/Jakarta",
		"pk": "Asia/Karachi",
		"bd": "Asia/Dhaka",
		"ng": "Africa/Lagos",
		"ru": "Europe/Moscow",
		"it": "Europe/Rome",
		"es": "Europe/Madrid",
		"nl": "Europe/Amsterdam",
		"se": "Europe/Stockholm",
		"no": "Europe/Oslo",
		"dk": "Europe/Copenhagen",
		"pl": "Europe/Warsaw",
		"at": "Europe/Vienna",
		"ch": "Europe/Zurich",
		"be": "Europe/Brussels",
		"pt": "Europe/Lisbon",
		"gr": "Europe/Athens",
		"cz": "Europe/Prague",
		"ro": "Europe/Bucharest",
		"hu": "Europe/Budapest",
		"il": "Asia/Jerusalem",
		"jo": "Asia/Amman",
		"lb": "Asia/Beirut",
		"kw": "Asia/Kuwait",
		"bh": "Asia/Bahrain",
		"qa": "Asia/Qatar",
		"om": "Asia/Muscat",
		"iq": "Asia/Baghdad",
		"sy": "Asia/Damascus",
		"ma": "Africa/Casablanca",
		"tn": "Africa/Tunis",
		"dz": "Africa/Algiers",
		"ly": "Africa/Tripoli",
		"sd": "Africa/Khartoum",
	}

	if tz, ok := timezones[countryCode]; ok {
		return tz
	}
	return "UTC"
}
