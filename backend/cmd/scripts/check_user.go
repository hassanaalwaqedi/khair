//go:build ignore
package main

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	db, err := sql.Open("postgres", "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454%2A@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	email := "hassan@khair.com"
	password := "As123456*"
	
	// Delete if exists
	db.Exec("DELETE FROM users WHERE email = $1", email)
	
	newHash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	
	// Insert admin user
	id := uuid.New().String()
	_, err = db.Exec(`
		INSERT INTO users (id, email, password_hash, role, status, is_verified, created_at, updated_at)
		VALUES ($1, $2, $3, 'admin', 'active', true, $4, $4)
	`, id, email, string(newHash), time.Now())
	
	if err != nil {
		log.Fatal("Failed to create admin:", err)
	}
	fmt.Println("Successfully created admin account: hassan@khair.com with password As123456*")
}
