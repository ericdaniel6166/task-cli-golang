#!/usr/bin/env bash
set -euo pipefail

BINARY_NAME="task-cli"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/task-cli"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/task-cli"

# Find binary location
find_binary() {
  command -v "$BINARY_NAME" 2>/dev/null || echo ""
}

main() {
  local binary_path=$(find_binary)
  local remove_data="${1:-}"

  if [[ -z "$binary_path" ]]; then
    echo "${BINARY_NAME} not found in PATH"
    exit 0
  fi

  echo "Removing ${binary_path}..."

  if [[ -w "$(dirname "$binary_path")" ]]; then
    rm -f "$binary_path"
  else
    sudo rm -f "$binary_path"
  fi

  echo "Binary removed."

  if [[ "$remove_data" == "--purge" ]]; then
    echo "Removing config and data..."
    rm -rf "$CONFIG_DIR" "$DATA_DIR"
    echo "Config and data removed."
  else
    echo "Config/data preserved. Use --purge to remove."
  fi

  echo "Uninstall complete."
}

main "$@"
