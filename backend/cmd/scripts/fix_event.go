//go:build ignore
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

	_, err = db.Exec("UPDATE events SET is_online = true, online_link = 'https://meet.google.com/test-link' WHERE id = 'b203ae3b-47fd-4e09-b12b-8f9aa7fdd602'")
	if err != nil {
		log.Fatalf("Update failed: %v", err)
	}
	fmt.Println("Event fixed!")
}
