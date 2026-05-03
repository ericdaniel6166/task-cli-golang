#!/bin/bash
set -e
shopt -s nullglob

# Helper functions
info()    { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
warn()    { echo "[WARN] $1"; }
error()   { echo "[ERROR] $1"; exit 1; }

# Safety checks
[ -n "$HOME" ] || error "HOME not set"
command -v sudo >/dev/null 2>&1 || error "sudo not available"

# Resolve real user's home directory (handles sudo, cross-platform)
if [ -n "$SUDO_USER" ]; then
    if command -v getent >/dev/null 2>&1; then
        # Linux
        REAL_HOME=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
        [ -n "$REAL_HOME" ] || error "User '$SUDO_USER' not found in passwd database"
    elif [ "$(uname)" = "Darwin" ]; then
        # macOS
        REAL_HOME=$(dscl . -read /Users/"$SUDO_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
        [ -n "$REAL_HOME" ] || error "User '$SUDO_USER' not found in directory service"
    else
        # Fallback for other UNIX
        REAL_HOME=$(eval echo ~"$SUDO_USER" 2>/dev/null)
        [ -n "$REAL_HOME" ] || error "Could not resolve home directory for user '$SUDO_USER'"
    fi
else
    REAL_HOME="$HOME"
fi
[ -n "$REAL_HOME" ] || error "Could not determine user home directory"

# Remove binary
info "Removing /usr/local/bin/task-cli..."
if [ -f /usr/local/bin/task-cli ]; then
    sudo rm -f /usr/local/bin/task-cli
    success "Binary removed"
else
    warn "Binary not found (already removed?)"
fi

# Remove plugins
info "Removing task-cli plugins..."
plugin_count=0
for plugin in /usr/local/bin/task-cli-*; do
    if [ -f "$plugin" ]; then
        if sudo rm "$plugin" 2>/dev/null; then
            success "Removed $(basename "$plugin")"
            plugin_count=$((plugin_count + 1))
        else
            warn "Failed to remove $(basename "$plugin")"
        fi
    fi
done
if [ $plugin_count -eq 0 ]; then
    info "No plugins found"
fi

# Remove data directory
info "Removing $REAL_HOME/.task-cli/..."
if [ -d "$REAL_HOME/.task-cli" ]; then
    rm -rf "$REAL_HOME/.task-cli"
    success "Data directory removed"
else
    warn "Data directory not found"
fi

# Remove config file
info "Removing $REAL_HOME/.task-cli.yaml..."
if [ -f "$REAL_HOME/.task-cli.yaml" ]; then
    rm -f "$REAL_HOME/.task-cli.yaml"
    success "Config file removed"
else
    warn "Config file not found"
fi

# Verify clean removal
info "Verifying clean removal..."
remaining=$(find /usr/local/bin -name "task-cli*" 2>/dev/null | wc -l)
if [ "$remaining" -gt 0 ]; then
    echo "[ERROR] task-cli files still present in /usr/local/bin:"
    find /usr/local/bin -name "task-cli*"
    exit 1
fi

echo ""
echo "========================================"
echo "           Clean Success!              "
echo "========================================"
