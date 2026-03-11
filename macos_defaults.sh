#!/usr/bin/env bash
# macOS defaults — idempotent, safe to re-run anytime.
# Called by bootstrap.sh step 3, or run standalone.
set -euo pipefail

# ── Mouse & Trackpad ──────────────────────────────────────────
defaults write -g com.apple.mouse.scaling -float 2.0
defaults write -g com.apple.trackpad.scaling -float 2.5
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# ── Dock ──────────────────────────────────────────────────────
defaults write com.apple.dock tilesize -int 39
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.15
defaults write com.apple.dock show-recents -bool false

# ── Finder ────────────────────────────────────────────────────
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Documents/"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowSidebar -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXArrangeGroupViewBy -string "None"
defaults write com.apple.finder FXPreferredGroupBy -string "None"

# List view settings (icon size, calculate folder sizes)
FINDER_PLIST=~/Library/Preferences/com.apple.finder.plist
for prefix in FK_StandardViewSettings StandardViewSettings; do
    for view in ListViewSettings ExtendedListViewSettingsV2; do
        /usr/libexec/PlistBuddy -c "Set :${prefix}:${view}:iconSize 32" "$FINDER_PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Set :${prefix}:${view}:calculateAllSizes true" "$FINDER_PLIST" 2>/dev/null || true
    done
done

# ── Keyboard ──────────────────────────────────────────────────
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# ── Dialogs ───────────────────────────────────────────────────
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# ── Screenshots ───────────────────────────────────────────────
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture location -string "${HOME}/Documents/00 Inbox/Screenshots"
mkdir -p "${HOME}/Documents/00 Inbox/Screenshots"

# ── .DS_Store ─────────────────────────────────────────────────
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# ── Accessibility ─────────────────────────────────────────────
defaults write com.apple.universalaccess reduceMotion -bool true

# ── ImageCapture ──────────────────────────────────────────────
defaults write com.apple.ImageCapture disableHotPlug -bool true

# ── Time Machine ──────────────────────────────────────────────
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

# ── Misc ──────────────────────────────────────────────────────
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# ── Apply changes ─────────────────────────────────────────────
killall Finder Dock SystemUIServer 2>/dev/null || true
