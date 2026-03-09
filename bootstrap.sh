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
    local log_file="$LOG_FILE"
    (
        local start=$SECONDS
        local last_size last_change current_size
        last_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
        last_change=$SECONDS
        while true; do
            for frame in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
                local elapsed=$(( SECONDS - start ))
                local mins=$(( elapsed / 60 )) secs=$(( elapsed % 60 ))
                local time_str
                if [ "$mins" -gt 0 ]; then
                    time_str="${mins}m $(printf '%02d' "$secs")s"
                else
                    time_str="${secs}s"
                fi

                # Check log growth once per cycle (every ~1s)
                if [ "$frame" = '⠋' ]; then
                    current_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
                    if [ "$current_size" != "$last_size" ]; then
                        last_size=$current_size
                        last_change=$SECONDS
                    fi
                fi

                local stall_secs=$(( SECONDS - last_change ))
                local suffix=""
                if [ "$stall_secs" -ge 30 ]; then
                    suffix=" ${YELLOW}— no activity for ${stall_secs}s${RESET}"
                fi

                printf '\r\033[K  %s %s (%s)%s' "$frame" "$label" "$time_str" "$suffix" >/dev/tty
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

# Clean up on unexpected exit or interrupt
trap 'spinner_stop' EXIT
trap 'exit 130' INT TERM

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
        if ! command -v chezmoi &>/dev/null; then
            fail "chezmoi installation failed"
            exit 1
        fi
    fi
}

# ── Step 3: Dotfiles & macOS defaults ────────────────────────
prompt_profile() {
    if [ ! -e /dev/tty ]; then
        fail "Cannot prompt for profile: no TTY available (non-interactive environment)"
        exit 1
    fi

    local profiles=("yw-macbook-pro" "yw-mac-mini")
    local choice

    echo ""
    echo "  ${BOLD}Select profile:${RESET}"
    for i in "${!profiles[@]}"; do
        echo "    $((i + 1))) ${profiles[$i]}"
    done
    echo ""
    printf "  Choice [1]: " >/dev/tty
    read -r choice </dev/tty 2>/dev/null || choice=""
    choice="${choice:-1}"

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#profiles[@]}" ]; then
        fail "Invalid choice"
        exit 1
    fi

    PROFILE="${profiles[$((choice - 1))]}"
    ok "Profile: ${PROFILE}"

    # Pre-seed chezmoi config so init won't prompt
    local config_dir="${HOME}/.config/chezmoi"
    mkdir -p "$config_dir"
    cat > "${config_dir}/chezmoi.toml" <<TOML
[data]
    profile = "$PROFILE"
    is_mbp = $([ "$PROFILE" = "yw-macbook-pro" ] && echo "true" || echo "false")
    is_mini = $([ "$PROFILE" = "yw-mac-mini" ] && echo "true" || echo "false")
TOML
}

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
        # Prompt for profile before init so chezmoi doesn't need to ask
        if [ -f "${HOME}/.config/chezmoi/chezmoi.toml" ]; then
            local existing_profile
            existing_profile=$(grep '^    profile' "${HOME}/.config/chezmoi/chezmoi.toml" 2>/dev/null \
                | sed 's/.*= *"\(.*\)"/\1/' || echo "unknown")
            echo ""
            printf "  Current profile: ${BOLD}%s${RESET}. Re-select? [y/N] " "$existing_profile" >/dev/tty
            local reselect=""
            read -r reselect </dev/tty 2>/dev/null || reselect=""
            if [[ "$reselect" =~ ^[Yy] ]]; then
                prompt_profile
            else
                ok "Keeping profile: ${existing_profile}"
            fi
        else
            prompt_profile
        fi

        spinner_start "Initializing dotfiles"
        chezmoi init --apply --force --verbose https://github.com/youlun/dotfiles >> "$LOG_FILE" 2>&1 || chezmoi_rc=$?
        spinner_stop
    fi

    if [ "$chezmoi_rc" -eq 0 ]; then
        ok "Dotfiles applied"
    else
        warn "chezmoi exited with status $chezmoi_rc (see log for details)"
    fi

}

