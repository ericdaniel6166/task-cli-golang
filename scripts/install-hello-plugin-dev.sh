#!/bin/bash
set -e

# Helper functions
info()    { echo "[INFO] $1"; }
success() { echo "[OK] $1"; }
error()   { echo "[ERROR] $1"; exit 1; }

# Check sudo is available
command -v sudo >/dev/null 2>&1 || error "sudo not available"

# Check source file exists and is valid
[ -f ./task-cli-hello-dev ] || error "task-cli-hello-dev not found in current directory"
[ -x ./task-cli-hello-dev ] || error "task-cli-hello-dev is not executable"
[ -s ./task-cli-hello-dev ] || error "task-cli-hello-dev is empty"

# Check if already installed
if [ -f /usr/local/bin/task-cli-hello-dev ]; then
    info "task-cli-hello-dev already installed at /usr/local/bin/task-cli-hello-dev"
    info "Verifying existing installation..."
    /usr/local/bin/task-cli-hello-dev >/dev/null 2>&1 || error "Existing installation verification failed"
    success "Installation already complete!"
    exit 0
fi

# Install plugin
info "Installing task-cli-hello-dev plugin..."
sudo cp ./task-cli-hello-dev /usr/local/bin/task-cli-hello-dev || error "Copy failed"
sudo chmod +x /usr/local/bin/task-cli-hello-dev
success "Installed to /usr/local/bin/task-cli-hello-dev"

# Verify installation using absolute path
info "Verifying installation..."
/usr/local/bin/task-cli-hello-dev >/dev/null 2>&1 || error "Verification failed"
success "Installation complete!"
