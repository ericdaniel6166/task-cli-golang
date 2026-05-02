# Task-CLI Codebase Summary

## Overview

Task-CLI is a 433-line Go CLI tool for task management built with Cobra and SQLite. The codebase prioritizes simplicity, cross-platform compatibility, and extensibility through a plugin architecture.

## Directory Structure

```
task-cli-golang/
├── main.go                          # Application entry point
├── cmd/
│   ├── root.go                      # Root command, plugin discovery logic
│   ├── task.go                      # CRUD commands (add, list, delete, update)
│   └── plugin_install.go            # Plugin installation with security checks
├── internal/
│   ├── database/db.go               # SQLite initialization and connection
│   ├── task/task.go                 # Task data model and CRUD operations
│   └── config/config.go             # Viper configuration initialization
├── scripts/
│   └── gen_docs.go                  # Auto-generates CLI documentation
├── .goreleaser.yaml                 # Cross-platform build configuration
├── go.mod / go.sum                  # Dependencies (Cobra, Viper, modernc.org/sqlite)
└── docs/                            # Documentation (this file, PDR, standards)
```

## Module Descriptions

### main.go (17 lines)
**Purpose**: Application bootstrap
- Initializes SQLite database
- Executes root command
- Exits with fatal error if database init fails

**Key Functions**:
- `main()` - DB init → Execute CLI

### cmd/root.go (54 lines)
**Purpose**: Root command definition and plugin discovery
- Defines root command with help text
- Implements kubectl-style plugin discovery
- Binds global flags (config, author)

**Key Components**:
- `RootCmd` - Root command definition (exported for doc generation)
- `Execute()` - Entry point that handles plugin discovery
- `invokePlugin(path, args)` - Shells out to discovered plugin
- Plugin naming convention: `task-cli-{name}`

**Plugin Discovery Logic**:
1. Check if first arg is known command (Cobra routing)
2. If not found, search PATH for `task-cli-{arg}`
3. If found, execute with remaining args
4. If not found, run root command (triggers help/error)

### cmd/task.go (103 lines)
**Purpose**: Task CRUD operations
- Four subcommands under `task` parent: add, list, delete, update

**Commands**:

| Command | Args | Flags | Behavior |
|---------|------|-------|----------|
| `task add [name]` | name (required) | `-p, --priority` (int, default 1) | INSERT task, confirm on stdout |
| `task list` | none | none | SELECT all, tabulate output, handle empty case |
| `task delete [id]` | id (required) | none | DELETE task, error if not found |
| `task update [id] [name]` | id, name (required) | `-p, --priority` (int, default 1) | UPDATE task, error if not found |

**Key Functions**:
- `addCmd` Run function calls `task.SaveTask()`
- `listCmd` Run function calls `task.GetAllTasks()`, formats with tabwriter
- `deleteCmd` Run function parses ID, calls `task.DeleteTask()`, validates rows affected
- `updateCmd` Run function parses ID, calls `task.UpdateTask()`, validates rows affected

### cmd/plugin_install.go (110 lines)
**Purpose**: Plugin installation with comprehensive security checks

**Command**: `plugin install [url] [name]`
- `url` - HTTPS URL to plugin binary
- `name` - Plugin name (prefix `task-cli-` added automatically)