# ── Step 4: Homebrew packages ────────────────────────────────
step_brew_install() {
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

    local install_failed=()
    local pkg_current=0
    local pkg_total=0
    local mas_count=0

    # Count total packages (always include MAS for accurate counter)
    mas_count=$(grep -c "^mas " "$brewfile" || true)
    pkg_total=$(( $(grep -c "^brew " "$brewfile") + $(grep -c "^cask " "$brewfile") + mas_count ))

    # Helper: install brew entries by type
    _install_entries() {
        local type="$1"    # formula or cask
        local prefix="$2"  # brew or cask
        local flag="--${type}"
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            pkg_current=$((pkg_current + 1))
            local counter="${DIM}(${pkg_current}/${pkg_total})${RESET}"
            if brew list "$flag" "$pkg" </dev/null &>/dev/null; then
                ok "$pkg $counter"
            else
                printf '  … %s %s' "$pkg" "$counter" >/dev/tty 2>/dev/null || true
                if brew install "$flag" "$pkg" </dev/null >> "$LOG_FILE" 2>&1; then
                    printf '\r\033[K' >/dev/tty 2>/dev/null || true
                    ok "$pkg $counter"
                else
                    printf '\r\033[K' >/dev/tty 2>/dev/null || true
                    fail "$pkg $counter"
                    install_failed+=("${type}: $pkg")
                fi
            fi
        done < <(grep "^${prefix} " "$brewfile" | sed "s/${prefix} \"\([^\"]*\)\".*/\1/")
    }

    _install_entries "formula" "brew"
    _install_entries "cask" "cask"

    # Install MAS apps individually
    if [ "$mas_count" -gt 0 ]; then
        if command -v mas &>/dev/null && mas account &>/dev/null; then
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                local app_name app_id
                app_name="${line#mas \"}"
                app_name="${app_name%%\"*}"
                app_id="${line##*id: }"
                app_id="${app_id%%[!0-9]*}"
                pkg_current=$((pkg_current + 1))
                local counter="${DIM}(${pkg_current}/${pkg_total})${RESET}"
                if mas list </dev/null | grep -q "^$app_id "; then
                    ok "$app_name $counter"
                else
                    printf '  … %s %s' "$app_name" "$counter" >/dev/tty 2>/dev/null || true
                    if mas install "$app_id" </dev/null >> "$LOG_FILE" 2>&1; then
                        printf '\r\033[K' >/dev/tty 2>/dev/null || true
                        ok "$app_name $counter"
                    else
                        printf '\r\033[K' >/dev/tty 2>/dev/null || true
                        fail "$app_name $counter"
                        install_failed+=("mas: $app_name")
                    fi
                fi
            done < <(grep '^mas ' "$brewfile")
        else
            warn "MAS apps skipped — not signed in (${mas_count} packages)"
            pkg_total=$((pkg_total - mas_count))
        fi
    fi

    # Summary
    if [ ${#install_failed[@]} -gt 0 ]; then
        echo ""
        warn "${#install_failed[@]} package(s) failed:"
        for item in "${install_failed[@]}"; do
            echo "    - $item"
        done
        echo ""
        local answer=""
        printf "  Continue with setup? [Y/n] "
        read -r answer </dev/tty 2>/dev/null || answer="y"
        if [[ "$answer" =~ ^[Nn] ]]; then
            info "Stopped. Fix issues and re-run bootstrap."
            exit 1
        fi
    else
        echo ""
        ok "All packages installed"
    fi
}

# ── Step 5: GitHub authentication ────────────────────────────
step_gh_auth() {
    step "GitHub authentication"

    if ! command -v gh &>/dev/null; then
        warn "gh not installed — skipping"
        return 0
    fi

    if gh auth status &>/dev/null 2>&1; then
        ok "Already authenticated"
    else
        info "Authenticate with GitHub (opens browser)"
        if gh auth login --web --git-protocol https </dev/tty >/dev/tty 2>/dev/tty; then
            ok "GitHub authenticated"
        else
            warn "Skipped — git push won't work until you run: gh auth login"
            return 0
        fi
    fi

    # Write credential helper to local git config (not chezmoi-managed)
    local local_config="${HOME}/.config/git/local"
    if ! grep -q 'gh auth git-credential' "$local_config" 2>/dev/null; then
        mkdir -p "$(dirname "$local_config")"
        cat >> "$local_config" <<'GITCONF'
[credential "https://github.com"]
    helper =
    helper = !/opt/homebrew/bin/gh auth git-credential
[credential "https://gist.github.com"]
    helper =
    helper = !/opt/homebrew/bin/gh auth git-credential
GITCONF
        ok "Git credential helper configured"
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
    bash "${CHEZMOI_SOURCE}/verify.sh" || true
}

# ── Manual steps ─────────────────────────────────────────────
print_summary() {
    echo ""
    echo "${BOLD}Manual steps:${RESET}"
    echo "  1. Sign into browsers"
    echo "  2. Open Bitwarden and sign in"
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
    step_brew_install
    step_gh_auth
    step_mise_install

    step_verify
    print_summary
}

main
