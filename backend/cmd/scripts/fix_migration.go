//go:build ignore

package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
)

func main() {
	host := getenv("DB_HOST", "khair.postgres.database.azure.com")
	port := getenv("DB_PORT", "5432")
	user := getenv("DB_USER", "khair")
	pass := getenv("DB_PASSWORD", "Net2026*")

	// First connect to postgres to list all databases
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=postgres sslmode=require",
		host, port, user, pass)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to open DB: %v", err)
	}

	if err := db.Ping(); err != nil {
		log.Fatalf("Failed to connect to DB: %v", err)
	}
	fmt.Println("✅ Connected to server")

	// List all databases
	rows, err := db.Query("SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname")
	if err != nil {
		log.Fatalf("Failed to list databases: %v", err)
	}
	fmt.Println("\nAvailable databases:")
	var databases []string
	for rows.Next() {
		var name string
		rows.Scan(&name)
		fmt.Printf("  - %s\n", name)
		databases = append(databases, name)
	}
	rows.Close()

	// Check if khair database exists
	khairExists := false
	for _, name := range databases {
		if name == "khair" {
			khairExists = true
			break
		}
	}

	// Create the khair database if missing
	if !khairExists {
		_, err = db.Exec("CREATE DATABASE khair")
		if err != nil {
			log.Fatalf("Failed to create database: %v", err)
		}
		fmt.Println("\n✅ Created database: khair")
	}

	db.Close()

	// Try each database to find schema_migrations
	for _, dbname := range databases {
		dsn2 := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
			host, port, user, pass, dbname)
		db2, err := sql.Open("postgres", dsn2)
		if err != nil {
			continue
		}
		var count int
		err = db2.QueryRow("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'schema_migrations'").Scan(&count)
		if err != nil || count == 0 {
			db2.Close()
			continue
		}

		fmt.Printf("\n✅ Found schema_migrations in database: %s\n", dbname)

		// Show migration state
		mrows, _ := db2.Query("SELECT version, dirty FROM schema_migrations ORDER BY version")
		fmt.Printf("\n%-10s %-8s\n", "Version", "Dirty")
		fmt.Println("-------------------")
		for mrows.Next() {
			var version int64
			var dirty bool
			mrows.Scan(&version, &dirty)
			if dirty {
				fmt.Printf("%-10d ⚠️  YES\n", version)
			} else {
				fmt.Printf("%-10d ✅ no\n", version)
			}
		}
		mrows.Close()

		// Fix dirty version 13
		result, err := db2.Exec("UPDATE schema_migrations SET dirty = false WHERE dirty = true")
		if err != nil {
			log.Fatalf("Failed to fix migration: %v", err)
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected > 0 {
			fmt.Printf("\n✅ Fixed %d dirty migration(s)\n", rowsAffected)
		} else {
			fmt.Println("\nℹ️  No dirty migrations found (already clean)")
		}
		db2.Close()
		return
	}

	fmt.Println("\n❌ Could not find schema_migrations in any database")
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
