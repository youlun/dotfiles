# dotfiles

Declarative Mac dev environment managed by [chezmoi](https://www.chezmoi.io/).

## Fresh machine setup

```bash
# Prerequisites: sign into Mac App Store, verify FileVault is enabled
bash bootstrap.sh
```

This installs Homebrew, chezmoi, then runs `chezmoi init --apply` which:
- Prompts for profile (`yw-macbook-pro` or `yw-mac-mini`)
- Places dotfiles
- Installs Brewfile packages
- Installs mise runtimes
- Applies macOS defaults

After bootstrap, run `./verify.sh` to check everything installed.

## Manual steps after bootstrap

1. Open Bitwarden and sign in
2. Enable Bitwarden SSH agent
3. Sign into browsers
4. Activate licenses

## Day-to-day usage

```bash
chezmoi add ~/.config/some/file   # capture a config into the repo
chezmoi edit ~/.config/some/file  # edit the source version, then apply
chezmoi apply                     # apply all changes from source to home
chezmoi diff                      # preview what apply would change
chezmoi cd                        # cd into the source directory
chezmoi update                    # git pull + apply (on other machines)
```

## Workflow after changing a config

```bash
chezmoi add ~/.config/starship.toml
chezmoi cd
git add . && git commit && git push
```

## Adding packages

Edit `Brewfile.tmpl`. Use `{{ if .is_mbp }}` blocks for MacBook Pro-only apps. The brew bundle script re-runs automatically on next `chezmoi apply`.
