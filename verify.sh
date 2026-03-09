#!/usr/bin/env bash
set -uo pipefail

# Ensure mise shims are available when run standalone
export PATH="${HOME}/.local/share/mise/shims:${PATH}"

_tmp_brewfile=""
trap '[ -n "$_tmp_brewfile" ] && rm -f "$_tmp_brewfile"' EXIT

errors=0
failed_items=()

echo "==> Checking CLI tools..."
for cmd in git gh mise zoxide fzf fd rg bat eza lazygit starship atuin sd dust delta mactop mas; do
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd NOT FOUND"
        errors=$((errors + 1))
        failed_items+=("CLI tool: $cmd")
    fi
done

echo ""
echo "==> Checking Brewfile..."
_brewfile="${HOME}/.config/homebrew/Brewfile"
if command -v mas &>/dev/null && mas account &>/dev/null; then
    _check_file="$_brewfile"
else
    _check_file=$(mktemp)
    _tmp_brewfile="$_check_file"
    grep -v '^mas ' "$_brewfile" > "$_check_file"
    echo "  ! MAS not signed in — skipping App Store entries"
fi
if brew bundle check --file="$_check_file" &>/dev/null; then
    echo "  ✓ All Brewfile entries installed"
else
    echo "  ✗ Brewfile entries missing (re-run bootstrap.sh)"
    errors=$((errors + 1))
    failed_items+=("Brewfile: entries missing")
fi

echo ""
echo "==> Checking GitHub authentication..."
if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
        echo "  ✓ GitHub authenticated"
    else
        echo "  ! GitHub not authenticated (run: gh auth login)"
    fi
else
    echo "  ! gh not found (already counted above)"
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
        failed_items+=("mise runtime: $runtime")
    fi
done

echo ""
if [ "$errors" -eq 0 ]; then
    echo "All checks passed."
else
    echo "$errors check(s) failed:"
    for item in "${failed_items[@]}"; do
        echo "  - $item"
    done
    echo ""
    echo "Recovery:"
    echo "  bash ~/.local/share/chezmoi/bootstrap.sh         # re-run bootstrap"
    echo "  bash ~/.local/share/chezmoi/verify.sh            # re-verify only"
    exit 1
fi
