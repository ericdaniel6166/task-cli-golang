Here is the complete, final source code for **task-cli**. This setup includes the new `list` command, a pure-Go SQLite implementation (no CGO required), professional error handling, and plugin discovery logic.

### 1. Setup & Dependencies

Run these commands in your terminal to initialize the project:

Bash

```
go mod init task-cli
go get github.com/spf13/cobra github.com/spf13/viper github.com/spf13/cobra/doc
go get modernc.org/sqlite
```

---

### 2. Core Entry Point

**`main.go`**

Go

```
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
```

---

### 3. Command Definitions (`cmd/`)

**`cmd/root.go`**

Go

```
package cmd

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"task-cli/internal/config"

	"github.com/spf13/cobra"
)

var cfgFile string

// RootCmd is exported for documentation generation and main.go access
var RootCmd = &cobra.Command{
	Use:   "task-cli",
	Short: "Task-CLI: A professional task manager",
	Long:  `An extensible CLI tool using Go, supporting nested commands and kubectl-style plugins.`,
}

func Execute() {
	// Plugin Discovery: If the command is unknown, look for 'task-cli-<subcommand>' in PATH
	if len(os.Args) > 1 && !strings.HasPrefix(os.Args[1], "-") {
		_, _, err := RootCmd.Find(os.Args[1:])
		if err != nil {
			pluginName := fmt.Sprintf("task-cli-%s", os.Args[1])
			if path, err := exec.LookPath(pluginName); err == nil {
				invokePlugin(path, os.Args[2:])
				return
			}
		}
	}

	if err := RootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func invokePlugin(path string, args []string) {
	cmd := exec.Command(path, args...)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	if err := cmd.Run(); err != nil {
		os.Exit(1)
	}
}

func init() {
	cobra.OnInitialize(config.InitConfig(&cfgFile))
	RootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.task-cli.yaml)")
	RootCmd.PersistentFlags().StringP("author", "a", "Unknown", "Author for tasks")
}
```

**`cmd/task.go`** (The parent command and `add`/`list` subcommands)

Go

```
package cmd

import (
	"fmt"
	"os"
	"task-cli/internal/task"
	"text/tabwriter"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

var priority int
var taskCmd = &cobra.Command{Use: "task", Short: "Task operations"}

// 'add' subcommand
var addCmd = &cobra.Command{
	Use:   "add [name]",
	Short: "Add a new task",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		author := viper.GetString("author")
		if err := task.SaveTask(args[0], priority, author); err != nil {
			fmt.Printf("❌ Error: %v\n", err)
			return
		}
		fmt.Printf("✅ Task '%s' added.\n", args[0])
	},
}

// 'list' subcommand
var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List all tasks",
	Run: func(cmd *cobra.Command, args []string) {
		tasks, err := task.GetAllTasks()
		if err != nil {
			fmt.Printf("❌ Error: %v\n", err)
			return
		}

		// Format output as a nice table
		w := tabwriter.NewWriter(os.Stdout, 0, 0, 3, ' ', 0)
		fmt.Fprintln(w, "ID\tNAME\tPRIORITY\tAUTHOR")
		for _, t := range tasks {
			fmt.Fprintf(w, "%d\t%s\t%d\t%s\n", t.ID, t.Name, t.Priority, t.Author)
		}
		w.Flush()
	},
}

func init() {
	RootCmd.AddCommand(taskCmd)
	taskCmd.AddCommand(addCmd)
	taskCmd.AddCommand(listCmd)
	addCmd.Flags().IntVarP(&priority, "priority", "p", 1, "Task priority level")
}
```

**`cmd/plugin_install.go`**

Go

