#!/usr/bin/env bash
# Dotfiles bootstrap — orchestrates a full macOS setup from scratch.
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/youlun/dotfiles/main/bootstrap.sh)
# -e intentionally omitted: each step handles its own errors
set -uo pipefail

# ── Architecture gate ────────────────────────────────────────
if [ "$(uname -m)" != "arm64" ]; then
    echo "Error: this setup targets Apple Silicon (arm64) only."
    exit 1
fi

# ── ANSI colors (disabled when not a TTY) ────────────────────
# Check /dev/tty since exec tee redirect makes fd 1 a pipe
if [ -e /dev/tty ] && [ -t 0 ]; then
    BOLD=$'\033[1m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RED=$'\033[31m'
    CYAN=$'\033[36m' DIM=$'\033[2m' RESET=$'\033[0m'
else
    BOLD='' GREEN='' YELLOW='' RED='' CYAN='' DIM='' RESET=''
fi

# ── UX helpers ───────────────────────────────────────────────
STEP_CURRENT=0
STEP_TOTAL=7
LOG_FILE="${HOME}/bootstrap-$(date +%Y%m%d-%H%M%S).log"
CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"
IS_MBP="false"

step() {
    STEP_CURRENT=$((STEP_CURRENT + 1))
    echo ""
    echo "${BOLD}${CYAN}[${STEP_CURRENT}/${STEP_TOTAL}]${RESET} ${BOLD}$1${RESET}"
}

ok()   { echo "  ${GREEN}✓${RESET} $1"; }
warn() { echo "  ${YELLOW}!${RESET} $1"; }
fail() { echo "  ${RED}✗${RESET} $1"; }
info() { echo "  $1"; }

_SPINNER_PID=''
spinner_start() {
    [ -e /dev/tty ] || return 0
    local label="$1"
    (
        while true; do
            for frame in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
                printf '\r  %s %s' "$frame" "$label" >/dev/tty
                sleep 0.1
            done
        done
    ) &
    _SPINNER_PID=$!
}

spinner_stop() {
    if [ -n "$_SPINNER_PID" ]; then
        kill "$_SPINNER_PID" 2>/dev/null
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=''
    fi
    [ -e /dev/tty ] && printf '\r\033[K' >/dev/tty
}

# Clean up spinner on unexpected exit
trap 'spinner_stop' EXIT

# ── Logging ──────────────────────────────────────────────────
setup_logging() {
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "${DIM}Log: ${LOG_FILE}${RESET}"
    echo "Bootstrap started: $(date)" >> "$LOG_FILE"
}

# ── Step 1: Pre-flight checks ───────────────────────────────
step_preflight() {
    step "Pre-flight checks"

    # Network
    if curl -fsS --max-time 5 https://formulae.brew.sh > /dev/null 2>&1; then
        ok "Network"
    else
        fail "No network — cannot continue"
        exit 1
    fi

    # MAS sign-in (only if mas is already installed from a previous run)
    if command -v mas &>/dev/null; then
        if mas account &>/dev/null; then
            ok "App Store signed in"
        else
            warn "Not signed into App Store — MAS apps will be skipped"
        fi
    else
        info "${DIM}MAS check skipped (mas not yet installed)${RESET}"
    fi
}

# ── Step 2: Homebrew & chezmoi ───────────────────────────────
step_homebrew() {
    step "Homebrew & chezmoi"

    if command -v brew &>/dev/null; then
        ok "Homebrew already installed"
    else
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    eval "$(/opt/homebrew/bin/brew shellenv)"

    if command -v chezmoi &>/dev/null; then
        ok "chezmoi already installed"
    else
        info "Installing chezmoi..."
        brew install chezmoi
    fi
}

# ── Step 3: Dotfiles & macOS defaults ────────────────────────
step_chezmoi() {
    step "Dotfiles & macOS defaults"

    local chezmoi_rc=0

    if [ -d "$CHEZMOI_SOURCE/.git" ]; then
        spinner_start "Pulling dotfiles"
        chezmoi git -- pull --autostash --rebase >> "$LOG_FILE" 2>&1 || chezmoi_rc=$?
        spinner_stop
        if [ "$chezmoi_rc" -eq 0 ]; then
            spinner_start "Applying dotfiles"
            chezmoi apply --force --verbose >> "$LOG_FILE" 2>&1 || chezmoi_rc=$?
            spinner_stop
        fi
    else
        spinner_start "Initializing dotfiles"
        chezmoi init --apply --force --verbose https://github.com/youlun/dotfiles >> "$LOG_FILE" 2>&1 || chezmoi_rc=$?
        spinner_stop
    fi

    if [ "$chezmoi_rc" -eq 0 ]; then
        ok "Dotfiles applied"
    else
        warn "chezmoi exited with status $chezmoi_rc (see log for details)"
    fi

    # Detect profile for OrbStack placeholder
    if command -v chezmoi &>/dev/null; then
        IS_MBP=$(chezmoi data --format json 2>/dev/null \
            | python3 -c "import sys,json; print('true' if json.load(sys.stdin).get('is_mbp') else 'false')" 2>/dev/null \
            || echo "false")
    fi
}

# ── Step 4: Homebrew packages ────────────────────────────────
step_brew_bundle() {
    step "Homebrew packages"

    local brewfile="${HOME}/.config/homebrew/Brewfile"

    if [ ! -f "$brewfile" ]; then
        fail "Brewfile not found at $brewfile (chezmoi may have failed)"
        return 1
    fi

    # Brew update
    spinner_start "Updating Homebrew"
    brew update >> "$LOG_FILE" 2>&1 || true
    spinner_stop
    ok "Homebrew updated"

    # Check if already complete
    if brew bundle check --file="$brewfile" --quiet >> "$LOG_FILE" 2>&1; then
        ok "All packages already installed"
        return 0
    fi

    # Try brew bundle
    info "Installing packages..."
    if brew bundle --file="$brewfile" >> "$LOG_FILE" 2>&1; then
        ok "All packages installed"
        return 0
    fi

    # Brew bundle failed — collect what's missing
    warn "brew bundle had failures"
    echo ""

    local failed=()
    local line

    while IFS= read -r line; do
        failed+=("$line")
    done < <(brew bundle check --file="$brewfile" --verbose 2>&1 | grep "^→" || true)

    if [ ${#failed[@]} -eq 0 ]; then
        warn "Could not determine which packages failed"
        return 1
    fi

    echo "  ${#failed[@]} package(s) need attention:"
    for line in "${failed[@]}"; do
        echo "    $line"
    done
    echo ""

    # Prompt to retry individually
    printf "  Install packages individually? [Y/n] "
    read -r answer </dev/tty
    if [[ "$answer" =~ ^[Nn] ]]; then
        warn "Skipped individual install"
        return 1
    fi

    echo ""
    local install_failed=()

    # Helper: install brew entries by type
    _install_entries() {
        local type="$1"    # formula or cask
        local prefix="$2"  # brew or cask
        local flag="--${type}"
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            if brew list "$flag" "$pkg" &>/dev/null; then
                ok "$pkg (already installed)"
            else
                if brew install $flag "$pkg" >> "$LOG_FILE" 2>&1; then
                    ok "$pkg"
                else
                    fail "$pkg"
                    install_failed+=("${type}: $pkg")
                fi
            fi
        done < <(grep "^${prefix} " "$brewfile" | sed "s/${prefix} \"\([^\"]*\)\".*/\1/")
    }

    _install_entries "formula" "brew"
    _install_entries "cask" "cask"

    # Install MAS apps individually
    if command -v mas &>/dev/null && mas account &>/dev/null; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local app_name app_id
            app_name=$(echo "$line" | sed 's/mas "\([^"]*\)".*/\1/')
            app_id=$(echo "$line" | sed 's/.*id: *\([0-9]*\).*/\1/')
            if mas list | grep -q "^$app_id "; then
                ok "$app_name (already installed)"
            else
                if mas install "$app_id" >> "$LOG_FILE" 2>&1; then
                    ok "$app_name"
                else
                    fail "$app_name"
                    install_failed+=("mas: $app_name")
                fi
            fi
        done < <(grep '^mas ' "$brewfile")
    else
        info "${DIM}MAS apps skipped (not signed in or mas not available)${RESET}"
    fi

    # Summary
    if [ ${#install_failed[@]} -gt 0 ]; then
        echo ""
        warn "${#install_failed[@]} package(s) failed:"
        for item in "${install_failed[@]}"; do
            echo "    - $item"
        done
        echo ""
        printf "  Continue with setup? [Y/n] "
        read -r answer </dev/tty
        if [[ "$answer" =~ ^[Nn] ]]; then
            info "Stopped. Fix issues and re-run bootstrap."
            exit 1
        fi
    else
        echo ""
        ok "All packages installed individually"
    fi
}

# ── Step 5: bat theme ────────────────────────────────────────
step_bat_theme() {
    step "bat theme"

    if ! command -v bat &>/dev/null; then
        warn "bat not installed — skipping"
        return 0
    fi

    local theme_dir
    theme_dir="$(bat --config-dir)/themes"

    if [ -f "${theme_dir}/Catppuccin Mocha.tmTheme" ]; then
        ok "Catppuccin Mocha already installed"
        return 0
    fi

    mkdir -p "$theme_dir"

    if curl -fsSL -o "${theme_dir}/Catppuccin Mocha.tmTheme" \
        "https://github.com/catppuccin/bat/raw/main/themes/Catppuccin%20Mocha.tmTheme" 2>> "$LOG_FILE"; then
        bat cache --build >> "$LOG_FILE" 2>&1
        ok "Catppuccin Mocha installed"
    else
        fail "Failed to download bat theme (see log)"
    fi
}

# ── Step 6: mise runtimes ────────────────────────────────────
step_mise_install() {
    step "Runtime versions"

    if ! command -v mise &>/dev/null; then
        warn "mise not installed — skipping"
        return 0
    fi

    # Check if all runtimes already present
    if mise which ruby &>/dev/null && mise which node &>/dev/null && mise which python &>/dev/null; then
        ok "All runtimes already installed"
        return 0
    fi

    eval "$(mise activate bash)"
    spinner_start "Installing runtimes"
    if mise install --yes >> "$LOG_FILE" 2>&1; then
        spinner_stop
        ok "Runtimes installed"
        # Show versions
        for rt in ruby node python; do
            local ver
            ver=$("$rt" --version 2>/dev/null | head -1 || echo "unknown")
            info "${DIM}$rt: $ver${RESET}"
        done
    else
        spinner_stop
        fail "mise install had errors (see log)"
    fi
}

# ── Step 7: Verify ───────────────────────────────────────────
step_verify() {
    step "Verification"
    bash "${CHEZMOI_SOURCE}/verify.sh" 2>&1 | tee -a "$LOG_FILE" || true
}

# ── Manual steps ─────────────────────────────────────────────
print_summary() {
    echo ""
    echo "${BOLD}Manual steps:${RESET}"
    echo "  1. Open Bitwarden and sign in"
    echo "  2. Enable Bitwarden SSH agent"
    echo "  3. Sign into browsers"
    echo ""
    info "${DIM}Full log: ${LOG_FILE}${RESET}"
}

# ── Main ─────────────────────────────────────────────────────
main() {
    echo "${BOLD}Dotfiles Bootstrap${RESET}"

    setup_logging
    step_preflight
    step_homebrew
    step_chezmoi
    step_brew_bundle
    step_bat_theme
    step_mise_install

    # OrbStack SSH placeholder (MBP only, before verify)
    if [ "$IS_MBP" = "true" ] && [ ! -f ~/.orbstack/ssh/config ]; then
        mkdir -p ~/.orbstack/ssh
        touch ~/.orbstack/ssh/config
    fi

    step_verify
    print_summary
}

main
