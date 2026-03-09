# dotfiles

## Overview
- Managed with **chezmoi** — source at `~/.local/share/chezmoi/`
- Profiles: `yw-macbook-pro` (MacBook Pro) and `yw-mac-mini` (Mac mini), both Apple Silicon
- Bootstrap: `bash <(curl -fsSL https://raw.githubusercontent.com/youlun/dotfiles/main/bootstrap.sh)`

## Commands
- Lint: `shellcheck bootstrap.sh verify.sh`
- Syntax check: `bash -n bootstrap.sh && bash -n verify.sh`
- Test templates: `chezmoi execute-template --config <config> < <file>.tmpl`

## Conventions
- Profile selection happens in bootstrap.sh via numbered menu, pre-seeds `~/.config/chezmoi/chezmoi.toml`
- chezmoi templates use `promptChoiceOnce` for profile — but interactive prompts go through bootstrap, not chezmoi directly
- Bootstrap logs to file via `tee`; interactive prompts must use `/dev/tty` to avoid being swallowed

## CI
- 7 jobs: shellcheck, syntax-check, chezmoi-validate (×2 profiles), brewfile-validate, integration-test (×2 profiles on macOS)
- All template changes must pass `chezmoi execute-template` for both profiles

## Related
- macstate (system state capture tool): https://github.com/youlun/macstate
