#!/bin/bash
set -e

# Helper functions
info()    { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
error()   { echo "[ERROR] $1"; exit 1; }

# Cleanup on error only
cleanup() { [ -f task-cli ] && rm -f task-cli; }
trap cleanup ERR

# Check sudo is available
command -v sudo >/dev/null 2>&1 || error "sudo not available"

# Check Go is installed and version
command -v go >/dev/null 2>&1 || error "Go not installed"
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
info "Go version: $GO_VERSION"

# Verify Go >= 1.22 (handles versions like 1.100+)
if ! awk -v ver="$GO_VERSION" 'BEGIN {
    split(ver, v, ".");
    major = v[1]; minor = v[2];
    if (major < 1 || (major == 1 && minor < 22)) exit 1;
}'; then
    error "Go 1.22+ required, found $GO_VERSION"
fi

# Check if already installed
if [ -f /usr/local/bin/task-cli ]; then
    info "task-cli already installed at /usr/local/bin/task-cli"
    info "Verifying existing installation..."
    /usr/local/bin/task-cli --help >/dev/null 2>&1 || error "Existing installation verification failed"
    success "Installation already complete!"
    exit 0
fi

# Build the binary
info "Building task-cli..."
go build -o task-cli main.go || error "Build failed"
success "Build complete"

# Install to /usr/local/bin
info "Installing to /usr/local/bin..."
sudo mv task-cli /usr/local/bin/task-cli || error "Move failed"
sudo chmod +x /usr/local/bin/task-cli
success "Installed to /usr/local/bin/task-cli"

# Verify installation using absolute path
info "Verifying installation..."
/usr/local/bin/task-cli --help >/dev/null 2>&1 || error "Verification failed"
success "Installation complete!"
trap - ERR  # Disable cleanup after successful install
