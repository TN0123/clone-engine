#!/bin/bash
# Digital Clone Maker — Install Script
# Usage: curl -fsSL https://tn0123.github.io/clone-engine/install.sh | bash

set -e

GITHUB_REPO="TN0123/clone-engine"
GITHUB_API="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
GITHUB_RELEASES="https://github.com/$GITHUB_REPO/releases/download"
ENGINE_DIR="$HOME/.clone-engine"
CONFIG_FILE="$ENGINE_DIR/config.json"

# ─── Colors ───────────────────────────────────────────────────────────────────
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Banner ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${MAGENTA}${BOLD}  ╔══════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}${BOLD}  ║       🧬  DIGITAL CLONE MAKER               ║${RESET}"
echo -e "${MAGENTA}${BOLD}  ╚══════════════════════════════════════════════╝${RESET}"
echo ""

# ─── Platform detection ───────────────────────────────────────────────────────

detect_platform() {
  local os arch

  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Darwin)
      case "$arch" in
        arm64)   echo "darwin-arm64" ;;
        x86_64)  echo "darwin-x86_64" ;;
        *)
          echo -e "${RED}  Error: Unsupported macOS architecture: $arch${RESET}" >&2
          exit 1
          ;;
      esac
      ;;
    Linux)
      case "$arch" in
        x86_64)  echo "linux-x86_64" ;;
        *)
          echo -e "${RED}  Error: Unsupported Linux architecture: $arch (only x86_64 supported)${RESET}" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo -e "${RED}  Error: Unsupported platform: $os. macOS and Linux only.${RESET}" >&2
      exit 1
      ;;
  esac
}

PLATFORM="$(detect_platform)"
echo -e "${DIM}  Platform: $PLATFORM${RESET}"

# ─── Dependency checks ────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}  Checking dependencies...${RESET}"

HAS_CLI=false

if command -v claude &>/dev/null; then
  echo -e "  ${GREEN}✓${RESET} claude (Claude Code) found"
  HAS_CLI=true
fi

if command -v codex &>/dev/null; then
  echo -e "  ${GREEN}✓${RESET} codex (OpenAI Codex) found"
  HAS_CLI=true
fi

if [ "$HAS_CLI" = "false" ]; then
  echo -e "  ${RED}✗${RESET} Neither 'claude' nor 'codex' CLI found"
  echo ""
  echo -e "${YELLOW}  You need one of:${RESET}"
  echo -e "    • Claude Code: https://claude.ai/download"
  echo -e "    • OpenAI Codex: npm install -g @openai/codex"
  echo ""
  echo -e "${RED}  Please install a CLI and re-run this installer.${RESET}"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo -e "  ${RED}✗${RESET} python3 not found"
  echo ""
  echo -e "${RED}  Python 3.10+ is required. Install it from https://python.org${RESET}"
  exit 1
else
  PYTHON_VERSION="$(python3 --version 2>&1 | awk '{print $2}')"
  echo -e "  ${GREEN}✓${RESET} python3 found ($PYTHON_VERSION)"
fi

if ! command -v curl &>/dev/null; then
  echo -e "  ${RED}✗${RESET} curl not found (required for downloads)"
  exit 1
fi

# ─── Python dependencies ──────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}  Installing Python dependencies...${RESET}"
echo -e "${DIM}  (sentence-transformers, chromadb — this may take a minute)${RESET}"
echo ""

if pip3 install --quiet --user sentence-transformers chromadb 2>/dev/null; then
  echo -e "  ${GREEN}✓${RESET} Python dependencies installed"
else
  echo -e "  ${YELLOW}⚠${RESET}  Could not install Python dependencies automatically."
  echo -e "${DIM}    Memory search features will be limited until you run:${RESET}"
  echo -e "${DIM}    pip3 install sentence-transformers chromadb${RESET}"
fi

# ─── Download latest release ──────────────────────────────────────────────────

echo ""
echo -e "${CYAN}${BOLD}  Fetching latest release...${RESET}"

LATEST_VERSION="$(curl -fsSL --max-time 10 "$GITHUB_API" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['tag_name'].lstrip('v'))" 2>/dev/null)" \
  || {
    echo -e "${RED}  Error: Could not fetch release info from GitHub.${RESET}"
    exit 1
  }

echo -e "  Latest: ${BOLD}v${LATEST_VERSION}${RESET}"

TARBALL_NAME="clone-engine-${LATEST_VERSION}-${PLATFORM}.tar.gz"
TARBALL_URL="$GITHUB_RELEASES/v${LATEST_VERSION}/${TARBALL_NAME}"
TMP_DIR="$(mktemp -d)"
TARBALL_PATH="$TMP_DIR/$TARBALL_NAME"

echo -e "${DIM}  Downloading $TARBALL_NAME ...${RESET}"

if ! curl -fsSL --max-time 120 -o "$TARBALL_PATH" "$TARBALL_URL"; then
  echo -e "${RED}  Error: Download failed.${RESET}"
  echo -e "${DIM}  URL: $TARBALL_URL${RESET}"
  rm -rf "$TMP_DIR"
  exit 1
fi

# ─── Extract to ~/.clone-engine ───────────────────────────────────────────────

echo -e "${CYAN}${BOLD}  Installing to $ENGINE_DIR ...${RESET}"
mkdir -p "$ENGINE_DIR"
tar -xzf "$TARBALL_PATH" -C "$ENGINE_DIR"

# Make all scripts executable
find "$ENGINE_DIR" -name "*.sh" -exec chmod +x {} \;

rm -rf "$TMP_DIR"
echo -e "  ${GREEN}✓${RESET} Engine installed"

# ─── Upgrade path: existing config ────────────────────────────────────────────

if [ -f "$CONFIG_FILE" ]; then
  echo ""
  echo -e "${GREEN}${BOLD}  Existing config found — upgrade complete.${RESET}"
  echo -e "${DIM}  Your profile and settings have been preserved.${RESET}"
  echo ""
  echo -e "${YELLOW}  Restart your shell to pick up any updates.${RESET}"
  echo ""
  exit 0
fi

# ─── Fresh install: run setup ─────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}  Installation complete. Starting setup...${RESET}"
echo ""

SETUP_SCRIPT="$ENGINE_DIR/setup/setup.sh"

if [ -f "$SETUP_SCRIPT" ]; then
  bash "$SETUP_SCRIPT"
else
  echo -e "${RED}  Error: setup.sh not found at $SETUP_SCRIPT${RESET}"
  echo -e "${DIM}  Try running: bash $ENGINE_DIR/setup/setup.sh${RESET}"
  exit 1
fi
