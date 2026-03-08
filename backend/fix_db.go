//go:build ignore

// fix_db.go — Diagnoses and fixes the Azure PostgreSQL database setup
// Run with: go run fix_db.go

package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

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
	fmt.Println("✅ Connected to khair database")

	// 1. Check if PostGIS is available
	fmt.Println("\n🔍 Checking PostGIS availability...")
	var postgisAvailable bool
	err = db.QueryRow("SELECT count(*) > 0 FROM pg_available_extensions WHERE name = 'postgis'").Scan(&postgisAvailable)
	if err != nil || !postgisAvailable {
		fmt.Println("⚠️  PostGIS extension is NOT available on this Azure PostgreSQL server.")
		fmt.Println("   👉 Go to Azure Portal → khair PostgreSQL → Server parameters")
		fmt.Println("   👉 Search for 'azure.extensions' → Add 'POSTGIS' to the allowed list → Save")
		fmt.Println("   Then re-run this script.")
		return
	}

	// 2. Try to enable PostGIS
	fmt.Println("✅ PostGIS is available — enabling it...")
	_, err = db.Exec("CREATE EXTENSION IF NOT EXISTS postgis")
	if err != nil {
		fmt.Printf("❌ Failed to create PostGIS extension: %v\n", err)
		fmt.Println("   👉 Go to Azure Portal → khair PostgreSQL → Server parameters")
		fmt.Println("   👉 Search for 'azure.extensions' → Add 'POSTGIS' to the allowed list → Save")
		fmt.Println("   Then re-run this script.")
		return
	}
	fmt.Println("✅ PostGIS extension enabled")

	// 3. Check current migration state
	fmt.Println("\n🔍 Checking migration state...")
	var version int64
	var dirty bool
	err = db.QueryRow("SELECT version, dirty FROM schema_migrations ORDER BY version DESC LIMIT 1").Scan(&version, &dirty)
	if err != nil {
		fmt.Println("   No schema_migrations table found — starting fresh")
	} else {
		fmt.Printf("   Current: version=%d, dirty=%v\n", version, dirty)
		// Clear dirty migration so server can retry
		_, _ = db.Exec("DELETE FROM schema_migrations WHERE dirty = true")
		_, _ = db.Exec("DELETE FROM schema_migrations WHERE version = 1")
		fmt.Println("   ✅ Cleared stale migration entries — server will re-run migrations on next start")
	}

	// 4. List all tables
	fmt.Println("\n📋 Tables in khair database:")
	rows, err := db.Query(`SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`)
	if err == nil {
		defer rows.Close()
		count := 0
		for rows.Next() {
			var t string
			rows.Scan(&t)
			fmt.Printf("   - %s\n", t)
			count++
		}
		if count == 0 {
			fmt.Println("   (no tables yet — will be created when server restarts)")
		}
	}

	fmt.Println("\n✅ Done! Now restart the App Service for migrations to run.")
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