**Validations**:
1. URL must be HTTPS (scheme enforcement)
2. Plugin name cannot contain `/`, `\`, or `..` (path traversal prevention)
3. HTTP response must be 200 OK (status validation)
4. Content-Length must be ≤ 100MB (pre-check)
5. Actual download limited to 100MB via `io.LimitReader` (during download)
6. Failed downloads cleaned up (partial file removal)

**Installation Logic**:
1. Create `~/.task-cli/bin/` directory
2. Download file with size limit
3. Save as `task-cli-{name}`
4. Set executable permissions (chmod 755)
5. Report success or detailed error

### internal/database/db.go (50 lines)
**Purpose**: SQLite database initialization and connection management

**Key Components**:
- `DB` - Global connection pool variable (exported)
- `InitDB()` - Called once from main.go
  1. Determine data directory (env var or `~/.task-cli`)
  2. Create directory if missing
  3. Open SQLite database (modernc.org/sqlite driver)
  4. Execute schema creation DDL
- `getDataDir()` - Resolve data directory with fallback chain

**Schema**:
```sql
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    priority INTEGER,
    author TEXT
);
```

**Design Notes**:
- Using IF NOT EXISTS allows idempotent init
- No migrations (schema is static)
- Auto-increment ensures unique IDs
- No constraints (name can be empty, priority can be any int)

### internal/task/task.go (66 lines)
**Purpose**: Task data model and CRUD business logic

**Data Model**:
```go
type Task struct {
    ID       int
    Name     string
    Priority int
    Author   string
}
```

**Functions**:

| Function | SQL | Returns | Errors |
|----------|-----|---------|--------|
| `SaveTask(name, priority, author)` | INSERT | error | DB error only |
| `GetAllTasks()` | SELECT * | []Task, error | DB error, scan error |
| `DeleteTask(id)` | DELETE | error | DB error, "not found" if 0 rows |
| `UpdateTask(id, name, priority)` | UPDATE | error | DB error, "not found" if 0 rows |

**Error Handling**:
- All functions return `error` as last return
- Row validation: `RowsAffected()` checked for delete/update
- Returns wrapped error: `fmt.Errorf("task %d not found", id)`

### internal/config/config.go (33 lines)
**Purpose**: Viper configuration initialization

**Config Loading Strategy** (in order):
1. Command-line flags (highest priority)
2. Environment variables (auto-bound via `viper.AutomaticEnv()`)
3. Config file (`--config` flag or default search paths)
4. Defaults (in Cobra flag definitions)

**Config Sources**:
- **File**: `~/.task-cli.yaml` or custom path
- **Env**: `TASK_CLI_*` prefix (matched to flag names)
- **Flags**: `--config`, `--author`, `--priority`

**InitConfig** returns a closure (Cobra pattern) for deferred initialization.

### scripts/gen_docs.go (14 lines)
**Purpose**: Auto-generates Markdown CLI documentation
- Uses Cobra's doc generation capability
- Exports RootCmd from cmd/root.go to access command tree
- Outputs to `./docs/` directory
- Run with: `go run scripts/gen_docs.go`

## Key Design Patterns

### Plugin Discovery
Implements kubectl-style plugin architecture without modifying core logic:
- Plugin lookup happens in Execute() before Cobra routing
- Unknown commands automatically trigger PATH search
- Plugin naming convention (`task-cli-*`) prevents conflicts
- Plugins inherit stdin/stdout/stderr from parent process

### Configuration Layering
Viper provides three-level config binding:
- **Code defaults**: In Cobra flag `.Flags().IntVarP(..., default: 1)`
- **File/env**: Loaded by `viper.ReadInConfig()` and `AutomaticEnv()`
- **Command-line**: Flag values override file/env via `viper.BindPFlag()`

### Error Handling
Consistent error-first return pattern:
- Database errors: returned as-is (DB layer)
- Validation errors: formatted with context (`fmt.Errorf`)
- User-facing: printed to stdout, no panic/fatal (except main.go)

### Database Access
Single global `DB` connection:
- Initialized once in main.go
- Shared across all cmd functions
- No connection pooling config (SQLite handles internally)
- All queries use parameterized queries (prevents SQL injection)

## Dependencies

| Package | Purpose | Version |
|---------|---------|---------|
| github.com/spf13/cobra | CLI framework | v1.8.1 |
| github.com/spf13/viper | Config management | v1.19.0 |
| modernc.org/sqlite | Pure-Go SQLite | v1.31.1 |

**Transitive Dependencies**: 16 total (see go.sum for full list)

## Build & Deployment

### Local Development
```bash
go run main.go task add "My Task"
go run main.go task list
```

### Cross-Platform Build
```bash
go build -o task-cli main.go          # Single binary
# Or use GoReleaser for multi-arch:
goreleaser release --snapshot
```

### Build Configuration (.goreleaser.yaml)
- **Environments**: `CGO_ENABLED=0` (pure Go)
- **Platforms**: linux, windows, darwin
- **Architectures**: amd64, arm64
- **Artifacts**: tar.gz archives per combination

## Code Quality Characteristics

### Simplicity
- No interfaces (concrete types)
- No goroutines (synchronous I/O)
- Linear function flows
- Minimal error wrapping

### Readability
- Short functions (max 30 lines)
- Clear variable names (no abbreviations)
- Exported types/functions for doc generation
- Comments on non-obvious logic

### Maintainability
- Separation of concerns (cmd vs internal)
- Stateless functions except DB operations
- No global state except DB connection
- Easy to add new commands (follow task.go pattern)

### Testing Surface
- Public API: CLI flags and commands
- Internal API: Exported Task functions
- Database: SQL queries (testable with sqlite in-memory)

## Known Issues & TODOs

- **No automated tests**: All testing is manual CLI invocation
- **No input validation**: Task name can be empty string
- **No task filtering**: list command returns all tasks
- **No concurrency locks**: Multiple writers may contend
- **No connection pooling**: Single global DB instance
- **No CLI rate limiting**: Plugin installs unlimited

## Extension Points

### Adding New Commands
1. Create new command struct in `cmd/new_feature.go`
2. Define `*cobra.Command` with Use/Short/Run
3. Call init() to register with RootCmd or parent
4. Implement helper functions in `internal/` as needed

### Adding Plugin Features
1. Plugin executable runs with user privileges
2. Plugin can read/write `~/.task-cli/` directory
3. Plugin receives args from command line
4. Plugin outputs to stdout/stderr
5. Plugin exit code propagates to parent shell

### Database Schema Changes
1. Add new columns to CREATE TABLE IF NOT EXISTS
2. Backfill data in migration script (manual, deferred)
3. Update Task struct in internal/task/task.go
4. Update CRUD functions to handle new fields

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| task add | O(1) | Single INSERT |
| task list | O(n) | Full table scan |
| task delete | O(1) | Single DELETE by ID |
| task update | O(1) | Single UPDATE by ID |

**Scalability**: Comfortable to ~10k tasks (full load into memory). Beyond that, add pagination or filtering.

## Security Considerations

### Implemented
- HTTPS-only plugin downloads
- Path traversal prevention in plugin names
- Download size limits (100MB)
- HTTP status validation
- SQL injection prevention (parameterized queries)

### Not Implemented
- Plugin signature verification
- Encrypted config storage
- Permission checks (user home access assumed)
- Rate limiting on operations
- Input length limits (except downloads)

## Module Dependency Graph

```
main.go
  └─> cmd.Execute()
       └─> cmd.RootCmd (plugin discovery)
            └─> cmd.taskCmd (add, list, delete, update)
                 └─> task.SaveTask/GetAllTasks/DeleteTask/UpdateTask
                      └─> database.DB
