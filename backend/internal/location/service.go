package location

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"
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

// PlaceResult is the provider-neutral public location returned to the app.
// Coordinates and normalized address fields remain canonical; provider IDs are
// optional hints and are never required by event storage.
type PlaceResult struct {
	Name        string  `json:"name"`
	Category    string  `json:"category,omitempty"`
	DisplayName string  `json:"display_name"`
	Address     string  `json:"address,omitempty"`
	Street      string  `json:"street,omitempty"`
	District    string  `json:"district,omitempty"`
	City        string  `json:"city,omitempty"`
	State       string  `json:"state,omitempty"`
	Country     string  `json:"country,omitempty"`
	CountryCode string  `json:"country_code,omitempty"`
	PostalCode  string  `json:"postal_code,omitempty"`
	Latitude    float64 `json:"latitude"`
	Longitude   float64 `json:"longitude"`
	DistanceKm  float64 `json:"distance_km,omitempty"`
	Provider    string  `json:"provider"`
	ProviderID  string  `json:"provider_id,omitempty"`
}

// LocationSearchProvider keeps the UI independent from Nominatim and allows a
// later move to self-hosted Photon/Pelias or another provider.
type LocationSearchProvider interface {
	Search(ctx context.Context, query, city, country, language string, lat, lng *float64) ([]PlaceResult, error)
	Reverse(ctx context.Context, lat, lng float64, language string) (*PlaceResult, error)
}

// Service handles location resolution
type Service struct {
	httpClient *http.Client
	redis      *redis.Client
	provider   LocationSearchProvider
}

// NewService creates a new location service
func NewService(redisClients ...*redis.Client) *Service {
	var redisClient *redis.Client
	if len(redisClients) > 0 {
		redisClient = redisClients[0]
	}
	s := &Service{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
	s.redis = redisClient
	s.provider = &nominatimProvider{httpClient: s.httpClient}
	return s
}

func (s *Service) SearchPlaces(ctx context.Context, query, city, country, language string, lat, lng *float64) ([]PlaceResult, error) {
	key := "location:search:v3:" + normalizeCachePart(language) + ":" + normalizeCachePart(country) + ":" + normalizeCachePart(city) + ":" + normalizeCachePart(query)
	if s.redis != nil {
		if data, err := s.redis.Get(ctx, key).Bytes(); err == nil {
			var cached []PlaceResult
			if json.Unmarshal(data, &cached) == nil {
				sort.SliceStable(cached, func(i, j int) bool {
					return placeRank(cached[i], city, country) > placeRank(cached[j], city, country)
				})
				return cached, nil
			}
		}
	}
	results, err := s.provider.Search(ctx, query, city, country, language, lat, lng)
	if err != nil {
		return nil, err
	}
	if s.redis != nil {
		if data, marshalErr := json.Marshal(results); marshalErr == nil {
			_ = s.redis.Set(ctx, key, data, 10*time.Minute).Err()
		}
	}
	return results, nil
}

func (s *Service) ReversePlace(ctx context.Context, lat, lng float64, language string) (*PlaceResult, error) {
	return s.provider.Reverse(ctx, lat, lng, language)
}

func normalizeCachePart(value string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(value)), "-"))
}

type nominatimProvider struct {
	httpClient *http.Client
	mu         sync.Mutex
	lastCall   time.Time
}

type nominatimPlace struct {
	PlaceID     int64  `json:"place_id"`
	Name        string `json:"name"`
	Type        string `json:"type"`
	Category    string `json:"category"`
	DisplayName string `json:"display_name"`
	Lat         string `json:"lat"`
	Lon         string `json:"lon"`
	Address     struct {
		Road        string `json:"road"`
		Pedestrian  string `json:"pedestrian"`
		Suburb      string `json:"suburb"`
		Neighbour   string `json:"neighbourhood"`
		City        string `json:"city"`
		Town        string `json:"town"`
		Village     string `json:"village"`
		County      string `json:"county"`
		State       string `json:"state"`
		Country     string `json:"country"`
		CountryCode string `json:"country_code"`
		Postcode    string `json:"postcode"`
	} `json:"address"`
}

