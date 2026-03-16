#!/usr/bin/env bash
set -euo pipefail

REPO="open-runtime/runtime_ci_tooling"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"

# Detect OS
case "$(uname -s)" in
  Darwin) OS="darwin" ;;
  Linux)  OS="linux" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

# Detect arch
case "$(uname -m)" in
  x86_64|amd64)   ARCH="x64" ;;
  aarch64|arm64)   ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

BINARY="manage_cicd-${OS}-${ARCH}"
[ "$OS" = "windows" ] && BINARY="${BINARY}.exe"

# Get latest version
VERSION="${VERSION:-$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)}"

if [ -z "$VERSION" ]; then
  echo "Error: Could not determine latest version" >&2
  exit 1
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY}"

echo "Installing manage_cicd ${VERSION} (${OS}-${ARCH})..."
mkdir -p "$INSTALL_DIR"

if command -v curl &>/dev/null; then
  curl -fsSL "$DOWNLOAD_URL" -o "${INSTALL_DIR}/manage_cicd"
elif command -v wget &>/dev/null; then
  wget -q "$DOWNLOAD_URL" -O "${INSTALL_DIR}/manage_cicd"
else
  echo "Error: curl or wget required" >&2; exit 1
fi

chmod +x "${INSTALL_DIR}/manage_cicd"
echo "Installed to ${INSTALL_DIR}/manage_cicd"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${INSTALL_DIR}$"; then
  echo ""
  echo "Add to your PATH:"
  echo "  export PATH=\"\$PATH:${INSTALL_DIR}\""
fi
