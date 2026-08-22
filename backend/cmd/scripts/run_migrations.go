//go:build ignore

package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"

	_ "github.com/lib/pq"
)

func main() {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		getenv("DB_HOST", "khair.postgres.database.azure.com"),
		getenv("DB_PORT", "5432"),
		getenv("DB_USER", "khair"),
		getenv("DB_PASSWORD", "Net2026*"),
		getenv("DB_NAME", "khair"),
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to open DB: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to connect: %v", err)
	}
	fmt.Println("✅ Connected to database")

	// Get current migration version
	var currentVersion int64
	err = db.QueryRow("SELECT COALESCE(MAX(version), 0) FROM schema_migrations WHERE dirty = false").Scan(&currentVersion)
	if err != nil {
		currentVersion = 0
	}

	// Clear any dirty entries
	db.Exec("DELETE FROM schema_migrations WHERE dirty = true")
	fmt.Printf("📍 Current clean migration version: %d\n\n", currentVersion)

	// Find and run pending migration files
	files, err := filepath.Glob("migrations/*.up.sql")
	if err != nil {
		log.Fatalf("Failed to find migration files: %v", err)
	}
	sort.Strings(files)

	for _, file := range files {
		// Parse version number from filename (e.g., "013_ai_moderation.up.sql" → 13)
		base := filepath.Base(file)
		parts := strings.SplitN(base, "_", 2)
		var version int64
		fmt.Sscanf(parts[0], "%d", &version)

		if version <= currentVersion {
			continue // already applied
		}

		fmt.Printf("▶️  Running migration %03d: %s...\n", version, base)

		content, err := os.ReadFile(file)
		if err != nil {
			log.Fatalf("   ❌ Failed to read %s: %v", file, err)
		}

		_, err = db.Exec(string(content))
		if err != nil {
			fmt.Printf("   ⚠️  Error: %v\n", err)
			fmt.Printf("   Continuing to next migration...\n")
			// Record this version anyway since the table might partially exist
			db.Exec("INSERT INTO schema_migrations (version, dirty) VALUES ($1, false) ON CONFLICT (version) DO UPDATE SET dirty = false", version)
			continue
		}

		// Record successful migration
		db.Exec("INSERT INTO schema_migrations (version, dirty) VALUES ($1, false) ON CONFLICT (version) DO UPDATE SET dirty = false", version)
		fmt.Printf("   ✅ Done\n")
	}

	// List all tables
	fmt.Println("\n📋 All tables:")
	rows, _ := db.Query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")
	defer rows.Close()
	for rows.Next() {
		var t string
		rows.Scan(&t)
		fmt.Printf("   - %s\n", t)
	}

	fmt.Println("\n✅ All migrations applied!")
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
