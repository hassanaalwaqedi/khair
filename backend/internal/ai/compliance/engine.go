package compliance

import (
	"regexp"
	"strings"

	"github.com/khair/backend/internal/models"
)

type Engine struct {
	musicPatterns         []*regexp.Regexp
	inappropriatePatterns []*regexp.Regexp
	genderMixingPatterns  []*regexp.Regexp
	extremismPatterns     []*regexp.Regexp
	sectarianPatterns     []*regexp.Regexp
	suspiciousLinkPattern *regexp.Regexp
	musicKeywords         []string
	inappropriateKW       []string
	genderMixingKW        []string
	extremismKW           []string
	sectarianKW           []string
}

func NewEngine() *Engine {
	e := &Engine{}
	e.initPatterns()
	return e
}

func (e *Engine) initPatterns() {
	e.musicKeywords = []string{
		"music", "concert", "dj", "band", "singing", "karaoke",
		"musical", "live band", "orchestra", "rap", "hip hop",
		"dance party", "nightclub", "disco", "rave",
		"موسيقى", "أغاني", "مغني", "حفل موسيقي",
		"غناء", "رقص", "ديسكو",
	}

	e.inappropriateKW = []string{
		"alcohol", "beer", "wine", "bar", "pub", "drinking",
		"gambling", "casino", "betting", "lottery",
		"adult content", "explicit", "nsfw",
		"خمر", "كحول", "قمار", "ميسر",
	}

	e.genderMixingKW = []string{
		"mixed party", "co-ed party", "singles mixer",
		"dating event", "speed dating", "couples night",
		"hookup", "matchmaking party",
		"حفلة مختلطة", "تعارف",
	}

	e.extremismKW = []string{
		"jihad war", "armed struggle", "violent revolution",
		"destroy enemies", "holy war attack", "caliphate uprising",
		"infidel punishment", "takfir",
		"تكفير", "قتال المرتدين",
	}

	e.sectarianKW = []string{
		"shia kafir", "sunni kafir", "rafida", "nasibi",
		"deviant sect", "false muslim", "mushrik group",
		"bid'ah people are kafir",
		"روافض", "نواصب", "كفار الشيعة", "كفار السنة",
	}

	for _, kw := range e.musicKeywords {
		pattern := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
		e.musicPatterns = append(e.musicPatterns, pattern)
	}

	for _, kw := range e.inappropriateKW {
		pattern := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
		e.inappropriatePatterns = append(e.inappropriatePatterns, pattern)
	}

	for _, kw := range e.genderMixingKW {
		pattern := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
		e.genderMixingPatterns = append(e.genderMixingPatterns, pattern)
	}

	for _, kw := range e.extremismKW {
		pattern := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
		e.extremismPatterns = append(e.extremismPatterns, pattern)
	}

	for _, kw := range e.sectarianKW {
		pattern := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(kw) + `\b`)
		e.sectarianPatterns = append(e.sectarianPatterns, pattern)
	}

	e.suspiciousLinkPattern = regexp.MustCompile(
		`(?i)(https?://)?(bit\.ly|tinyurl|t\.co|goo\.gl|rb\.gy|is\.gd|cutt\.ly|shorturl|` +
			`.*\.(tk|ml|ga|cf|gq)|` +
			`[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)`)
}

func (e *Engine) Scan(content string) *models.ComplianceFlags {
	flags := &models.ComplianceFlags{}

	flags.MusicDetected = e.matchAny(content, e.musicPatterns)
	flags.InappropriateContentDetected = e.matchAny(content, e.inappropriatePatterns)
	flags.GenderMixingDetected = e.matchAny(content, e.genderMixingPatterns)
	flags.ExtremismRisk = e.matchAny(content, e.extremismPatterns)
	flags.SectarianLanguage = e.matchAny(content, e.sectarianPatterns)
	flags.ExternalLinkSuspicious = e.suspiciousLinkPattern.MatchString(content)

	return flags
}

func (e *Engine) matchAny(content string, patterns []*regexp.Regexp) bool {
	for _, p := range patterns {
		if p.MatchString(content) {
			return true
		}
	}
	return false
}

func (e *Engine) GetMatchedKeywords(content string) map[string][]string {
	matched := make(map[string][]string)
	lower := strings.ToLower(content)

	for _, kw := range e.musicKeywords {
		if strings.Contains(lower, kw) {
			matched["music"] = append(matched["music"], kw)
		}
	}
	for _, kw := range e.inappropriateKW {
		if strings.Contains(lower, kw) {
			matched["inappropriate"] = append(matched["inappropriate"], kw)
		}
	}
	for _, kw := range e.genderMixingKW {
		if strings.Contains(lower, kw) {
			matched["gender_mixing"] = append(matched["gender_mixing"], kw)
		}
	}
	for _, kw := range e.extremismKW {
		if strings.Contains(lower, kw) {
			matched["extremism"] = append(matched["extremism"], kw)
		}
	}
	for _, kw := range e.sectarianKW {
		if strings.Contains(lower, kw) {
			matched["sectarian"] = append(matched["sectarian"], kw)
		}
	}

	return matched
}
