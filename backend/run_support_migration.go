package main

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/lib/pq"
)

func main() {
	connStr := "postgresql://postgres.ulwubufgyodwmajbsfsw:As717801454*@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres?sslmode=require"
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Failed to open db: %v", err)
	}
	defer db.Close()

	content, err := os.ReadFile("migrations/050_support_system.up.sql")
	if err != nil {
		log.Fatalf("Failed to read migration file: %v", err)
	}

	_, err = db.Exec(string(content))
	if err != nil {
		log.Fatalf("Migration failed: %v", err)
	}
	fmt.Println("Migration 050 successfully applied!")
}
