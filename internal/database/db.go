package database

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite" // Pure Go driver
)

var DB *sql.DB

func InitDB() error {
	dataDir, err := getDataDir()
	if err != nil {
		return fmt.Errorf("failed to determine data directory: %w", err)
	}

	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return fmt.Errorf("failed to create data directory: %w", err)
	}

	DB, err = sql.Open("sqlite", filepath.Join(dataDir, "tasks.db"))
	if err != nil {
		return err
	}

	// Initialize the schema
	_, err = DB.Exec(`CREATE TABLE IF NOT EXISTS tasks (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT,
		priority INTEGER,
		author TEXT
	);`)
	return err
}

func getDataDir() (string, error) {
	// Check env var first
	if dir := os.Getenv("TASK_CLI_DATA_DIR"); dir != "" {
		return dir, nil
	}
	// Default to ~/.task-cli
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".task-cli"), nil
}
