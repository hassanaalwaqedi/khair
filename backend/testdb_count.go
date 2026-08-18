package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"
)

func main() {
	db, err := sql.Open("postgres", "postgres://khair:khair@localhost:5432/khair?sslmode=disable")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	var url sql.NullString
	err = db.QueryRow("SELECT avatar_url FROM profiles ").Scan(&url)
	if err != nil { fmt.Println("No avatars found") } else { fmt.Println("Avatar:", url.String) }

	err = db.QueryRow("SELECT logo_url FROM organizers ").Scan(&url)
	if err != nil { fmt.Println("No logos found") } else { fmt.Println("Logo:", url.String) }

	err = db.QueryRow("SELECT image_url FROM events ").Scan(&url)
	if err != nil { fmt.Println("No event images found") } else { fmt.Println("Event Image:", url.String) }
}
