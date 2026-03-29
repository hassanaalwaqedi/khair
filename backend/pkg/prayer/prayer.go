package prayer

import (
	"math"
	"time"
)

// Times holds the five daily prayer times plus sunrise.
type Times struct {
	Fajr    time.Time `json:"fajr"`
	Sunrise time.Time `json:"sunrise"`
	Dhuhr   time.Time `json:"dhuhr"`
	Asr     time.Time `json:"asr"`
	Maghrib time.Time `json:"maghrib"`
	Isha    time.Time `json:"isha"`
}

// Window represents a blocked window around a prayer time.
type Window struct {
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
	Name  string    `json:"name"`
}

// Method is the calculation method for prayer times.
type Method int

const (
	MWL  Method = iota // Muslim World League
	ISNA               // Islamic Society of North America
	Egypt              // Egyptian General Authority of Survey
)

// methodAngles returns (fajr angle, isha angle) for the method.
func methodAngles(m Method) (float64, float64) {
	switch m {
	case ISNA:
		return 15.0, 15.0
	case Egypt:
		return 19.5, 17.5
	default: // MWL
		return 18.0, 17.0
	}
}

// Calculate computes the five prayer times for a given date, location, and method.
func Calculate(date time.Time, lat, lng float64, method Method) Times {
	fajrAngle, ishaAngle := methodAngles(method)

	// Julian date
	jd := julianDate(date)

	// Sun declination and equation of time
	decl := sunDeclination(jd)
	eqt := equationOfTime(jd)

	// Dhuhr = 12:00 - eqt - longitude/15 (in hours, UTC)
	dhuhr := 12.0 - eqt - lng/15.0

	// Hour angles
	sunrise := dhuhr - hourAngle(lat, decl, 0.8333) // 0.8333° for atmospheric refraction
	sunset := dhuhr + hourAngle(lat, decl, 0.8333)

	fajr := dhuhr - hourAngle(lat, decl, fajrAngle)
	isha := dhuhr + hourAngle(lat, decl, ishaAngle)

	// Asr (Shafi'i: shadow = object length + 1)
	asrHA := asrHourAngle(lat, decl, 1.0)
	asr := dhuhr + asrHA

	loc := date.Location()
	base := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc)

	return Times{
		Fajr:    hoursToTime(base, fajr),
		Sunrise: hoursToTime(base, sunrise),
		Dhuhr:   hoursToTime(base, dhuhr),
		Asr:     hoursToTime(base, asr),
		Maghrib: hoursToTime(base, sunset),
		Isha:    hoursToTime(base, isha),
	}
}

// BlockedWindows returns time windows around each prayer for blocking.
// beforeMin: minutes before each prayer to block.
// afterMin: minutes after each prayer to block.
func BlockedWindows(times Times, beforeMin, afterMin int) []Window {
	before := time.Duration(beforeMin) * time.Minute
	after := time.Duration(afterMin) * time.Minute

	prayers := []struct {
		name string
		t    time.Time
	}{
		{"Fajr", times.Fajr},
		{"Dhuhr", times.Dhuhr},
		{"Asr", times.Asr},
		{"Maghrib", times.Maghrib},
		{"Isha", times.Isha},
	}

	// If it's Friday, extend Dhuhr window for Jumu'ah
	if times.Dhuhr.Weekday() == time.Friday {
		for i, p := range prayers {
			if p.name == "Dhuhr" {
				prayers[i].name = "Jumu'ah"
				// Block 45 min before and 30 min after for Jumu'ah
				before = 45 * time.Minute
				after = 30 * time.Minute
			}
		}
	}

	windows := make([]Window, len(prayers))
	for i, p := range prayers {
		b := before
		a := after
		if p.name == "Jumu'ah" {
			b = 45 * time.Minute
			a = 30 * time.Minute
		}
		windows[i] = Window{
			Start: p.t.Add(-b),
			End:   p.t.Add(a),
			Name:  p.name,
		}
	}
	return windows
}

// ── Astronomical helpers ──

func julianDate(t time.Time) float64 {
	y := float64(t.Year())
	m := float64(t.Month())
	d := float64(t.Day())

	if m <= 2 {
		y--
		m += 12
	}

	a := math.Floor(y / 100)
	b := 2 - a + math.Floor(a/4)

	return math.Floor(365.25*(y+4716)) + math.Floor(30.6001*(m+1)) + d + b - 1524.5
}

func sunDeclination(jd float64) float64 {
	d := jd - 2451545.0
	g := mod(357.529 + 0.98560028*d, 360)
	q := mod(280.459 + 0.98564736*d, 360)
	l := mod(q+1.915*sin(g)+0.020*sin(2*g), 360)
	e := 23.439 - 0.00000036*d
	return asin(sin(e) * sin(l))
}

func equationOfTime(jd float64) float64 {
	d := jd - 2451545.0
	g := mod(357.529+0.98560028*d, 360)
	q := mod(280.459+0.98564736*d, 360)
	l := mod(q+1.915*sin(g)+0.020*sin(2*g), 360)
	e := 23.439 - 0.00000036*d
	ra := atan2(cos(e)*sin(l), cos(l)) / 15.0
	return (q/15.0 - mod(ra, 24)) // in hours
}

func hourAngle(lat, decl, angle float64) float64 {
	cos_ha := (sin(angle) - sin(lat)*sin(decl)) / (cos(lat) * cos(decl))
	if cos_ha > 1 {
		return 0
	}
	if cos_ha < -1 {
		return math.Pi / 15.0
	}
	return acos(cos_ha) / 15.0
}

func asrHourAngle(lat, decl, factor float64) float64 {
	a := atan(1.0 / (factor + tan(math.Abs(lat-decl))))
	cos_ha := (sin(90-a) - sin(lat)*sin(decl)) / (cos(lat) * cos(decl))
	if cos_ha > 1 {
		return 0
	}
	return acos(cos_ha) / 15.0
}

func hoursToTime(base time.Time, hours float64) time.Time {
	// Adjust to UTC offset: the calculation assumes UTC, but base is in local time.
	_, offset := base.Zone()
	hours += float64(offset) / 3600.0

	h := int(hours)
	m := int((hours - float64(h)) * 60)
	s := int(((hours - float64(h)) * 60 - float64(m)) * 60)
	return base.Add(time.Duration(h)*time.Hour + time.Duration(m)*time.Minute + time.Duration(s)*time.Second)
}

// Trig helpers (degree-based)
func sin(deg float64) float64  { return math.Sin(deg * math.Pi / 180) }
func cos(deg float64) float64  { return math.Cos(deg * math.Pi / 180) }
func tan(deg float64) float64  { return math.Tan(deg * math.Pi / 180) }
func asin(x float64) float64   { return math.Asin(x) * 180 / math.Pi }
func acos(x float64) float64   { return math.Acos(x) * 180 / math.Pi }
func atan(x float64) float64   { return math.Atan(x) * 180 / math.Pi }
func atan2(y, x float64) float64 { return math.Atan2(y*math.Pi/180, x*math.Pi/180) * 180 / math.Pi }
func mod(a, b float64) float64 { return a - b*math.Floor(a/b) }
