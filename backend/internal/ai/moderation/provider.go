package moderation

type AIProvider interface {
	Analyze(content string) (riskScore float64, flags map[string]bool, err error)
}
