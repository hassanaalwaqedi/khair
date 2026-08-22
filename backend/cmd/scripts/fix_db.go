//go:build ignore
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

	oldURL := "https://pub-2fb98d8015004ff495555dd5d9718c85.r2.dev"
	newURL := "https://images.khair.it.com"

	tables := map[string]string{
		"profiles":   "avatar_url",
		"organizers": "logo_url",
		"events":     "image_url",
	}

	for table, column := range tables {
		query := fmt.Sprintf(`UPDATE %s SET %s = REPLACE(%s, $1, $2) WHERE %s LIKE $3`, table, column, column, column)
		res, err := db.Exec(query, oldURL, newURL, oldURL+"%")
		if err != nil {
			log.Printf("Error updating %s: %v\n", table, err)
			continue
		}
		affected, _ := res.RowsAffected()
		fmt.Printf("Updated %d rows in %s\n", affected, table)
	}
}
