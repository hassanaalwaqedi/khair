package database

import (
	"database/sql"
	"fmt"
	"log"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/lib/pq"

	"github.com/khair/backend/pkg/config"
)

// DB is the global database connection
var DB *sql.DB

// Connect establishes a connection to the PostgreSQL database
func Connect(cfg config.DatabaseConfig) (*sql.DB, error) {
	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)

	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	// Test the connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// Enforce UTF-8 for client communication and validate server encoding.
	if _, err := db.Exec(`SET client_encoding = 'UTF8'`); err != nil {
		return nil, fmt.Errorf("failed to set client encoding to UTF8: %w", err)
	}

	var serverEncoding string
	if err := db.QueryRow(`SHOW SERVER_ENCODING`).Scan(&serverEncoding); err != nil {
		return nil, fmt.Errorf("failed to read server encoding: %w", err)
	}
	if strings.ToUpper(serverEncoding) != "UTF8" {
		return nil, fmt.Errorf("database server encoding must be UTF8, got %s", serverEncoding)
	}

	// Configure connection pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	DB = db
	log.Println("Database connection established")

	return db, nil
}

// RunMigrations runs database migrations
func RunMigrations(db *sql.DB, migrationsPath string) error {
	driver, err := postgres.WithInstance(db, &postgres.Config{})
	if err != nil {
		return fmt.Errorf("failed to create migration driver: %w", err)
	}

	m, err := migrate.NewWithDatabaseInstance(
		fmt.Sprintf("file://%s", migrationsPath),
		"postgres",
		driver,
	)
	if err != nil {
		return fmt.Errorf("failed to create migration instance: %w", err)
	}

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	log.Println("Database migrations completed")
	return nil
}

// Close closes the database connection
func Close() error {
	if DB != nil {
		return DB.Close()
	}
	return nil
}
