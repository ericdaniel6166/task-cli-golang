package main

import (
	"log"
	"task-cli/cmd"
	"task-cli/internal/database"
)

func main() {
	// Initialize SQLite database and tables
	if err := database.InitDB(); err != nil {
		log.Fatalf("Critical Error: Failed to initialize database: %v", err)
	}

	// Execute the CLI root command
	cmd.Execute()
}
