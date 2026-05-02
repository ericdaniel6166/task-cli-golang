#!/bin/bash
set -e

# Helper functions
info()    { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
error()   { echo "[ERROR] $1"; exit 1; }

# Cleanup on failure
trap 'rm -f task-cli' EXIT

# Check sudo is available
command -v sudo >/dev/null 2>&1 || error "sudo not available"

# Check Go is installed and version
command -v go >/dev/null 2>&1 || error "Go not installed"
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
info "Go version: $GO_VERSION"

# Verify Go >= 1.22
GO_MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
GO_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)
if [ "$GO_MAJOR" -lt 1 ] || { [ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 22 ]; }; then
    error "Go 1.22+ required, found $GO_VERSION"
fi

# Check if already installed
if [ -f /usr/local/bin/task-cli ]; then
    info "task-cli already installed at /usr/local/bin/task-cli"
    read -p "Overwrite existing installation? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Installation cancelled"
        exit 0
    fi
fi

# Build the binary
info "Building task-cli..."
go build -o task-cli . || error "Build failed"
success "Build complete"

# Install to /usr/local/bin
info "Installing to /usr/local/bin..."
sudo mv task-cli /usr/local/bin/task-cli || error "Move failed"
sudo chmod +x /usr/local/bin/task-cli
success "Installed to /usr/local/bin/task-cli"

# Verify installation
info "Verifying installation..."
task-cli --version || error "Verification failed"
success "Installation complete!"
