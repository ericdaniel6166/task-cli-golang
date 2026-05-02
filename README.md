# task-cli

A lightweight, cross-platform task management CLI written in pure Go. Manage tasks directly from your terminal with full CRUD operations, a flexible plugin system, and zero external dependencies.

## Features

- **Full CRUD Operations**: Create, read, update, and delete tasks with simple commands
- **Priority Management**: Assign and modify task priority levels (1-5)
- **SQLite Persistence**: Tasks stored in a local SQLite database (pure Go, no CGO required)
- **Plugin Architecture**: Extend functionality with kubectl-style plugins from PATH
- **Cross-Platform**: Builds for Linux, Windows, and macOS on amd64 and arm64
- **Configuration**: YAML config files + environment variables + command-line flags
- **Single Binary**: Minimal ~8-12MB, zero runtime dependencies

## Quick Start

### Installation

Download the latest binary for your platform from [releases](https://github.com/your-org/task-cli-golang/releases):

```bash
# Linux/macOS
tar -xzf task-cli_linux_amd64.tar.gz
chmod +x task-cli
sudo mv task-cli /usr/local/bin/

# Windows (add to PATH)
# Extract task-cli.exe and add to your PATH
```

Or build from source:

```bash
git clone https://github.com/your-org/task-cli-golang.git
cd task-cli-golang
go build -o task-cli main.go
```

### Basic Usage

```bash
# Add a new task
task-cli task add "Buy groceries" --priority 3

# List all tasks
task-cli task list

# Update a task
task-cli task update 1 "Buy groceries and cook" --priority 2

# Delete a task
task-cli task delete 1
```

## Commands

### task add
Create a new task.

```bash
task-cli task add [name] --priority [1-5] --author [name]
```

**Flags:**
- `--priority, -p` (int): Task priority level, 1-5 (default: 1)
- `--author, -a` (string): Author name for the task (default: "Unknown")
- `--config` (string): Path to YAML config file

**Example:**
```bash
task-cli task add "Review code" --priority 4 --author "alice"
```

### task list
Display all tasks in a table.

```bash
task-cli task list
```

**Output:**
```
ID | NAME          | PRIORITY | AUTHOR
1  | Buy groceries | 3        | Unknown
2  | Review code   | 4        | alice
```

### task update
Modify an existing task.

```bash
task-cli task update [id] [new-name] --priority [1-5]
```

**Flags:**
- `--priority, -p` (int): New priority level (optional)

**Example:**
```bash
task-cli task update 1 "Buy groceries and cook" --priority 2
```

### task delete
Remove a task by ID.

```bash
task-cli task delete [id]
```

**Example:**
```bash
task-cli task delete 1
```

### plugin install
Download and install a plugin from an HTTPS URL.

```bash
task-cli plugin install [https-url] [plugin-name]
```

**Flags:** None

**Details:**
- URL must use HTTPS (security requirement)
- Plugin name cannot contain `/`, `\`, or `..` (path traversal prevention)
- Maximum download size: 100MB
- Plugin installed to `~/.task-cli/bin/task-cli-{name}` with executable permissions

**Example:**
```bash
task-cli plugin install https://example.com/plugins/my-plugin.tar.gz my-plugin
```

## Configuration

### Environment Variables

Set `TASK_CLI_DATA_DIR` to customize where tasks are stored:

```bash
export TASK_CLI_DATA_DIR=/var/lib/task-cli
task-cli task list
```

Default location: `~/.task-cli/tasks.db`

### YAML Config File

Create `~/.task-cli.yaml`:

```yaml
author: "alice"
priority: 2
```

Or specify a custom path:

```bash
task-cli task add "My task" --config /etc/task-cli.yaml
```

### Configuration Priority

Command-line flags override environment variables, which override config files:

```
Command-line flags > Environment variables > Config file > Defaults
```

## Plugin System

Extend task-cli with custom commands using the kubectl plugin pattern.

### Plugin Basics

1. Create an executable program named `task-cli-{plugin-name}`
2. Place it in your PATH (e.g., `~/.local/bin/`)
3. Call it directly: `task-cli {plugin-name} [args]`

### Installation

```bash
# From URL
task-cli plugin install https://example.com/my-plugin.tar.gz my-plugin

# Manual
chmod +x my-plugin
mkdir -p ~/.task-cli/bin
mv my-plugin ~/.task-cli/bin/task-cli-my-plugin
export PATH="$HOME/.task-cli/bin:$PATH"
```

### Example Plugin

A simple shell script plugin at `~/.task-cli/bin/task-cli-stats`:

```bash
#!/bin/bash
echo "Task Statistics"
echo "Total tasks: $(task-cli task list | tail -n +2 | wc -l)"
```

## Build & Development

### Prerequisites

- Go 1.22.2 or later
- No CGO required (pure Go SQLite)

### Building

```bash
# Single binary
go build -o task-cli main.go

# Cross-platform (requires GoReleaser)
goreleaser release --snapshot
```

### Project Structure

```
task-cli-golang/
├── main.go                        # Entry point
├── cmd/
│   ├── root.go                    # Root command & plugin discovery
│   ├── task.go                    # Task CRUD commands
│   └── plugin_install.go          # Plugin installation
├── internal/
│   ├── database/db.go             # SQLite initialization
│   ├── task/task.go               # Task model & operations
│   └── config/config.go           # Viper configuration
├── .goreleaser.yaml               # Build configuration
├── go.mod / go.sum                # Dependencies
└── docs/                          # Documentation
```

### Running Locally

```bash
go run main.go task add "Test task"
go run main.go task list
```

## Architecture

### Database

Tasks are stored in SQLite with a simple schema:

```sql
CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    priority INTEGER,
    author TEXT
);
```

Database location: `$TASK_CLI_DATA_DIR/tasks.db` (default: `~/.task-cli/tasks.db`)

### Command Structure

- **Root Command**: `task-cli` (plugin discovery, help)
- **Task Group**: `task add|list|delete|update` (CRUD operations)
- **Plugin Group**: `plugin install` (plugin management)
- **Plugin Invocation**: `task-cli {plugin-name} [args]` (kubectl-style)

### Security

- **HTTPS-only downloads**: Plugin installation enforces HTTPS
- **Path traversal prevention**: Plugin names validated for `..`, `/`, `\`
- **Size limits**: 100MB maximum download
- **SQL injection prevention**: Parameterized queries throughout
- **No auto-execution**: Plugins require explicit installation

## Troubleshooting

### Tasks not found
Ensure `TASK_CLI_DATA_DIR` is set correctly or use the default `~/.task-cli/`:

```bash
ls -la ~/.task-cli/tasks.db
```

### Plugin not discovered
Check if the plugin is in PATH:

```bash
ls -la ~/.task-cli/bin/
echo $PATH
which task-cli-{plugin-name}
```

### Database locked
SQLite uses WAL mode for concurrent access. If you see "database is locked":
- Ensure only one instance is running
- Wait a few seconds and retry
- Check for stale processes: `lsof ~/.task-cli/tasks.db`

## Contributing

See [docs/code-standards.md](./docs/code-standards.md) for development guidelines and conventions.

Contributions welcome! Please:

1. Follow Go naming conventions and patterns in `docs/code-standards.md`
2. Keep code under 200 lines per file (split into modules if needed)
3. Test locally before submitting: `go build && ./task-cli task list`
4. Use clear commit messages

## Documentation

- [Product Overview & Requirements](./docs/project-overview-pdr.md) - Vision, features, success criteria
- [Codebase Architecture](./docs/codebase-summary.md) - Detailed module descriptions
- [Code Standards & Conventions](./docs/code-standards.md) - Go style guide and patterns

## License

See LICENSE file in repository.

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/task-cli-golang/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/task-cli-golang/discussions)
- **Contact**: Open an issue or discussion
