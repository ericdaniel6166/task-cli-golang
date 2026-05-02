# Task-CLI Code Standards & Go Conventions

## Overview

This document establishes the coding conventions, patterns, and guidelines for the task-cli codebase. All developers should follow these standards to maintain consistency, readability, and maintainability.

## Go Version & Setup

- **Minimum Go Version**: 1.22.2
- **Module Name**: task-cli
- **Build Command**: `go build -o task-cli main.go`
- **Linting**: `gofmt` (automatic), `golangci-lint` (manual check)

## Naming Conventions

### Packages
- **Style**: lowercase, no underscores, short names
- **Location**: `cmd/`, `internal/{domain}/`
- **Examples**:
  - ✅ `cmd` - CLI commands
  - ✅ `database` - Database layer
  - ✅ `task` - Task domain logic
  - ❌ `cmd_root` - Use package + file separation instead

### Functions & Methods
- **Style**: `PascalCase` for exported, `camelCase` for unexported
- **Naming**: Verb-first for actions, noun-first for getters
- **Examples**:
  - ✅ `SaveTask()` - Creates/saves entity
  - ✅ `GetAllTasks()` - Retrieves entities
  - ✅ `DeleteTask()` - Removes entity
  - ✅ `InitDB()` - Initializes subsystem
  - ❌ `GetTasks` - Missing "All" clarifies full dataset
  - ❌ `TaskSave()` - Reverse action-first order

### Variables & Constants
- **Style**: `camelCase` (package scope), `SCREAMING_SNAKE_CASE` (constants)
- **Naming**: Descriptive, avoid single-letter except loop indices
- **Examples**:
  - ✅ `var DB *sql.DB` - Clear purpose, exported
  - ✅ `var cfgFile string` - Config file path
  - ✅ `const maxSize = 100 * 1024 * 1024` - 100MB limit
  - ❌ `var d *sql.DB` - Too abbreviated
  - ❌ `const SIZE int = 100000000` - Use multiplication, unit clarity

### Type Names
- **Style**: `PascalCase`, singular noun
- **Examples**:
  - ✅ `type Task struct` - Single entity
  - ✅ `type RootCmd` - Command object
  - ❌ `type TaskItem struct` - Redundant "Item"
  - ❌ `type Tasks struct` - Use slice, not plural type

### File Names
- **Style**: `snake_case` (Go convention), descriptive
- **Suffix Convention**: 
  - `_cmd.go` - Cobra command definitions (legacy, use descriptive names instead)
  - No suffix for business logic
- **Examples**:
  - ✅ `root.go` - Root command
  - ✅ `task.go` - Task commands
  - ✅ `plugin_install.go` - Plugin installation command
  - ✅ `db.go` - Database module

## Code Structure & Organization

### File Organization
Each file should follow this layout:

```go
// 1. Package declaration
package cmd

// 2. Imports (grouped by standard, external, local)
import (
    "fmt"
    "os"
    
    "github.com/spf13/cobra"
    "github.com/spf13/viper"
    
    "task-cli/internal/database"
)

// 3. Constants and package-level variables
const maxSize = 100 * 1024 * 1024
var DB *sql.DB

// 4. Type definitions
type Task struct {
    ID       int
    Name     string
    Priority int
    Author   string
}

// 5. Exported functions (alphabetically)
func GetAllTasks() ([]Task, error) { }
func SaveTask(name string, priority int, author string) error { }

// 6. Unexported functions (alphabetically)
func parseTaskID(idStr string) (int, error) { }
func validateTaskName(name string) error { }

// 7. init() function (command registration)
func init() { }
```

### Import Organization
Group imports in three sections, separated by blank lines:

```go
import (
    // Standard library (alphabetical)
    "database/sql"
    "fmt"
    "os"
    
    // External dependencies (alphabetical)
    "github.com/spf13/cobra"
    "github.com/spf13/viper"
    
    // Local imports (alphabetical)
    "task-cli/internal/database"
    "task-cli/internal/task"
)
```

### Package Structure
```
task-cli/
├── main.go                              # Entry point only
├── cmd/                                 # Cobra commands
│   ├── root.go                          # Root command, plugin discovery
│   ├── task.go                          # Task CRUD commands
│   └── plugin_install.go                # Plugin installation
├── internal/                            # Private business logic
│   ├── config/config.go                 # Configuration
│   ├── database/db.go                   # Database layer
│   └── task/task.go                     # Task domain logic
└── scripts/gen_docs.go                  # Utilities
```

