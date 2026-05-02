#!/usr/bin/env bash
set -euo pipefail

REPO="ericdaniel6166/task-cli-golang"
BRANCH="${BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/scripts"

detect_os() {
  local os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    linux*) echo "linux" ;;
    darwin*) echo "macos" ;;
    mingw*|msys*|cygwin*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

main() {
  local os=$(detect_os)
  local tmpscript=$(mktemp)
  trap "rm -f $tmpscript" EXIT

  case "$os" in
    linux)
      echo "Detected Linux, running install-linux.sh..."
      curl -fsSL "${BASE_URL}/install-linux.sh" -o "$tmpscript"
      bash "$tmpscript"
      ;;
    macos)
      echo "Detected macOS, running install-macos.sh..."
      curl -fsSL "${BASE_URL}/install-macos.sh" -o "$tmpscript"
      bash "$tmpscript"
      ;;
    windows)
      echo "Detected Windows (Git Bash/MSYS2/Cygwin)"
      echo "Please use PowerShell instead:"
      echo ""
      echo "  irm https://raw.githubusercontent.com/${REPO}/${BRANCH}/scripts/install-windows.ps1 | iex"
      exit 1
      ;;
    *)
      echo "Unknown OS: $(uname -s)"
      echo "Supported: Linux, macOS, Windows"
      exit 1
      ;;
  esac
}

main "$@"
