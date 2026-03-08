#!/usr/bin/env bash
set -euo pipefail

errors=0

echo "==> Checking CLI tools..."
for cmd in git gh mise zoxide fzf fd rg bat eza lazygit starship atuin sd dust delta mactop mas; do
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd NOT FOUND"
        errors=$((errors + 1))
    fi
done

echo ""
echo "==> Checking brew bundle..."
if brew bundle check --file="${HOME}/.config/homebrew/Brewfile" &>/dev/null; then
    echo "  ✓ All Brewfile entries installed"
else
    echo "  ✗ Some Brewfile entries missing"
    brew bundle check --file="${HOME}/.config/homebrew/Brewfile" --verbose 2>&1 | head -20
    errors=$((errors + 1))
fi

echo ""
echo "==> Checking Bitwarden SSH agent..."
if [ -S ~/.bitwarden-ssh-agent.sock ]; then
    echo "  ✓ Bitwarden SSH agent socket found"
else
    echo "  ! Bitwarden SSH agent socket not found (start Bitwarden to activate)"
fi

echo ""
echo "==> Checking mise runtimes..."
for runtime in ruby node python; do
    if mise which "$runtime" &>/dev/null; then
        echo "  ✓ $runtime"
    else
        echo "  ✗ $runtime NOT INSTALLED"
        errors=$((errors + 1))
    fi
done

echo ""
if [ "$errors" -eq 0 ]; then
    echo "All checks passed."
else
    echo "$errors check(s) failed."
    exit 1
fi