**Rule**: Code in `internal/` is private to this module and not for external import.

## Function & Method Patterns

### Error Handling
**Pattern**: Return errors as the last return value

```go
// ✅ Good: Standard Go error pattern
func SaveTask(name string, priority int, author string) error {
    _, err := database.DB.Exec(
        "INSERT INTO tasks (name, priority, author) VALUES (?, ?, ?)",
        name, priority, author,
    )
    return err
}

// ✅ Good: Multiple returns with error
func GetAllTasks() ([]Task, error) {
    rows, err := database.DB.Query("SELECT ...")
    if err != nil {
        return nil, err
    }
    defer rows.Close()
    // ... process rows
    return tasks, nil
}

// ✅ Good: Wrapped error with context
func DeleteTask(id int) error {
    result, err := database.DB.Exec("DELETE FROM tasks WHERE id = ?", id)
    if err != nil {
        return err
    }
    rows, _ := result.RowsAffected()
    if rows == 0 {
        return fmt.Errorf("task %d not found", id)
    }
    return nil
}

// ❌ Bad: Error as first return
func SaveTask(name string) (error, Task) { }

// ❌ Bad: Panic on error (except main.go)
func SaveTask(name string) {
    _, err := database.DB.Exec(...)
    if err != nil {
        panic(err)  // Never in library code
    }
}

// ❌ Bad: Silent error swallowing
func SaveTask(name string) {
    _, _ = database.DB.Exec(...)  // Ignore all errors
}
```

### Command Run Functions
**Pattern**: Cobra command handlers should be short, delegate to business logic

```go
// ✅ Good: Clear separation of concerns
var addCmd = &cobra.Command{
    Use:   "add [name]",
    Short: "Add a new task",
    Args:  cobra.ExactArgs(1),
    Run: func(cmd *cobra.Command, args []string) {
        author := viper.GetString("author")
        if err := task.SaveTask(args[0], priority, author); err != nil {
            fmt.Printf("Error: %v\n", err)
            return
        }
        fmt.Printf("Task '%s' added.\n", args[0])
    },
}

// ❌ Bad: Business logic in Run function
var addCmd = &cobra.Command{
    Run: func(cmd *cobra.Command, args []string) {
        _, err := database.DB.Exec(
            "INSERT INTO tasks (name, priority, author) VALUES (?, ?, ?)",
            args[0], priority, viper.GetString("author"),
        )
        if err != nil {
            fmt.Printf("Error: %v\n", err)
            return
        }
    },
}
```

### Input Validation
**Pattern**: Validate early, return specific errors

```go
// ✅ Good: Validate type first
func DeleteTask(idStr string) error {
    id, err := strconv.Atoi(idStr)
    if err != nil {
        return fmt.Errorf("invalid task ID '%s': must be a number", idStr)
    }
    // ... proceed with deletion
}

// ✅ Good: Check preconditions
func installPlugin(url, name string) error {
    parsedURL, err := url.Parse(url)
    if err != nil {
        return fmt.Errorf("invalid URL: %w", err)
    }
    if parsedURL.Scheme != "https" {
        return fmt.Errorf("security error: only HTTPS URLs are allowed")
    }
    if strings.Contains(name, "/") || strings.Contains(name, "\\") {
        return fmt.Errorf("invalid plugin name: must not contain path separators")
    }
    // ... proceed
}

// ❌ Bad: No validation, assume inputs are valid
func DeleteTask(idStr string) error {
    id, _ := strconv.Atoi(idStr)  // Silently fails
    // ... proceed with garbage ID
}
```

## Cobra Command Patterns

### Command Registration
**Pattern**: Define command, register in init()

```go
// ✅ Good: Clear, modular command definition
var taskCmd = &cobra.Command{
    Use:   "task",
    Short: "Task operations",
}

var addCmd = &cobra.Command{
    Use:   "add [name]",
    Short: "Add a new task",
    Args:  cobra.ExactArgs(1),
    Run: func(cmd *cobra.Command, args []string) { },
}

func init() {
    RootCmd.AddCommand(taskCmd)
    taskCmd.AddCommand(addCmd)
    addCmd.Flags().IntVarP(&priority, "priority", "p", 1, "Task priority level")
}
```

### Flag Definition
**Pattern**: Short flag for common options, long for clarity

