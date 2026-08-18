package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"
)

func main() {
	connStr := "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454*@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Failed to open db: %v", err)
	}
	defer db.Close()

	var isOnline bool
	var onlineLink sql.NullString
	err = db.QueryRow("SELECT is_online, online_link FROM events WHERE id = 'b203ae3b-47fd-4e09-b12b-8f9aa7fdd602'").Scan(&isOnline, &onlineLink)
	if err != nil {
		log.Fatalf("Query failed: %v", err)
	}
	fmt.Printf("IsOnline: %v\nOnlineLink: %v\n", isOnline, onlineLink)
}
