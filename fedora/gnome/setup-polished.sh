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

# DNF Packages (Host System Utilities only)
# Removed: dev tools. Kept: virtualization, system monitors, terminal tools.
CLI_PKGS=(
  gh distrobox @virtualization
  neovim lsd btop fzf fastfetch
  mpv keepassxc bat qbittorrent
  gnome-tweaks unzip tealdeer chezmoi
)

# Flatpak Packages (GUI Apps)
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

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

check_not_root() {
  if [[ $EUID -eq 0 ]]; then
    error "Run as NORMAL USER. The script uses 'sudo' internally."
  fi
}

# Smart Directory Creation
ensure_dir() {
  local target="$1"
  if [[ -d "$target" ]]; then
    # Silent success or verbose log depending on preference.
    # Comment out the next line if you want total silence for existing dirs.
    log "Directory exists: $target"
    return 0
  else
    mkdir -p "$target"
    success "Created directory: $target"
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

setup_rpm_fusion() {
  log "Configuring RPM Fusion..."
  # Check if repo file exists to avoid costly network hit/error
  if rpm -q rpmfusion-free-release &>/dev/null; then
    warn "RPM Fusion is already installed. Skipping."
  else
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
    sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
    success "RPM Fusion installed."
  fi
}

install_packages() {
  log "Installing Host Packages..."
  sudo dnf install -y "${CLI_PKGS[@]}"
  success "Host packages installed."
}

setup_multimedia() {
  log "Configuring Multimedia..."

  # Cisco OpenH264
  sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

  # FFmpeg (Handle swap gracefully)
  if rpm -q ffmpeg-free &>/dev/null; then
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
  else
    sudo dnf install -y ffmpeg
  fi

  # Multimedia Group (excluding buggy plugins)
  sudo dnf update -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

  # Hardware Acceleration (Intel)
  sudo dnf install -y intel-media-driver libva-intel-driver

  success "Multimedia setup complete."
}

setup_virtualization() {
  log "Configuring Virtualization permissions..."

  # Ensure libvirt service is enabled
  if ! systemctl is-active --quiet libvirtd; then
    sudo systemctl enable --now libvirtd
  fi

  # Add user to libvirt group
  if groups "$USER" | grep &>/dev/null 'libvirt'; then
    log "User is already in libvirt group."
  else
    sudo usermod -aG libvirt "$USER"
    success "User added to libvirt group."
  fi
}

setup_local_env() {
  log "Setting up local directories..."
  ensure_dir "$HOME/.local/bin"
  ensure_dir "$HOME/.local/share/applications"
  ensure_dir "$HOME/.local/share/fonts"
}

install_kitty() {
  log "Checking Kitty Terminal..."
  if command -v kitty &>/dev/null; then
    warn "Kitty is already installed. Skipping."
    return
  fi

  log "Installing Kitty..."
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

  # Symlinks (Force overwrite with -sf to ensure they point to the right place)
  ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/"
  ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/"

  # Desktop Integration
  cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" "$HOME/.local/share/applications/"
  cp "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" "$HOME/.local/share/applications/"

  # Fix Icon/Exec Paths
  sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" "$HOME/.local/share/applications/kitty*.desktop"
  sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" "$HOME/.local/share/applications/kitty*.desktop"

  success "Kitty installed."
}

install_chezmoi_starship() {
  # Chezmoi
  #if command -v chezmoi &>/dev/null; then
  #  warn "Chezmoi already installed."
  #else
  #  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  #  success "Chezmoi installed."
  #fi

  # Starship
  if command -v starship &>/dev/null; then
    warn "Starship already installed."
  else
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    success "Starship installed."
  fi
}

install_flatpaks() {
  log "Processing Flatpaks..."

  # Add Remote
  if ! flatpak remote-list | grep -q "flathub"; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  # Install
  # We use 'flatpak install' which handles "already installed" gracefully,
  # but checking first is faster for the whole list.
  flatpak install flathub -y "${FLATPAK_APPS[@]}"

  success "Flatpaks processed."
}

install_fonts() {
  log "Checking Fonts..."
  local font_dir="$HOME/.local/share/fonts"
  local new_fonts_installed=false

  for font in "${NERD_FONTS[@]}"; do
    if ls "$font_dir/$font"/*.ttf &>/dev/null; then
      # Skipping log to reduce noise, uncomment if needed
      # log "Font $font exists."
      continue
    else
      log "Downloading $font..."
      wget -q --show-progress "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/$font.zip" -P /tmp
      ensure_dir "$font_dir/$font"
      unzip -q -o "/tmp/$font.zip" -d "$font_dir/$font/"
      rm "/tmp/$font.zip"
      new_fonts_installed=true
    fi
  done

  if [ "$new_fonts_installed" = true ]; then
    fc-cache -f
    success "New fonts installed and cached."
  else
    success "All fonts were already present."
  fi
}

cleanup_gnome() {
  log "Running cleanup..."
  # Only remove if they are actually present to avoid 'package not found' warnings
  local bloat=(gnome-connections gnome-tour gnome-boxes gnome-maps libreoffice*)

  for pkg in "${bloat[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
      sudo dnf remove -y "$pkg"
      success "Removed $pkg"
    fi
  done
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

check_not_root
sudo -v
setup_local_env

# Host System Configuration
system_updates
setup_rpm_fusion
install_packages
setup_multimedia
setup_virtualization

# User Apps & Configs
install_kitty
install_chezmoi_starship
install_flatpaks
install_fonts
cleanup_gnome

echo ""
echo -e "${GREEN}------------------------------------------------${NC}"
echo -e "${GREEN}   Host Setup Complete!                         ${NC}"
echo -e "${GREEN}   Now use Distrobox for your dev work:         ${NC}"
echo -e "${BLUE}   distrobox create -n angular-dev -i fedora:40 ${NC}"
echo -e "${GREEN}------------------------------------------------${NC}"
