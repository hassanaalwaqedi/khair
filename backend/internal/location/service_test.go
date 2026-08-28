package location

import "testing"

func TestPlaceFromNominatimNormalizesPoiFields(t *testing.T) {
	item := nominatimPlace{
		PlaceID:     42,
		Name:        "EspressoLab Emaar Square",
		Type:        "cafe",
		Category:    "amenity",
		DisplayName: "EspressoLab Emaar Square, Istanbul, Türkiye",
		Lat:         "41.0772",
		Lon:         "29.0124",
	}
	item.Address.Road = "Libadiye Caddesi"
	item.Address.Suburb = "Ünalan"
	item.Address.City = "Istanbul"
	item.Address.Country = "Türkiye"
	item.Address.CountryCode = "tr"

	place := placeFromNominatim(item)
	if place.Name != item.Name || place.Latitude != 41.0772 || place.Longitude != 29.0124 {
		t.Fatalf("unexpected normalized place: %+v", place)
	}
	if place.Street != "Libadiye Caddesi" || place.District != "Ünalan" || place.City != "Istanbul" {
		t.Fatalf("address fields were not normalized: %+v", place)
	}
	if place.Provider != "nominatim" || place.ProviderID != "42" {
		t.Fatalf("provider metadata was not preserved: %+v", place)
	}
}

func TestDistanceKm(t *testing.T) {
	if got := distanceKm(41.0082, 28.9784, 41.0082, 28.9784); got != 0 {
		t.Fatalf("same point distance = %v, want zero", got)
	}
	if got := distanceKm(0, 0, 0, 1); got < 110 || got > 112 {
		t.Fatalf("one degree distance = %v km, want about 111", got)
	}
}

func TestPlaceRankPrefersSelectedCityBeforeDistance(t *testing.T) {
	outside := PlaceResult{City: "Küçükçekmece", DisplayName: "Küçükçekmece, Turkey", DistanceKm: 1}
	inside := PlaceResult{City: "Istanbul", DisplayName: "Istanbul, Turkey", DistanceKm: 20}
	if placeRank(inside, "Istanbul", "Turkey") <= placeRank(outside, "Istanbul", "Turkey") {
		t.Fatal("selected city should outrank a closer result outside the selected city")
	}
}
