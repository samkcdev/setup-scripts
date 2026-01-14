#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$HOME/Documents/keybindings-backup"
DATE=$(date +%Y-%m-%d)
mkdir -p "$BACKUP_DIR"

echo "Backing up GNOME Keybindings..."

# 1. Standard Window Manager Shortcuts (Alt+Tab, Maximize, etc.)
dconf dump /org/gnome/desktop/wm/keybindings/ >"$BACKUP_DIR/wm-shortcuts-$DATE.dconf"

# 2. Media Keys & Custom Shortcuts (Volume, Play/Pause, Custom scripts)
# Crucial: This path contains the definition of your custom shortcuts list AND their values
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ >"$BACKUP_DIR/media-custom-shortcuts-$DATE.dconf"

# 3. GNOME Shell Shortcuts (Overview, Switch Input, etc.)
dconf dump /org/gnome/shell/keybindings/ >"$BACKUP_DIR/shell-shortcuts-$DATE.dconf"

# 4. Mutter Shortcuts (Wayland/Compositor specifics)
dconf dump /org/gnome/mutter/keybindings/ >"$BACKUP_DIR/mutter-shortcuts-$DATE.dconf"
dconf dump /org/gnome/mutter/wayland/keybindings/ >"$BACKUP_DIR/mutter-wayland-shortcuts-$DATE.dconf"

echo -e "\033[0;32m[OK]\033[0m Backup saved to: $BACKUP_DIR"
