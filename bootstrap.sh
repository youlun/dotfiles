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

echo "==> Installing chezmoi..."
brew install chezmoi

echo "==> Running chezmoi init --apply..."
chezmoi init --apply --verbose https://github.com/youlun/dotfiles

echo ""
echo "Bootstrap complete. Run ./verify.sh to check."
echo ""
echo "Manual steps:"
echo "  1. Open Bitwarden and sign in"
echo "  2. Enable Bitwarden SSH agent"
echo "  3. Sign into browsers"