```go
// ✅ Good: Concise short flags, descriptive long names
cmd.Flags().StringVarP(&cfgFile, "config", "c", "", "Config file path")
cmd.Flags().IntVarP(&priority, "priority", "p", 1, "Priority level (1-5)")
cmd.PersistentFlags().StringP("author", "a", "Unknown", "Task author")

// ✅ Good: Bind to Viper for env var + config file support
viper.BindPFlag("author", RootCmd.PersistentFlags().Lookup("author"))

// ❌ Bad: No short flag for common options
cmd.Flags().StringVar(&cfgFile, "config-file", "", "...")

// ❌ Bad: Vague help text
cmd.Flags().IntVar(&priority, "p", 1, "priority")
```

## Database Patterns

### SQL Queries
**Pattern**: Always use parameterized queries to prevent SQL injection

```go
// ✅ Good: Parameterized query
_, err := database.DB.Exec(
    "INSERT INTO tasks (name, priority, author) VALUES (?, ?, ?)",
    name, priority, author,
)

// ✅ Good: Prepared statement for complex queries
rows, err := database.DB.Query(
    "SELECT id, name, priority, author FROM tasks WHERE priority > ?",
    minPriority,
)

// ❌ Bad: String concatenation (SQL injection risk)
query := fmt.Sprintf("INSERT INTO tasks (name) VALUES ('%s')", name)
_, err := database.DB.Exec(query)

// ❌ Bad: No error handling
_, _ = database.DB.Exec("INSERT INTO tasks ...")
```

### Row Scanning
**Pattern**: Defer close, handle scan errors

```go
// ✅ Good: Proper resource cleanup and error handling
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

// ❌ Bad: No defer, resource leak possible
func GetAllTasks() ([]Task, error) {
    rows, _ := database.DB.Query("SELECT ...")
    var tasks []Task
    for rows.Next() {
        var t Task
        rows.Scan(&t.ID, &t.Name, &t.Priority, &t.Author)
        tasks = append(tasks, t)
    }
    rows.Close()
    return tasks, nil
}
```

## Comments & Documentation

### Function Comments
**Pattern**: Exported functions have doc comments

```go
// ✅ Good: Doc comment for exported function
// SaveTask inserts a new task into the database with the given name,
// priority, and author. It returns an error if the insert fails.
func SaveTask(name string, priority int, author string) error { }

// ✅ Good: Unexported functions may have doc comments
// validateURL checks that the URL is HTTPS and properly formatted.
func validateURL(u string) error { }

// ❌ Bad: No doc comment for exported function
func SaveTask(name string, priority int, author string) error { }

// ❌ Bad: Redundant doc comment
// This function saves a task
func SaveTask(name string, priority int, author string) error { }
```

### Inline Comments
**Pattern**: Comment non-obvious logic only

```go
// ✅ Good: Explains why, not what
const maxSize = 100 * 1024 * 1024 // 100MB limit prevents disk exhaustion

// ✅ Good: Clarifies complex condition
if parsedURL.Scheme != "https" {
    return fmt.Errorf("security error: only HTTPS URLs are allowed")
}

// ❌ Bad: States the obvious
i := 0 // Set i to zero
tasks := []Task{} // Create empty slice

// ❌ Bad: Outdated comment
// TODO: Fix the bug in row scanning (actually already fixed in v2)
for rows.Next() { }
```

## Error Messages

### User-Facing Errors
**Pattern**: Clear, specific, actionable

```go
// ✅ Good: Specific error with context
if rows == 0 {
    return fmt.Errorf("task %d not found", id)
}
// Output: "Error: task 42 not found"

// ✅ Good: Error hints what to fix
if parsedURL.Scheme != "https" {
    return fmt.Errorf("security error: only HTTPS URLs are allowed")
}

// ✅ Good: Suggests next step
if err != nil {
    fmt.Printf("Error: %v\n", err)
    return
}

// ❌ Bad: Vague error
return fmt.Errorf("failed")

// ❌ Bad: No context
return fmt.Errorf("error")

// ❌ Bad: Multiple errors in one string
return fmt.Errorf("failed to save task, database error, disk full")
```

### Log Output
**Pattern**: Print to stdout for CLI feedback, stderr for errors

```go
// ✅ Good: Success to stdout
fmt.Printf("Task '%s' added.\n", name)

// ✅ Good: Error to stdout (convention for CLI tools)
fmt.Printf("Error: %v\n", err)

// ✅ Good: Plugin download progress to stdout
fmt.Printf("Installed %s to %s\n", fullName, binDir)

// ❌ Bad: Info to stderr
fmt.Fprintf(os.Stderr, "Task added")

// ❌ Bad: Log instead of print
log.Printf("Task added")
```

## Type Definitions

### Struct Design
**Pattern**: Export types with public fields only

