package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	if err := godotenv.Load(".env"); err != nil {
		log.Fatal("Error loading .env file")
	}

	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL is not set")
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("Failed to connect to db: %v", err)
	}
	defer db.Close()

	res, err := db.Exec("UPDATE event_registrations SET status = 'confirmed' WHERE status = 'pending'")
	if err != nil {
		log.Fatalf("Failed to update: %v", err)
	}
	
	count, _ := res.RowsAffected()
	fmt.Printf("Successfully updated %d pending registrations to confirmed.\n", count)
}
