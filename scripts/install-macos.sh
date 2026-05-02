#!/usr/bin/env bash
set -euo pipefail

REPO="ericdaniel6166/task-cli-golang"
BINARY_NAME="task-cli"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Detect architecture (Intel vs Apple Silicon)
detect_arch() {
  local arch=$(uname -m)
  case "$arch" in
    x86_64) echo "amd64" ;;
    arm64) echo "arm64" ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac
}

# Get latest version from GitHub
get_latest_version() {
  local response
  response=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest") || {
    echo "Failed to fetch latest version. Set VERSION env var manually." >&2
    exit 1
  }

  # Validate JSON structure
  echo "$response" | grep -q '"tag_name"' || {
    echo "Invalid GitHub API response. You may be rate-limited." >&2
    echo "Set VERSION=vX.Y.Z and retry." >&2
    exit 1
  }

  echo "$response" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Main install
main() {
  local arch=$(detect_arch)
  local version="${VERSION:-$(get_latest_version)}"
  local os="darwin"
  local archive="${BINARY_NAME}_${version#v}_${os}_${arch}.tar.gz"
  local url="https://github.com/${REPO}/releases/download/${version}/${archive}"
  local checksums_url="https://github.com/${REPO}/releases/download/${version}/checksums.txt"

  echo "Installing ${BINARY_NAME} ${version} for macOS/${arch}..."

  local tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" EXIT

  # Download archive and checksums
  curl -fsSL -o "${tmpdir}/${archive}" "$url"
  curl -fsSL -o "${tmpdir}/checksums.txt" "$checksums_url"

  # Verify checksum (macOS uses shasum)
  cd "$tmpdir"
  grep -- "${archive}" checksums.txt | shasum -a 256 -c - || {
    echo "Checksum verification failed!" >&2
    exit 1
  }

  # Extract
  tar -xzf "${archive}"

  # Remove quarantine attribute (Gatekeeper)
  xattr -d com.apple.quarantine "${BINARY_NAME}" 2>/dev/null || true

  # Install binary
  if [[ "$INSTALL_DIR" == "/usr/local/bin" ]]; then
    # Create /usr/local/bin if needed (common on fresh macOS)
    sudo mkdir -p "$INSTALL_DIR"
    sudo install -m 755 "${BINARY_NAME}" "${INSTALL_DIR}/"
  else
    mkdir -p "$INSTALL_DIR"
    install -m 755 "${BINARY_NAME}" "${INSTALL_DIR}/"
  fi

  echo "Installed ${BINARY_NAME} to ${INSTALL_DIR}/${BINARY_NAME}"

  # Check PATH
  if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo ""
    echo "Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
  fi
}

main "$@"
