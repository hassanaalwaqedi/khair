//go:build integration

package tests

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	_ "github.com/lib/pq"
)

// testDB is the shared database connection for integration tests.
var testDB *sql.DB

// SetupTestDB connects to the test PostgreSQL database and runs all migrations.
// It should be called from TestMain.
func SetupTestDB() *sql.DB {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		envOr("DB_HOST", "localhost"),
		envOr("DB_PORT", "5432"),
		envOr("DB_USER", "khair_test"),
		envOr("DB_PASSWORD", "khair_test_pw"),
		envOr("DB_NAME", "khair_test"),
		envOr("DB_SSLMODE", "disable"),
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("SetupTestDB: connect: %v", err)
	}
	if err := db.Ping(); err != nil {
		log.Fatalf("SetupTestDB: ping: %v", err)
	}

	runMigrations(db)
	testDB = db
	return db
}

// CleanupDB truncates all user-created tables so each test starts fresh.
func CleanupDB(t *testing.T) {
	t.Helper()
	tables := []string{
		"notifications",
		"email_verifications",
		"refresh_tokens",
		"events",
		"organizers",
		"user_roles",
		"users",
	}
	for _, table := range tables {
		if _, err := testDB.Exec(fmt.Sprintf("TRUNCATE TABLE %s CASCADE", table)); err != nil {
			// Table might not exist yet — ignore
			log.Printf("CleanupDB: truncate %s: %v (ignored)", table, err)
		}
	}
}

// runMigrations applies all .up.sql files in ../migrations/ in order.
func runMigrations(db *sql.DB) {
	migrationsDir := filepath.Join("..", "migrations")
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		log.Fatalf("runMigrations: read dir: %v", err)
	}

	var upFiles []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".up.sql") {
			upFiles = append(upFiles, e.Name())
		}
	}
	sort.Strings(upFiles)

	for _, name := range upFiles {
		path := filepath.Join(migrationsDir, name)
		sqlBytes, err := os.ReadFile(path)
		if err != nil {
			log.Fatalf("runMigrations: read %s: %v", name, err)
		}
		if _, err := db.Exec(string(sqlBytes)); err != nil {
			log.Printf("runMigrations: %s: %v (continuing)", name, err)
		}
	}
}

// envOr returns the value of an environment variable or a default.
func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