```
package cmd

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
)

var pluginCmd = &cobra.Command{Use: "plugin", Short: "Plugin management"}

var installCmd = &cobra.Command{
	Use:   "install [url] [name]",
	Short: "Install a plugin from a URL",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		url, name := args[0], "task-cli-"+args[1]
		home, _ := os.UserHomeDir()
		binDir := filepath.Join(home, ".task-cli", "bin")

		if err := os.MkdirAll(binDir, 0755); err != nil {
			fmt.Printf("❌ FS Error: %v\n", err)
			return
		}

		resp, err := http.Get(url)
		if err != nil {
			fmt.Printf("❌ Network Error: %v\n", err)
			return
		}
		defer resp.Body.Close()

		dest := filepath.Join(binDir, name)
		out, err := os.Create(dest)
		if err != nil {
			fmt.Printf("❌ Creation Error: %v\n", err)
			return
		}
		defer out.Close()

		if _, err = io.Copy(out, resp.Body); err != nil {
			fmt.Printf("❌ Download Error: %v\n", err)
			return
		}

		_ = os.Chmod(dest, 0755)
		fmt.Printf("🚀 Installed %s to %s\n", name, binDir)
	},
}

func init() {
	RootCmd.AddCommand(pluginCmd)
	pluginCmd.AddCommand(installCmd)
}
```

---

### 4. Internal Logic (`internal/`)

**`internal/database/db.go`**

Go

```
package database

import (
	"database/sql"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite" // Pure Go driver
)

var DB *sql.DB

func InitDB() error {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, ".task-cli")
	_ = os.MkdirAll(dir, 0755)

	var err error
	DB, err = sql.Open("sqlite", filepath.Join(dir, "tasks.db"))
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
```

**`internal/task/task.go`**

Go

```
package task

import "task-cli/internal/database"

type Task struct {
	ID       int
	Name     string
	Priority int
	Author   string
}

func SaveTask(name string, priority int, author string) error {
	_, err := database.DB.Exec(
		"INSERT INTO tasks (name, priority, author) VALUES (?, ?, ?)",
		name, priority, author,
	)
	return err
}

func GetAllTasks() ([]Task, error) {
	rows, err := database.DB.Query("SELECT id, name, priority, author FROM tasks")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tasks []Task
	for rows.Next() {
		var t Task
		if err := rows.Scan(&t.ID, &t.Name, &t.Priority, &t.Author); err != nil {
			return nil, err
		}
		tasks = append(tasks, t)
	}
	return tasks, nil
}
```

**`internal/config/config.go`**

Go

```
package config

import (
	"os"
	"github.com/spf13/viper"
)

func InitConfig(cfgFile *string) func() {
	return func() {
		if *cfgFile != "" {
			viper.SetConfigFile(*cfgFile)
		} else {
			home, _ := os.UserHomeDir()
			viper.AddConfigPath(home)
			viper.SetConfigName(".task-cli")
			viper.SetConfigType("yaml")
		}
		viper.AutomaticEnv()
		_ = viper.ReadInConfig()
	}
}
```

---

### 5. Automation & Distribution

**`scripts/gen_docs.go`**

Go

```
package main

import (
	"log"
	"task-cli/cmd"
	"github.com/spf13/cobra/doc"
)

func main() {
	// RootCmd is exported, so this works perfectly now
	err := doc.GenMarkdownTree(cmd.RootCmd, "./docs")
	if err != nil {
		log.Fatal(err)
	}
}
```

**`.goreleaser.yaml`**

YAML

```
version: 2
project_name: task-cli
builds:
  - env: [CGO_ENABLED=0] # Safe because of modernc.org/sqlite
    goos: [linux, windows, darwin]
    goarch: [amd64, arm64]
    main: ./main.go
archives:
  - format: tar.gz
    name_template: "{{ .ProjectName }}_{{ .Os }}_{{ .Arch }}"
```

---

### Summary of Final Features:

- **Database**: Uses SQLite via `modernc.org/sqlite`, ensuring your app remains a single binary without needing a C compiler for cross-compilation.

- **Command Set**: `task add`, `task list`, and `plugin install`.

- **Extensibility**: If a user has an executable named `task-cli-hello` in their PATH, they can run `task-cli hello`.

- **Configuration**: Supports YAML config files and environment variables via Viper.

- **Documentation**: Ready-to-go script for generating Markdown docs for your GitHub repo.