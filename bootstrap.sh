#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -m)" != "arm64" ]; then
    echo "Error: this setup targets Apple Silicon (arm64) only."
    exit 1
fi

echo "==> Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Apple Silicon — both target machines use /opt/homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

if ! command -v chezmoi &>/dev/null; then
    echo "==> Installing chezmoi..."
    brew install chezmoi
fi

CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"

chezmoi_rc=0
if [ -d "$CHEZMOI_SOURCE/.git" ]; then
    echo "==> Updating dotfiles..."
    chezmoi update --verbose || chezmoi_rc=$?
else
    echo "==> Initializing dotfiles..."
    chezmoi init --apply --verbose https://github.com/youlun/dotfiles || chezmoi_rc=$?
fi

if [ "$chezmoi_rc" -ne 0 ]; then
    echo ""
    echo "Warning: chezmoi exited with status $chezmoi_rc (some scripts may have failed)."
    echo "  Run 'chezmoi apply --force --verbose' to retry after fixing issues."
fi

echo ""
echo "==> Running verification..."
bash "${CHEZMOI_SOURCE}/verify.sh" || true

echo ""
echo "Manual steps:"
echo "  1. Open Bitwarden and sign in"
echo "  2. Enable Bitwarden SSH agent"
echo "  3. Sign into browsers"
