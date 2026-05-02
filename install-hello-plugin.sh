#!/bin/bash
set -e

# Helper functions
info()    { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
error()   { echo "[ERROR] $1"; exit 1; }

# Check sudo is available
command -v sudo >/dev/null 2>&1 || error "sudo not available"

# Check source file exists and is valid
[ -f ./task-cli-hello ] || error "task-cli-hello not found in current directory"
[ -x ./task-cli-hello ] || error "task-cli-hello is not executable"
[ -s ./task-cli-hello ] || error "task-cli-hello is empty"

# Check if already installed
if [ -f /usr/local/bin/task-cli-hello ]; then
    info "task-cli-hello already installed at /usr/local/bin/task-cli-hello"
    info "Verifying existing installation..."
    /usr/local/bin/task-cli-hello >/dev/null 2>&1 || error "Existing installation verification failed"
    success "Installation already complete!"
    exit 0
fi

# Install plugin
info "Installing task-cli-hello plugin..."
sudo cp ./task-cli-hello /usr/local/bin/task-cli-hello || error "Copy failed"
sudo chmod +x /usr/local/bin/task-cli-hello
success "Installed to /usr/local/bin/task-cli-hello"

# Verify installation using absolute path
info "Verifying installation..."
/usr/local/bin/task-cli-hello >/dev/null 2>&1 || error "Verification failed"
success "Installation complete!"