type photonFeatureCollection struct {
	Features []photonFeature `json:"features"`
}

type photonFeature struct {
	Properties photonProperties `json:"properties"`
	Geometry   struct {
		Coordinates []float64 `json:"coordinates"`
	} `json:"geometry"`
}

type photonProperties struct {
	OSMType     string `json:"osm_type"`
	OSMID       int64  `json:"osm_id"`
	OSMKey      string `json:"osm_key"`
	OSMValue    string `json:"osm_value"`
	Type        string `json:"type"`
	Name        string `json:"name"`
	Street      string `json:"street"`
	District    string `json:"district"`
	Locality    string `json:"locality"`
	City        string `json:"city"`
	County      string `json:"county"`
	State       string `json:"state"`
	Country     string `json:"country"`
	CountryCode string `json:"countrycode"`
	Postcode    string `json:"postcode"`
}

func (p *nominatimProvider) waitForPolicy(ctx context.Context) error {
	p.mu.Lock()
	delay := time.Second - time.Since(p.lastCall)
	if delay < 0 {
		delay = 0
	}
	p.lastCall = time.Now().Add(delay)
	p.mu.Unlock()
	if delay == 0 {
		return nil
	}
	timer := time.NewTimer(delay)
	defer timer.Stop()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}

func (p *nominatimProvider) request(ctx context.Context, endpoint string, values url.Values, target interface{}) error {
	if err := p.waitForPolicy(ctx); err != nil {
		return err
	}
	u := "https://nominatim.openstreetmap.org/" + endpoint + "?" + values.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "KhairApp/1.0 (location search; contact: support@khairapp.org)")
	resp, err := p.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("nominatim request failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("nominatim returned status %d", resp.StatusCode)
	}
	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		return fmt.Errorf("decoding nominatim response: %w", err)
	}
	return nil
}

// photonRequest is the OpenStreetMap-compatible fallback used when the
// public Nominatim endpoint is temporarily unavailable or rate-limits us.
func (p *nominatimProvider) photonRequest(ctx context.Context, endpoint string, values url.Values, target interface{}) error {
	if err := p.waitForPolicy(ctx); err != nil {
		return err
	}
	u := "https://photon.komoot.io/" + endpoint + "?" + values.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "KhairApp/1.0 (location search; contact: support@khairapp.org)")
	resp, err := p.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("photon request failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("photon returned status %d", resp.StatusCode)
	}
	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		return fmt.Errorf("decoding photon response: %w", err)
	}
	return nil
}

func (p *nominatimProvider) Search(ctx context.Context, query, city, country, language string, lat, lng *float64) ([]PlaceResult, error) {
	var raw []nominatimPlace
	for _, searchQuery := range searchQueryVariants(query) {
		contextParts := []string{searchQuery}
		if city != "" {
			contextParts = append(contextParts, city)
		}
		if country != "" {
			contextParts = append(contextParts, country)
		}
		values := url.Values{"q": {strings.Join(contextParts, ", ")}, "format": {"jsonv2"}, "addressdetails": {"1"}, "namedetails": {"1"}, "limit": {"8"}, "dedupe": {"1"}, "accept-language": {language}}
		if lat != nil && lng != nil {
			const delta = 0.35
			values.Set("viewbox", fmt.Sprintf("%f,%f,%f,%f", *lng-delta, *lat+delta, *lng+delta, *lat-delta))
		}
		if err := p.request(ctx, "search", values, &raw); err != nil {
			return p.searchPhoton(ctx, query, city, country, language, lat, lng)
		}
		if len(raw) > 0 {
			break
		}
	}
	results := make([]PlaceResult, 0, len(raw))
	for _, item := range raw {
		result := placeFromNominatim(item)
		if lat != nil && lng != nil {
			result.DistanceKm = distanceKm(*lat, *lng, result.Latitude, result.Longitude)
		}
		results = append(results, result)
	}
	sort.SliceStable(results, func(i, j int) bool {
		return placeRank(results[i], city, country) > placeRank(results[j], city, country)
	})
	return results, nil
}

