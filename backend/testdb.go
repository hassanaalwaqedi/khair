package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

func main() {
	godotenv.Load(".env")
	dbHost := os.Getenv("DB_HOST")
	dbPort := os.Getenv("DB_PORT")
	dbUser := os.Getenv("DB_USER")
	dbPassword := os.Getenv("DB_PASSWORD")
	dbName := os.Getenv("DB_NAME")
	dbSSLMode := os.Getenv("DB_SSLMODE")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPassword, dbName, dbSSLMode)

	if dbURL := os.Getenv("DATABASE_URL"); dbURL != "" {
		dsn = dbURL
	}

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	var url sql.NullString
	err = db.QueryRow("SELECT avatar_url FROM profiles WHERE avatar_url IS NOT NULL AND avatar_url != '' LIMIT 1").Scan(&url)
	if err != nil { fmt.Println("No avatars found") } else { fmt.Println("Avatar:", url.String) }

	err = db.QueryRow("SELECT logo_url FROM organizers WHERE logo_url IS NOT NULL AND logo_url != '' LIMIT 1").Scan(&url)
	if err != nil { fmt.Println("No logos found") } else { fmt.Println("Logo:", url.String) }

	err = db.QueryRow("SELECT image_url FROM events WHERE image_url IS NOT NULL AND image_url != '' LIMIT 1").Scan(&url)
	if err != nil { fmt.Println("No event images found") } else { fmt.Println("Event Image:", url.String) }

	var id string
	db.QueryRow("SELECT id FROM users LIMIT 1").Scan(&id)
	fmt.Println("Users exist:", id != "")
}