cmd.pluginCmd (plugin install)
  └─> http.Get() + os.Create()
  
internal/config.InitConfig()
  └─> viper.ReadInConfig()
```

## File Size Reference

| File | Lines | Purpose |
|------|-------|---------|
| main.go | 17 | Entry point |
| cmd/root.go | 54 | Root command |
| cmd/task.go | 103 | CRUD commands |
| cmd/plugin_install.go | 110 | Plugin installation |
| internal/database/db.go | 50 | DB init |
| internal/task/task.go | 66 | Business logic |
| internal/config/config.go | 33 | Config loading |
| **Total** | **433** | |

## Getting Started for Developers

1. **Clone & Setup**: `git clone ... && cd task-cli-golang && go mod download`
2. **Build**: `go build -o task-cli main.go`
3. **Run**: `./task-cli task add "Example" && ./task-cli task list`
4. **Modify**: Edit cmd/ and internal/ files, rerun go build
5. **Test**: Manual CLI testing (no test suite yet)
6. **Distribute**: Run `goreleaser release --snapshot` for multi-platform builds

## Related Documentation

- **project-overview-pdr.md** - Product requirements, vision, success criteria
- **code-standards.md** - Go coding conventions, patterns, guidelines
- **.claude/rules/** - Project development workflows and standards
