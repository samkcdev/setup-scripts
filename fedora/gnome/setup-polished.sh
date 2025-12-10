#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration & Variables
# -----------------------------------------------------------------------------

# Colors for pretty printing
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# DNF Packages
CLI_PKGS=(
  gh lsd neovim btop fzf fastfetch mpv distrobox tealdeer
  keepassxc bat qbittorrent gnome-tweaks @virtualization
)

RPM_FUSION_URLS=(
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
)

# Flatpak Packages
FLATPAK_APPS=(
  md.obsidian.Obsidian
  app.zen_browser.zen
  com.github.tchx84.Flatseal
  com.stremio.Stremio
  com.usebottles.bottles
  org.gnome.World.PikaBackup
  org.onlyoffice.desktopeditors
  com.github.iwalton3.jellyfin-media-player
  com.mattjakeman.ExtensionManager
  ca.desrt.dconf-editor
)

# Fonts
NERD_FONTS=("FiraCode" "FiraMono" "JetBrainsMono" "3270")

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

check_not_root() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script must be run as a NORMAL USER, not root.${NC}"
    echo "The script will use 'sudo' internally for system tasks."
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Installation Functions
# -----------------------------------------------------------------------------

system_updates() {
  log "Starting System Updates..."
  sudo dnf upgrade -y
  success "System updates complete."
}

install_packages() {
  log "Installing RPM Fusion and CLI packages..."
  # Install Repos first
  sudo dnf install -y "${RPM_FUSION_URLS[@]}"
  # Install Packages
  sudo dnf install -y "${CLI_PKGS[@]}"
  success "RPM packages installed."
}

setup_multimedia() {
  log "Configuring Multimedia (Codecs, FFmpeg, OpenH264)..."

  # OpenH264
  #sudo dnf config-manager --set-enabled fedora-cisco-openh264 -- no longer valid
  sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

  # FFmpeg (Swapping free for full version)
  sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing

  # Multimedia Group
  sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

  # Intel Drivers (New)
  sudo dnf install -y intel-media-driver

  success "Multimedia setup complete."
}

setup_local_dirs() {
  log "Creating local directory structure..."
  mkdir -p "$HOME/.local/bin"
  mkdir -p "$HOME/.local/share/applications"
  mkdir -p "$HOME/.local/share/fonts"
  success "Directories created."
}

install_kitty() {
  log "Installing Kitty Terminal..."
  if command -v kitty &>/dev/null; then
    warn "Kitty is already installed."
  else
    # Install to local user
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

    # Symlinks
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/"

    # Desktop Integration
    cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" "$HOME/.local/share/applications/"
    cp "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" "$HOME/.local/share/applications/"

    # Fix Icon Paths
    sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "$HOME/.local/share/applications/kitty*.desktop"
    sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" "$HOME/.local/share/applications/kitty*.desktop"

    success "Kitty installed."
  fi
}

install_chezmoi() {
  log "Installing Chezmoi..."
  if command -v chezmoi &>/dev/null; then
    warn "Chezmoi is already installed."
  else
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    success "Chezmoi installed."
  fi
}

install_starship() {
  log "Installing Starship Prompt..."
  if command -v starship &>/dev/null; then
    warn "Starship is already installed."
  else
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    success "Starship installed."
  fi
}

install_flatpaks() {
  log "Setting up Flatpaks..."

  # Ensure Flathub is added (Fedora sometimes filters it)
  flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo

  # Install apps (User scope preferred for personal dev machines)
  flatpak install --user -y flathub "${FLATPAK_APPS[@]}"

  success "Flatpaks installed."
}

install_fonts() {
  log "Installing Nerd Fonts..."
  local font_dir="$HOME/.local/share/fonts"

  for font in "${NERD_FONTS[@]}"; do
    if ls "$font_dir/$font"/*.ttf &>/dev/null; then
      warn "Font $font already exists. Skipping."
    else
      log "Downloading $font..."
      wget -q --show-progress "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/$font.zip" -P /tmp
      unzip -q -o "/tmp/$font.zip" -d "$font_dir/$font/"
      rm "/tmp/$font.zip"
    fi
  done

  fc-cache -f
  success "Fonts installed."
}

cleanup_gnome() {
  log "Cleaning up bloatware..."
  sudo dnf remove -y gnome-connections gnome-tour gnome-boxes gnome-maps libreoffice*
  sudo dnf autoremove -y
  success "Cleanup complete."
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

check_not_root
sudo -v
setup_local_dirs

# System Stuff (Will ask for Sudo)
system_updates
install_packages
setup_multimedia
cleanup_gnome

# User Stuff (No Sudo)
install_kitty
install_chezmoi
install_starship
install_flatpaks
install_fonts

echo ""
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${GREEN}   Installation Complete! Please Restart.       ${NC}"
echo -e "${GREEN}------------------------------------------------${NC}"