func (p *nominatimProvider) searchPhoton(ctx context.Context, query, city, country, language string, lat, lng *float64) ([]PlaceResult, error) {
	var raw photonFeatureCollection
	for _, variant := range searchQueryVariants(query) {
		searchQuery := variant
		if city != "" {
			searchQuery += ", " + city
		}
		if country != "" {
			searchQuery += ", " + country
		}
		values := url.Values{
			"q":     {searchQuery},
			"limit": {"8"},
		}
		setPhotonLanguage(values, language)
		if lat != nil && lng != nil {
			values.Set("lat", strconv.FormatFloat(*lat, 'f', 6, 64))
			values.Set("lon", strconv.FormatFloat(*lng, 'f', 6, 64))
		}
		if err := p.photonRequest(ctx, "api/", values, &raw); err != nil {
			return nil, err
		}
		if len(raw.Features) > 0 {
			break
		}
	}
	results := make([]PlaceResult, 0, len(raw.Features))
	for _, item := range raw.Features {
		result := placeFromPhoton(item)
		if lat != nil && lng != nil {
			result.DistanceKm = distanceKm(*lat, *lng, result.Latitude, result.Longitude)
		}
		results = append(results, result)
	}
	sort.SliceStable(results, func(i, j int) bool {
		return placeRank(results[i], city, country) > placeRank(results[j], city, country)
	})
	return results, nil
}

// searchQueryVariants handles common place-name spelling mistakes while
// keeping the provider request exact for normal queries. Nominatim does not
// perform fuzzy matching, so a harmless typo can otherwise produce no result.
func searchQueryVariants(query string) []string {
	query = strings.TrimSpace(query)
	variants := []string{query}
	lower := strings.ToLower(query)
	if strings.Contains(lower, "emmar") {
		variants = append(variants, strings.ReplaceAll(query, "emmar", "emaar"))
		variants = append(variants, strings.ReplaceAll(query, "Emmar", "Emaar"))
	}
	// Nominatim searches names and tags as written in OpenStreetMap. These
	// common Arabic place terms are translated into a second provider query so
	// Arabic users can find POIs whose OSM name is stored in Latin script.
	arabicVariant := strings.NewReplacer(
		"مقهى", "cafe",
		"كافيه", "cafe",
		"مطعم", "restaurant",
		"مسجد", "mosque",
		"جامع", "mosque",
		"مول", "mall",
		"مركز تسوق", "shopping mall",
		"فندق", "hotel",
		"إعمار", "Emaar",
		"اعمار", "Emaar",
	).Replace(query)
	if arabicVariant != query {
		variants = append(variants, arabicVariant)
	}
	result := make([]string, 0, len(variants))
	seen := make(map[string]struct{}, len(variants))
	for _, variant := range variants {
		key := strings.ToLower(strings.TrimSpace(variant))
		if key == "" {
			continue
		}
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, variant)
	}
	return result
}

func placeRank(place PlaceResult, city, country string) float64 {
	rank := 0.0
	city = strings.TrimSpace(city)
	country = strings.TrimSpace(country)
	if city != "" {
		if strings.EqualFold(place.City, city) {
			rank += 100
		} else if strings.Contains(strings.ToLower(place.DisplayName), strings.ToLower(city)) {
			rank += 35
		}
	}
	if country != "" && strings.Contains(strings.ToLower(place.DisplayName), strings.ToLower(country)) {
		rank += 20
	}
	if place.DistanceKm > 0 {
		rank += 10 / (1 + place.DistanceKm)
	}
	return rank
}

func (p *nominatimProvider) Reverse(ctx context.Context, lat, lng float64, language string) (*PlaceResult, error) {
	values := url.Values{"lat": {strconv.FormatFloat(lat, 'f', 6, 64)}, "lon": {strconv.FormatFloat(lng, 'f', 6, 64)}, "format": {"jsonv2"}, "addressdetails": {"1"}, "namedetails": {"1"}, "accept-language": {language}}
	var raw nominatimPlace
	if err := p.request(ctx, "reverse", values, &raw); err != nil {
		return p.reversePhoton(ctx, lat, lng, language)
	}
	result := placeFromNominatim(raw)
	return &result, nil
}