```go
// ✅ Good: Simple, flat struct with clear purpose
type Task struct {
    ID       int
    Name     string
    Priority int
    Author   string
}

// ✅ Good: Embed Cobra command for extension
var RootCmd = &cobra.Command{
    Use:   "task-cli",
    Short: "A professional task manager",
}

// ❌ Bad: Unexported struct (should be interface or plain function returns)
type task struct {
    name string
}

// ❌ Bad: Over-engineered struct
type Task struct {
    id       int
    name     string
    getID()  func() int
    getName() func() string
}
```

## Testing & Validation

**Current Status**: No automated test suite. Manual CLI testing is primary validation method.

### Manual Test Categories (see README.md for commands)

**Task Operations**:
- `task add` - Normal case, priority flag, missing arguments
- `task list` - Empty database, multiple tasks, output format
- `task update` - Valid ID, invalid ID, priority changes only
- `task delete` - Valid ID, invalid ID, verify removal

**Input Boundaries**:
- Valid input: Normal cases (task name, ID, priority 1-5)
- Empty/nil: Empty task names, zero/negative IDs, missing flags
- Invalid type: Non-integer ID, non-integer priority
- Boundary: ID not found, very long names (no length limit)

**Database State**:
- Task persists after `SaveTask()` (verify with `task list`)
- `GetAllTasks()` returns all tasks in correct order
- `DeleteTask()` removes record, no duplicates remain
- `UpdateTask()` modifies correct fields only

**Plugin System**:
- HTTPS validation rejects HTTP URLs with clear error
- Path traversal prevention blocks `..`, `/`, `\` in plugin names
- 100MB size limit enforced with error on exceeded size
- Executable permissions set correctly (chmod 755)
- Failed downloads cleanup partial files

**Configuration**:
- YAML config file loads correctly
- Environment variables override config file
- Command-line flags override environment variables
- Missing config file doesn't break CLI

## Performance Considerations

### Database
- No index on priority (small datasets)
- No pagination (full load for small tables)
- No connection pooling (single global connection adequate)
- SQLite WAL mode handles concurrent reads

### CLI
- Plugin discovery via PATH (linear search, typical 10-50 paths)
- No caching of task list (stateless, reload on each command)
- No async operations (simpler, sequential error handling)

## Security Checklist

- [x] All SQL queries parameterized (prevents SQL injection)
- [x] Plugin URLs must be HTTPS only (enforced in cmd/plugin_install.go)
- [x] Plugin names validated (no path separators: `.`, `/`, `\`)
- [x] Download size limits enforced (100MB hard limit with io.LimitReader)
- [x] HTTP status checked (returns error on non-200 responses)
- [x] Config file paths user-controllable via `--config` flag
- [x] No hardcoded secrets or credentials
- [x] No eval/exec of untrusted input (plugins require explicit installation, not auto-executed)
- [ ] Plugin signature verification (future enhancement)
- [ ] Encrypted config storage (future enhancement)
- [ ] Rate limiting on operations (future enhancement)

## Refactoring Guidelines

### When to Extract
Extract when a function exceeds 30 lines or handles multiple concerns:
- One responsibility per function
- Break command handlers into business logic + display
- Extract repeated patterns into helper functions

### Avoid Premature Abstractions
Don't introduce interfaces until there are 2+ implementations:
- ✅ Keep functions concrete until interface clearly emerges
- ✅ Keep tasks table schema static until new field needed
- ✅ Keep command tree flat until 10+ subcommands

## Documentation Generation

### Auto-Generated Docs
Run to generate Markdown CLI documentation:
```bash
go run scripts/gen_docs.go
```

**Requirements**:
- RootCmd must be exported from cmd/root.go
- All commands registered in init() before execution
- Help text clear and concise

## Version Management

- **Module**: task-cli
- **Go Version**: 1.22.2+
- **Semantic Versioning**: Applied to releases only
- **Dependencies**: Pinned in go.mod, managed by `go get -u`

## Continuous Improvement

### Code Review Focus
- Is error handling complete?
- Are inputs validated?
- Are SQL queries parameterized?
- Does comment explain non-obvious logic?
- Are variable names descriptive?

### Refactoring Opportunities
- Combine similar command handlers
- Extract validation logic into named functions
- Add pagination to task list command
- Consider task filtering/search

## Related Documentation

- **project-overview-pdr.md** - Product vision and requirements
- **codebase-summary.md** - Module descriptions and dependencies
- **.claude/rules/development-rules.md** - Project-wide standards
