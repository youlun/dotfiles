# dotfiles

Declarative Mac dev environment managed by [chezmoi](https://www.chezmoi.io/). Apple Silicon only.

## What's included

- **Shell**: zsh with starship prompt, history, cached completions, aliases (`cat`→`bat`, `ls`→`eza`)
- **Tools**: mise (Ruby, Node, Python), fzf, zoxide, atuin, ripgrep, fd, lazygit, delta, and more
- **Theme**: Catppuccin Mocha across bat, fzf, starship, lazygit, and delta
- **Git**: delta pager, rebase on pull, rerere, histogram diffs
- **SSH**: Bitwarden SSH agent, OrbStack integration (MBP only)
- **macOS**: keyboard repeat, trackpad tap-to-click, Dock autohide, Finder preferences, and more

## Profiles

Two profiles with shared base config:

- **yw-macbook-pro** — full setup with IDE casks (VSCode, JetBrains), OrbStack, dev tools, and Mac App Store apps
- **yw-mac-mini** — core CLI tools and essential GUI apps only

## Setup

> Prerequisites: sign into Mac App Store (for MAS apps on MBP), verify FileVault is enabled.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/youlun/dotfiles/main/bootstrap.sh)
```

The script is safe to re-run — it detects an existing checkout and runs `chezmoi update` instead of a fresh init.

This installs Homebrew and chezmoi, then applies dotfiles which:
- Prompts for profile (restricted to `yw-macbook-pro` or `yw-mac-mini`)
- Places dotfiles
- Installs Brewfile packages
- Installs bat Catppuccin Mocha theme
- Installs mise runtimes (Ruby, Node, Python)
- Applies macOS defaults
- Runs verification automatically

## Manual steps after bootstrap

1. Open Bitwarden and sign in
2. Enable Bitwarden SSH agent
3. Sign into browsers
4. Activate licenses

## Day-to-day usage

```bash
chezmoi apply                     # apply all changes from source to home
chezmoi diff                      # preview what apply would change
chezmoi add ~/.config/some/file   # capture a config into the repo
chezmoi edit ~/.config/some/file  # edit the source version, then apply
chezmoi cd                        # cd into the source directory
chezmoi update                    # git pull + apply (on other machines)
```

## Adding packages

Edit `dot_config/homebrew/Brewfile.tmpl`. Use `{{ if .is_mbp }}` blocks for MacBook Pro-only apps. The brew bundle script re-runs automatically on next `chezmoi apply`.
