//go:build ignore
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/joho/godotenv"
	"github.com/khair/backend/internal/organizerapplication"
)

func main() {
	if err := godotenv.Load(); err != nil {
		log.Println("Note: .env not found or error loading, continuing with env variables")
	}

	r2 := organizerapplication.NewS3StoreFromEnv()
	
	ctx := context.Background()
	data := []byte("hello world from internal s3")
	err := r2.Put(ctx, "test_upload_internal.txt", data, "text/plain")
	if err != nil {
		log.Fatalf("Failed to put: %v", err)
	}

	fmt.Println("Successfully uploaded using internal S3Store!")
}
