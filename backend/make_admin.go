//go:build ignore

package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	email := "hassanalwaqedi3@gmail.com"
	password := "As717801454*"
	name := "Hassan Al Waqedi"

	if len(os.Args) > 1 {
		email = os.Args[1]
	}
	if len(os.Args) > 2 {
		password = os.Args[2]
	}

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

	// Check if user exists
	var existingID string
	err = db.QueryRow("SELECT id FROM users WHERE email = $1", email).Scan(&existingID)
	if err == nil {
		// User exists — update it
		hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		_, err = db.Exec(`
			UPDATE users SET role='admin', password_hash=$2, is_verified=true, status='active', updated_at=NOW()
			WHERE email=$1
		`, email, string(hash))
		if err != nil {
			log.Fatalf("❌ Failed to update: %v", err)
		}
		fmt.Printf("✅ Updated existing user '%s' → admin\n", email)
	} else {
		// Create new user
		hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		userID := uuid.New()
		orgID := uuid.New()

		_, err = db.Exec(`
			INSERT INTO users (id, email, password_hash, role, status, is_verified, created_at, updated_at)
			VALUES ($1, $2, $3, 'admin', 'active', true, NOW(), NOW())
		`, userID, email, string(hash))
		if err != nil {
			log.Fatalf("❌ Failed to create user: %v", err)
		}

		_, err = db.Exec(`
			INSERT INTO organizers (id, user_id, name, status, created_at, updated_at)
			VALUES ($1, $2, $3, 'approved', NOW(), NOW())
		`, orgID, userID, name)
		if err != nil {
			fmt.Printf("⚠️  User created but organizer profile failed: %v\n", err)
		}

		fmt.Printf("✅ Created admin user:\n")
		fmt.Printf("   ID:       %s\n", userID)
		fmt.Printf("   Email:    %s\n", email)
		fmt.Printf("   Password: %s\n", password)
		fmt.Printf("   Role:     admin\n")
	}

	fmt.Println("\n🔑 You can now sign in!")
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
