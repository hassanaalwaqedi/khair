# ── Build stage ────────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Download modules first (better layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source and build
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -a -installsuffix cgo -o khair-api ./cmd/api

# ── Final stage ─────────────────────────────────────────────────────────────
FROM alpine:3.19

# Create non-root user
RUN addgroup -g 1001 -S khair && \
    adduser -u 1001 -S khair -G khair

WORKDIR /app

# Runtime dependencies
RUN apk --no-cache add ca-certificates tzdata curl

# Copy binary and assets from builder
COPY --from=builder /app/khair-api .
COPY --from=builder /app/migrations ./migrations
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/firebase-service-account.json ./firebase-service-account.json

# Set ownership
RUN chown -R khair:khair /app

USER khair

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["./khair-api"]
