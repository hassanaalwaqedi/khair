package middleware

// MaxPageSize is the hard upper limit for any list endpoint.
const MaxPageSize = 100

// ClampPagination normalizes page and pageSize values:
//   - page < 1 → 1
//   - pageSize < 1 → defaultPageSize
//   - pageSize > MaxPageSize → MaxPageSize
func ClampPagination(page, pageSize, defaultPageSize int) (int, int) {
	if page < 1 {
		page = 1
	}
	if pageSize < 1 {
		pageSize = defaultPageSize
	}
	if pageSize > MaxPageSize {
		pageSize = MaxPageSize
	}
	return page, pageSize
}
