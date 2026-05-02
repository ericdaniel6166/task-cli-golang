# Task-CLI Product Development Requirements

## Executive Summary

Task-CLI is a professional command-line task manager written in Go. It provides a lightweight, extensible interface for managing tasks with full CRUD operations, plugin architecture, and cross-platform support. The implementation prioritizes simplicity, portability (pure Go, no CGO), and developer experience through a familiar kubectl-style CLI interface.

## Product Vision

Deliver a zero-dependency task management CLI that serves as a foundation for task automation and extensibility. Users can:
- Manage tasks directly from the terminal with intuitive commands
- Extend functionality through a plugin system
- Configure behavior via environment variables and YAML config
- Work seamlessly across Linux, Windows, and macOS (both amd64 and arm64)

## Core Functional Requirements

### CRUD Operations
- **Create**: `task add [name] --priority [1-5]` adds new tasks with optional priority
- **Read**: `task list` displays all tasks in tabular format with ID, name, priority, author
- **Update**: `task update [id] [name] --priority [1-5]` modifies task name and/or priority
- **Delete**: `task delete [id]` removes task by ID with validation

### Configuration
- YAML config file support via `--config` flag or default location (`~/.task-cli.yaml`)
- Environment variable support (auto-bound via Viper)
- `--author` flag for task ownership (persists across commands)
- `TASK_CLI_DATA_DIR` environment variable to customize storage location

### Plugin System
- `plugin install [url] [name]` downloads plugins from HTTPS URLs
- Kubectl-style invocation: `task-cli [plugin-name]` discovers and runs plugins from PATH
- Plugins installed to `~/.task-cli/bin/` with `task-cli-` prefix convention

## Core Non-Functional Requirements

### Performance
- Sub-millisecond task listing for typical datasets (< 1000 tasks)
- Plugin discovery via PATH lookup (no central registry)
- In-process SQLite (modernc.org) eliminates process overhead

### Reliability
- All task operations validated (ID existence checks, type conversions)
- Graceful error handling with clear error messages
- Database schema created automatically on first run
- Supports concurrent task access (SQLite default WAL mode)

