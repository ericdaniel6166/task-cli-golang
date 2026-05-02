# task-cli

An educational, lightweight, and cross-platform task management CLI written in pure Go. Manage tasks directly from your terminal with full CRUD operations, a flexible plugin system, and zero external dependencies.

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

#### Quick Install (Recommended)

**Linux/macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install-windows.ps1 | iex
```

The install script will:
- Auto-detect your OS and architecture (amd64/arm64)
- Download the latest release from GitHub
- Verify checksums for security
- Install to the appropriate location
- Set up PATH if needed

#### Platform-Specific Install

**Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install-linux.sh | bash
```

**macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install-macos.sh | bash
```

**Windows:**
```powershell
irm https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/install-windows.ps1 | iex
```

#### From Source

```bash
go install github.com/ericdaniel6166/task-cli-golang@latest
```

#### Manual Installation

Download the latest binary for your platform from [releases](https://github.com/ericdaniel6166/task-cli-golang/releases):

**Linux/macOS:**
```bash
# Extract and install
tar -xzf task-cli_v*_linux_amd64.tar.gz
sudo mv task-cli /usr/local/bin/
```

**Windows:**
```powershell
# Extract task-cli.exe from the .zip file and add to your PATH
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

Set `TASK_CLI_DATA_DIR` to customize where tasks and plugins are stored:

```bash
export TASK_CLI_DATA_DIR=/var/lib/task-cli
task-cli task list
```

Default location: `~/.task-cli/` (contains `tasks.db` and `bin/` for plugins)

**Note**: The config file is always stored in your home directory as `~/.task-cli.yaml`, separate from `TASK_CLI_DATA_DIR`.

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

#### Hello Plugin (Example)

The repository includes `task-cli-hello`, a simple example plugin demonstrating the plugin system. Install it with:

```bash
./install-hello-plugin.sh
```

The script will:
- Verify prerequisites (sudo access, source file exists and is executable)
- Install to `/usr/local/bin/task-cli-hello`
- Set executable permissions
- Verify the installation

**Note:** `task-cli-hello` is intentionally committed as an example plugin to demonstrate the plugin architecture.

#### From URL

```bash
task-cli plugin install https://example.com/my-plugin.tar.gz my-plugin
```

#### Manual Installation

```bash
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

### Installation Issues

**Linux/macOS:**
- **Permission denied**: Use `sudo` or install to `~/.local/bin` by setting `INSTALL_DIR=~/.local/bin` before running the install script
- **Command not found after install**: Add install directory to PATH:
  ```bash
  export PATH="$PATH:/usr/local/bin"
  # Or for ~/.local/bin:
  export PATH="$PATH:$HOME/.local/bin"
  ```
- **Checksum verification failed**: Re-download, check network connection, or verify GitHub releases are accessible

**Windows:**
- **Execution policy error**: Run in PowerShell as Administrator:
  ```powershell
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```
- **Access denied**: Run PowerShell as Administrator
- **PATH not updated**: Restart your terminal or PowerShell session

### Runtime Issues

**Tasks not found:**
Ensure `TASK_CLI_DATA_DIR` is set correctly or use the default `~/.task-cli/`:

```bash
ls -la ~/.task-cli/tasks.db
```

**Plugin not discovered:**
Check if the plugin is in PATH:

```bash
ls -la ~/.task-cli/bin/
echo $PATH
which task-cli-{plugin-name}
```

**Database locked:**
SQLite uses WAL mode for concurrent access. If you see "database is locked":
- Ensure only one instance is running
- Wait a few seconds and retry
- Check for stale processes: `lsof ~/.task-cli/tasks.db` (Linux/macOS)

## Uninstallation

**Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/uninstall-linux.sh | bash

# Or to remove config and data:
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/uninstall-linux.sh | bash -s -- --purge
```

**macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/uninstall-macos.sh | bash

# Or to remove config and data:
curl -fsSL https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/uninstall-macos.sh | bash -s -- --purge
```

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/uninstall-windows.ps1 | iex

# Or to remove config and data:
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ericdaniel6166/task-cli-golang/main/scripts/uninstall-windows.ps1))) -Purge
```

**Manual Uninstall:**

Linux/macOS:
```bash
# Remove binary
which task-cli  # Find binary location
sudo rm /path/to/task-cli

# Remove config and data (if --purge used)
rm -rf ~/.task-cli
rm -f ~/.task-cli.yaml
```

Windows:
```powershell
# Remove binary
$binaryPath = (Get-Command task-cli).Source
Remove-Item $binaryPath -Force

# Remove config and data (if -Purge used)
Remove-Item "$env:USERPROFILE\.task-cli" -Recurse -Force
Remove-Item "$env:USERPROFILE\.task-cli.yaml" -Force
```

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

See [LICENSE](./LICENSE) file in repository.

## Support

- **Issues**: [GitHub Issues](https://github.com/ericdaniel6166/task-cli-golang/issues)
- **Contact**: Open an issue
