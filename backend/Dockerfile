# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -a -installsuffix cgo -o khair-api ./cmd/api

# Final stage
FROM alpine:3.19

# Create non-root user for security
RUN addgroup -g 1001 -S khair && \
    adduser -u 1001 -S khair -G khair

WORKDIR /app

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata curl

# Copy binary from builder
COPY --from=builder /app/khair-api .
COPY --from=builder /app/migrations ./migrations
COPY --from=builder /app/templates ./templates

# Set ownership
RUN chown -R khair:khair /app

# Switch to non-root user
USER khair

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
CMD ["./khair-api"]