### Security
- HTTPS-only enforcement for plugin downloads
- Plugin name validation prevents path traversal (`..`, `/`, `\`)
- 100MB download size limit prevents disk exhaustion
- HTTP status validation prevents silent failures
- No automatic execution of downloaded binaries (chmod 755 only)

### Portability
- Pure Go implementation (modernc.org/sqlite) eliminates CGO dependency
- Cross-platform builds: Linux, Windows, Darwin (amd64, arm64)
- Single binary distribution via GoReleaser
- Data stored in user home directory (OS-agnostic)

## Technical Architecture

### Database
- **SQLite via modernc.org/sqlite** (pure Go, no C compiler required)
- Schema: Single `tasks` table with auto-incrementing ID
- Location: `~/.task-cli/tasks.db` (or `$TASK_CLI_DATA_DIR/tasks.db`)
- No migrations required (schema created on init)

### CLI Framework
- **Cobra** for command tree, flag parsing, and help generation
- **Viper** for config file + environment variable binding
- Nested command structure: `task-cli task [add|list|delete|update]`
- Plugin discovery integrated into root command execution

### Module Structure
```
task-cli/
├── main.go                          # Entry point, DB initialization
├── cmd/
│   ├── root.go                      # Root command, plugin discovery
│   ├── task.go                      # task add/list/delete/update
│   └── plugin_install.go            # plugin install
├── internal/
│   ├── database/db.go               # SQLite init, connection pool
│   ├── task/task.go                 # CRUD logic
│   └── config/config.go             # Viper configuration
├── scripts/gen_docs.go              # Cobra doc generation
└── .goreleaser.yaml                 # Multi-platform build config
```

### API Contracts

#### Command: task add
```
Usage: task-cli task add [name]
Flags:
  -p, --priority int  Task priority level (default: 1)
  -a, --author string Author for tasks (default: "Unknown")
  --config string     Path to YAML config file
```
Returns: "Task '{name}' added." on success

#### Command: task list
```
Usage: task-cli task list
Output: Tabular format (ID | NAME | PRIORITY | AUTHOR)
```
Returns: "No tasks found." if empty

#### Command: task delete
```
Usage: task-cli task delete [id]
Error if: Task ID not found
```
Returns: "Task {id} deleted." on success

#### Command: task update
```
Usage: task-cli task update [id] [name]
Flags:
  -p, --priority int  New priority level
Error if: Task ID not found
```
Returns: "Task {id} updated." on success

#### Command: plugin install
```
Usage: task-cli plugin install [url] [name]
Validations:
  - URL must be HTTPS
  - Plugin name cannot contain: / \ ..
  - Downloaded file max 100MB
  - HTTP status must be 200 OK
```
Returns: "Installed {full-name} to {bin-path}" on success

## Implementation Decisions

### Why modernc.org/sqlite?
Eliminates CGO dependency, allowing true cross-compilation (no C compiler needed) and zero external runtime dependencies. Standard `database/sql` interface maintains compatibility with existing Go patterns.

### Why Cobra + Viper?
Industry-standard for Go CLIs, kubectl-compatible, enables plugin discovery without modifying core logic. Configuration layering (file → env → flags) matches operator expectations.

### Why single binary?
GoReleaser produces minimal, portable artifacts. No runtime dependencies, configuration files, or installation scripts. Users download and run immediately.

### Why home directory storage?
Non-privileged operation (no `sudo`), respects user-level data isolation, works across all platforms, survives application reinstalls.

## Success Criteria

- [x] CRUD operations execute without errors
- [x] Plugin discovery works when plugin exists in PATH
- [x] Configuration loads from YAML and environment variables
- [x] Builds cross-platform with zero CGO dependencies
- [x] All command inputs validated (IDs, URLs, names)
- [x] Error messages are actionable and specific
- [x] Database persists between invocations
- [x] Plugin installation enforces HTTPS and size limits

## Known Limitations

- **No concurrency control**: Multiple simultaneous writes may cause lock contention (acceptable for MVP)
- **In-memory task list**: `GetAllTasks()` loads all records; scales to ~10k tasks comfortably
- **No task status field**: Priority is the only mutable attribute (extensible via schema)
- **No plugin sandboxing**: Downloaded plugins run with user privileges
- **No built-in update mechanism**: Plugin updates require manual reinstallation

## Future Enhancements

- Task status field (pending, in-progress, completed, archived)
- Due dates and recurring tasks
- Task categories/tags
- Built-in update checker for plugins
- TOML config support alongside YAML
- Shell completion generation (Cobra-native)
- HTTP API mode (server flag)
- Database export/import utilities

## Version & Compatibility

- **Go Version**: 1.22.2 or later
- **Module**: task-cli v0.1.0 (initial release)
- **Dependencies**: Cobra, Viper, modernc.org/sqlite (see go.mod)
- **Breaking Changes**: None (initial release)

## Deployment & Distribution

- **Build Tool**: GoReleaser v2
- **Artifacts**: Tarball archives per platform/arch
- **Installation**: Download binary, add to PATH, run directly
- **Configuration**: Optional YAML file, environment variables, command flags
- **Testing**: Manual CLI testing on all platforms (automated tests deferred)

## Project Metrics

- **Codebase**: 433 lines of Go (before comments/tests)
- **Modules**: 3 packages (cmd, database, config, task)
- **Dependencies**: 16 external (Cobra, Viper, modernc.org/sqlite + transitive)
- **Build Time**: ~3s cross-platform (8 combinations)
- **Binary Size**: ~8-12MB per platform (debug symbols included)

## Rollout Plan

1. **Beta**: Publish binary builds to releases page
2. **Early Access**: Solicit feedback on command UX and plugin system
3. **Stable**: Lock API, document plugin interface, promote to users
4. **Operations**: Monitor error logs, collect feature requests

## Owner & Contact

- **Implementation**: Eric Nguyen
- **Repository**: task-cli-golang
- **Issue Tracking**: GitHub Issues
