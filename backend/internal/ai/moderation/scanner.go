package moderation

import (
	"math"
	"strings"

	"github.com/khair/backend/internal/ai/compliance"
	"github.com/khair/backend/internal/models"
)

type LocalProvider struct {
	complianceEngine *compliance.Engine
}

func NewLocalProvider() *LocalProvider {
	return &LocalProvider{
		complianceEngine: compliance.NewEngine(),
	}
}

func (p *LocalProvider) Analyze(content string) (float64, map[string]bool, error) {
	flags := make(map[string]bool)
	score := 0.0

	lower := strings.ToLower(content)

	compFlags := p.complianceEngine.Scan(lower)

	if compFlags.MusicDetected {
		flags["music_content"] = true
		score += 12
	}
	if compFlags.InappropriateContentDetected {
		flags["inappropriate_content"] = true
		score += 30
	}
	if compFlags.GenderMixingDetected {
		flags["gender_mixing"] = true
		score += 15
	}
	if compFlags.ExternalLinkSuspicious {
		flags["suspicious_link"] = true
		score += 20
	}
	if compFlags.ExtremismRisk {
		flags["extremism_risk"] = true
		score += 35
	}
	if compFlags.SectarianLanguage {
		flags["sectarian_language"] = true
		score += 25
	}

	textScore := analyzeTextPatterns(lower)
	score += textScore

	score = math.Min(score, 100)
	score = math.Max(score, 0)

	return score, flags, nil
}

func (p *LocalProvider) ScanCompliance(content string) *models.ComplianceFlags {
	return p.complianceEngine.Scan(strings.ToLower(content))
}

func analyzeTextPatterns(content string) float64 {
	score := 0.0

	spamIndicators := []string{
		"click here", "free money", "guaranteed", "act now",
		"limited time", "winner", "congratulations", "urgent",
		"buy now", "discount code", "promo code",
	}
	for _, indicator := range spamIndicators {
		if strings.Contains(content, indicator) {
			score += 5
		}
	}

	if strings.Count(content, "!") > 5 {
		score += 3
	}
	if strings.Count(content, "$") > 2 {
		score += 5
	}

	upperCount := 0
	totalAlpha := 0
	for _, r := range content {
		if r >= 'A' && r <= 'Z' {
			upperCount++
			totalAlpha++
		} else if r >= 'a' && r <= 'z' {
			totalAlpha++
		}
	}
	if totalAlpha > 20 && float64(upperCount)/float64(totalAlpha) > 0.5 {
		score += 8
	}

	if len(content) > 10000 {
		score += 5
	}

	return score
}

type Scanner struct {
	provider         AIProvider
	complianceEngine *compliance.Engine
}

func NewScanner(provider AIProvider) *Scanner {
	return &Scanner{
		provider:         provider,
		complianceEngine: compliance.NewEngine(),
	}
}

func (s *Scanner) ScanEvent(req *models.ScanRequest) (*models.ScanResult, error) {
	combinedText := req.Title + " " + req.Description + " " + req.Tags + " " + req.MeetingLink

	riskScore, detectedFlags, err := s.provider.Analyze(combinedText)
	if err != nil {
		return nil, err
	}

	complianceFlags := s.complianceEngine.Scan(strings.ToLower(combinedText))

	decision := DetermineDecision(riskScore)

	eventStatus := "pending"
	if decision == models.AIDecisionHighRisk || complianceFlags.HasHighRiskFlag() {
		eventStatus = "under_review"
	}

	return &models.ScanResult{
		RiskScore:       riskScore,
		Decision:        decision,
		DetectedFlags:   detectedFlags,
		ComplianceFlags: complianceFlags,
		EventStatus:     eventStatus,
		AutoApproved:    false,
	}, nil
}

func DetermineDecision(score float64) models.AIDecision {
	switch {
	case score <= 30:
		return models.AIDecisionSafe
	case score <= 70:
		return models.AIDecisionReviewRequired
	default:
		return models.AIDecisionHighRisk
	}
}