func (p *nominatimProvider) reversePhoton(ctx context.Context, lat, lng float64, language string) (*PlaceResult, error) {
	values := url.Values{
		"lat": {strconv.FormatFloat(lat, 'f', 6, 64)},
		"lon": {strconv.FormatFloat(lng, 'f', 6, 64)},
	}
	setPhotonLanguage(values, language)
	var raw photonFeatureCollection
	if err := p.photonRequest(ctx, "reverse", values, &raw); err != nil {
		return nil, err
	}
	if len(raw.Features) == 0 {
		return nil, fmt.Errorf("photon returned no reverse-geocode result")
	}
	result := placeFromPhoton(raw.Features[0])
	return &result, nil
}

// Photon currently accepts only a limited set of language codes. Omitting the
// parameter lets it return the source language instead of failing the request
// for Arabic or Turkish users.
func setPhotonLanguage(values url.Values, language string) {
	switch strings.ToLower(strings.TrimSpace(language)) {
	case "en", "de", "fr", "it":
		values.Set("lang", strings.ToLower(strings.TrimSpace(language)))
	}
}

func placeFromPhoton(item photonFeature) PlaceResult {
	props := item.Properties
	var lat, lng float64
	if len(item.Geometry.Coordinates) >= 2 {
		lng = item.Geometry.Coordinates[0]
		lat = item.Geometry.Coordinates[1]
	}
	city := props.City
	if city == "" {
		city = props.Locality
	}
	street := props.Street
	district := props.District
	address := strings.Join(nonEmpty(street, district, city), ", ")
	name := props.Name
	if name == "" {
		name = address
	}
	return PlaceResult{
		Name:        name,
		Category:    props.OSMKey + ":" + props.OSMValue,
		DisplayName: strings.Join(nonEmpty(name, address, props.State, props.Country), ", "),
		Address:     address,
		Street:      street,
		District:    district,
		City:        city,
		State:       props.State,
		Country:     props.Country,
		CountryCode: strings.ToUpper(props.CountryCode),
		PostalCode:  props.Postcode,
		Latitude:    lat,
		Longitude:   lng,
		Provider:    "photon",
		ProviderID:  props.OSMType + ":" + strconv.FormatInt(props.OSMID, 10),
	}
}

func placeFromNominatim(item nominatimPlace) PlaceResult {
	lat, _ := strconv.ParseFloat(item.Lat, 64)
	lng, _ := strconv.ParseFloat(item.Lon, 64)
	street := item.Address.Road
	if street == "" {
		street = item.Address.Pedestrian
	}
	district := item.Address.Suburb
	if district == "" {
		district = item.Address.Neighbour
	}
	city := item.Address.City
	if city == "" {
		city = item.Address.Town
	}
	if city == "" {
		city = item.Address.Village
	}
	if city == "" {
		city = item.Address.County
	}
	name := item.Name
	if name == "" {
		name = strings.Split(item.DisplayName, ",")[0]
	}
	return PlaceResult{Name: name, Category: item.Category + ":" + item.Type, DisplayName: item.DisplayName, Address: strings.Join(nonEmpty(street, district, city), ", "), Street: street, District: district, City: city, State: item.Address.State, Country: item.Address.Country, CountryCode: strings.ToUpper(item.Address.CountryCode), PostalCode: item.Address.Postcode, Latitude: lat, Longitude: lng, Provider: "nominatim", ProviderID: strconv.FormatInt(item.PlaceID, 10)}
}

func nonEmpty(values ...string) []string {
	result := make([]string, 0, len(values))
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			result = append(result, value)
		}
	}
	return result
}

func distanceKm(lat1, lng1, lat2, lng2 float64) float64 {
	// Equirectangular approximation is sufficient for ranking nearby results.
	const earthKm = 6371.0
	latScale := 0.017453292519943295
	x := (lng2 - lng1) * latScale * math.Cos((lat1+lat2)*latScale/2)
	y := (lat2 - lat1) * latScale
	return earthKm * math.Sqrt(x*x+y*y)
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
