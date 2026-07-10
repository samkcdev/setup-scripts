#!/usr/bin/env bash
# ==============================================================================
# Fedora Post-Install Setup Script
# Author: Sam
# Description: Idempotent system configuration for a fresh Fedora installation.
# Usage: ./setup.sh
# ==============================================================================
# SECURITY NOTE: This script uses `curl | sh` for Kitty, Chezmoi, and Starship.
# This is a widely accepted pattern for their official installers.
# If you're security-conscious, download, inspect, then execute manually.
# ==============================================================================

# ------------------------------------------------------------------------------
# Strict Mode
# 'set -e'           → Exit immediately if any command fails
# 'set -u'           → Treat unset variables as errors
# 'set -o pipefail'  → If any command in a pipeline fails, the pipeline fails
#                      Without this: 'false | true' would return 0 (success)
# ------------------------------------------------------------------------------
set -euo pipefail

# ------------------------------------------------------------------------------
# Script Metadata
# ------------------------------------------------------------------------------
readonly SCRIPT_VERSION="1.2.0"
readonly SCRIPT_START_TIME=$(date +%s)
# Log file in /tmp — cleared on reboot, safe for setup logs
readonly LOG_FILE="/tmp/fedora-setup-$(date +%Y%m%d-%H%M%S).log"

# ------------------------------------------------------------------------------
# Colors — only enable if we're in an interactive terminal (tty)
# This prevents escape codes from littering log files if output is redirected
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  BLUE='\033[0;34m'
  YELLOW='\033[1;33m'
  RED='\033[0;31m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN='' BLUE='' YELLOW='' RED='' BOLD='' NC=''
fi

# ------------------------------------------------------------------------------
# Package Lists
# ------------------------------------------------------------------------------

# DNF: Host-level CLI and system utilities
# Principle: Keep this minimal. Dev tools go into Distrobox containers.
CLI_PKGS=(
  gh            # GitHub CLI — for repo management from terminal
  distrobox     # Container-based dev environments (your dev tools live here)
  "@virtualization" # KVM/QEMU/libvirt group — virtual machines
  neovim        # Modal text editor
  lsd           # Modern 'ls' replacement with icons
  btop          # Resource monitor (better than htop)
  fzf           # Fuzzy finder — transforms your terminal workflow
  fastfetch     # System info display (neofetch successor)
  mpv           # Minimal, scriptable media player
  keepassxc     # Local password manager
  bat           # 'cat' with syntax highlighting and line numbers
  qbittorrent   # BitTorrent client
  gnome-tweaks  # GNOME customisation (hidden settings)
  unzip         # Archive extraction — needed for fonts
  tealdeer      # Fast 'tldr' client — simplified man pages
  curl          # Ensure curl is present (used throughout this script)
  wget          # Used for font downloads
)

# Flatpak: GUI applications (sandboxed, distribution-agnostic)
FLATPAK_APPS=(
  md.obsidian.Obsidian                    # Note-taking / second brain
  app.zen_browser.zen                     # Firefox-based privacy browser
  com.github.tchx84.Flatseal             # Flatpak permissions manager
  com.stremio.Stremio                     # Media streaming hub
  com.usebottles.bottles                  # Wine manager for Windows apps
  org.gnome.World.PikaBackup             # GNOME backup tool (Borg-based)
  org.onlyoffice.desktopeditors          # MS Office-compatible office suite
  com.github.iwalton3.jellyfin-media-player # Jellyfin desktop client
  com.mattjakeman.ExtensionManager       # GNOME Shell Extension manager
  ca.desrt.dconf-editor                  # Low-level GNOME settings editor
)

# Nerd Fonts: Patched fonts with developer icons (used by lsd, nvim, starship)
NERD_FONTS=("FiraCode" "FiraMono" "JetBrainsMono" "3270")
readonly NERD_FONTS_VERSION="v3.3.0"

# Packages to remove — Fedora default bloat we don't need
BLOAT_PKGS=(
  gnome-connections
  gnome-tour
  gnome-boxes    # Replaced by full KVM/virt-manager from @virtualization
  gnome-maps
)

# ==============================================================================
# Utility Functions
# ==============================================================================

# Logging functions — write to both terminal AND log file simultaneously
# 'tee -a' appends to the log file without suppressing terminal output
log()     { echo -e "${BLUE}[INFO]${NC}  $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC}    $1" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }
section() { echo -e "\n${BOLD}${BLUE}==== $1 ====${NC}" | tee -a "$LOG_FILE"; }

# ------------------------------------------------------------------------------
# trap: This runs automatically when the script exits — successfully OR on error.
# Think of it like a 'finally' block in JavaScript try/catch/finally.
# '$?' holds the exit code of the last command. 0 = success, anything else = fail.
# ------------------------------------------------------------------------------
on_exit() {
  local exit_code=$?
  local end_time=$(date +%s)
  local elapsed=$(( end_time - SCRIPT_START_TIME ))
  local minutes=$(( elapsed / 60 ))
  local seconds=$(( elapsed % 60 ))

  echo "" | tee -a "$LOG_FILE"
  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}Script completed successfully in ${minutes}m ${seconds}s.${NC}" | tee -a "$LOG_FILE"
  else
    echo -e "${RED}Script failed (exit code: $exit_code) after ${minutes}m ${seconds}s.${NC}" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}Full log available at: ${LOG_FILE}${NC}"
  fi

  # Kill the sudo keepalive background process (explained below)
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
}
trap on_exit EXIT

# ------------------------------------------------------------------------------
# Sudo Keepalive
# Problem: 'sudo' expires after ~5 min. A 20-30 min setup script will hit this.
# Solution: Spawn a background process that refreshes sudo every 50 seconds.
# 'kill -0 "$$"' checks if the *parent* script ($$) is still alive.
# If the parent dies, the background process exits too — no zombie processes.
# ------------------------------------------------------------------------------
sudo_keepalive() {
  while true; do
    sudo -n true          # Refresh sudo non-interactively
    sleep 50
    kill -0 "$$" || exit  # Exit if parent script is gone
  done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!   # Save PID so on_exit() can clean it up
}

# Ensure directories exist — safe, idempotent
ensure_dir() {
  local target="$1"
  if [[ ! -d "$target" ]]; then
    mkdir -p "$target"
    success "Created directory: $target"
  fi
}

# Check that we're NOT running as root
# Why: The script uses 'sudo' internally so it can escalate only where needed.
# Running as root would mean $HOME might be /root, paths break, and it's unsafe.
check_not_root() {
  if [[ $EUID -eq 0 ]]; then
    error "Do NOT run as root. Run as your normal user — the script uses 'sudo' internally."
  fi
}

# Validate sudo access upfront — fail fast with a clear message
check_sudo() {
  if ! sudo -v 2>/dev/null; then
    error "This script requires sudo privileges. Please ensure your user is in the sudoers file."
  fi
  sudo_keepalive
  success "Sudo access confirmed. Keepalive started (PID: ${SUDO_KEEPALIVE_PID})."
}

# ==============================================================================
# Setup Functions
# ==============================================================================

system_updates() {
  section "System Updates"
  log "Running full system upgrade..."
  sudo dnf upgrade -y
  success "System is up to date."
}

setup_rpm_fusion() {
  section "RPM Fusion Repositories"

  # 'rpm -q' checks if a package is installed — returns 0 if yes, 1 if no
  # We use this to make the step idempotent (safe to run multiple times)
  if rpm -q rpmfusion-free-release &>/dev/null; then
    warn "RPM Fusion already configured. Skipping."
    return 0
  fi

  log "Installing RPM Fusion (Free + Non-Free)..."
  # '$(rpm -E %fedora)' dynamically gets your Fedora version number (e.g., 40)
  sudo dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

  success "RPM Fusion installed."
}

install_packages() {
  section "Host System Packages"
  log "Installing DNF packages..."
  # '--best' ensures the best available versions are installed
  # '--allowerasing' permits replacing conflicting packages if needed
  sudo dnf install -y --best "${CLI_PKGS[@]}"
  success "Host packages installed."
}

setup_multimedia() {
  section "Multimedia Codecs"

  # Enable Cisco's OpenH264 codec (H.264 video decode/encode via patent licence)
  log "Enabling Cisco OpenH264 repository..."
  sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

  # FFmpeg: Fedora ships 'ffmpeg-free' (missing patented codecs).
  # We swap it for the full RPM Fusion build which includes everything.
  log "Configuring FFmpeg..."
  if rpm -q ffmpeg &>/dev/null; then
    warn "Full FFmpeg already installed. Skipping swap."
  elif rpm -q ffmpeg-free &>/dev/null; then
    log "Swapping ffmpeg-free → ffmpeg (full build)..."
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
  else
    log "Installing ffmpeg..."
    sudo dnf install -y ffmpeg
  fi

  # Multimedia group: GStreamer plugins and codec support
  # '--exclude=PackageKit-gstreamer-plugin' skips a plugin that can conflict
  # with DNF while it's running — a known Fedora quirk
  log "Installing multimedia codec group..."
  sudo dnf update -y @multimedia \
    --setopt="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin

  # Intel hardware acceleration drivers (VA-API)
  # These let hardware-accelerated video decoding work in mpv, Firefox, etc.
  log "Installing Intel VA-API drivers..."
  sudo dnf install -y intel-media-driver libva-intel-driver

  success "Multimedia setup complete."
}

setup_virtualization() {
  section "Virtualization"

  # Ensure libvirtd (the virtualisation daemon) is running
  if ! systemctl is-active --quiet libvirtd; then
    log "Starting and enabling libvirtd..."
    sudo systemctl enable --now libvirtd
  else
    log "libvirtd is already active."
  fi

  # '-w' = whole word match — prevents false positives like 'libvirt_qemu'
  # 'id -nG' is more reliable than 'groups' for listing current group memberships
  if id -nG "$USER" | grep -qw 'libvirt'; then
    warn "User '$USER' is already in the libvirt group."
  else
    sudo usermod -aG libvirt "$USER"
    success "User '$USER' added to libvirt group."
    warn "You'll need to log out and back in for group changes to take effect."
  fi
}

setup_local_env() {
  section "Local User Directories"
  # These directories are part of the XDG Base Directory spec —
  # the standard Linux convention for where user files live.
  ensure_dir "$HOME/.local/bin"
  ensure_dir "$HOME/.local/share/applications"
  ensure_dir "$HOME/.local/share/fonts"
  success "Local directories ready."
}

install_kitty() {
  section "Kitty Terminal"

  if command -v kitty &>/dev/null; then
    warn "Kitty already installed at $(command -v kitty). Skipping."
    return 0
  fi

  log "Installing Kitty via official installer..."
  # The installer handles the binary, no package manager needed
  curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

  # Symlinks: Make kitty/kitten available on $PATH via ~/.local/bin
  # '-sf' = force-create symlink, overwriting any stale existing link
  ln -sf "$HOME/.local/kitty.app/bin/kitty"  "$HOME/.local/bin/kitty"
  ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"

  # Desktop integration: Copy .desktop files for GNOME app launcher
  cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" \
     "$HOME/.local/share/applications/"
  cp "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" \
     "$HOME/.local/share/applications/"

  # Fix absolute paths in the .desktop files
  # The installed files use bare 'kitty' references; we need full paths
  # for GNOME to find the binary and icon correctly
  local desktop_files=("$HOME/.local/share/applications/kitty.desktop"
                        "$HOME/.local/share/applications/kitty-open.desktop")
  for f in "${desktop_files[@]}"; do
    [[ -f "$f" ]] || continue
    sed -i \
      -e "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
      -e "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" \
      "$f"
  done

  success "Kitty installed."
}

install_chezmoi_starship() {
  section "Chezmoi & Starship"

  # Chezmoi: Dotfile manager — keeps your configs in a git repo
  if command -v chezmoi &>/dev/null; then
    warn "Chezmoi already installed at $(command -v chezmoi)."
  else
    log "Installing Chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    success "Chezmoi installed."
  fi

  # Starship: Cross-shell prompt — fast, minimal, highly configurable
  if command -v starship &>/dev/null; then
    warn "Starship already installed at $(command -v starship)."
  else
    log "Installing Starship..."
    # '-y' = non-interactive, '-b' = install to this directory
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    success "Starship installed."
  fi
}

install_flatpaks() {
  section "Flatpak Applications"

  # Add Flathub remote if not already configured
  if ! flatpak remote-list --user | grep -q "flathub"; then
    log "Adding Flathub remote..."
    flatpak remote-add --if-not-exists --user flathub \
      https://flathub.org/repo/flathub.flatpakrepo
    success "Flathub remote added."
  else
    warn "Flathub remote already configured."
  fi

  # Install each Flatpak individually so one failure doesn't abort the entire list.
  # '--or-update' installs if missing, updates if already installed — truly idempotent.
  local failed_apps=()
  for app in "${FLATPAK_APPS[@]}"; do
    log "Installing Flatpak: $app"
    if flatpak install flathub --user -y --or-update "$app" 2>>"$LOG_FILE"; then
      success "$app installed/updated."
    else
      warn "Failed to install $app — will retry or install manually later."
      failed_apps+=("$app")
    fi
  done

  # Report any failures at the end — don't bury them in scroll
  if [[ ${#failed_apps[@]} -gt 0 ]]; then
    warn "The following Flatpaks failed to install:"
    for app in "${failed_apps[@]}"; do
      warn "  - $app"
    done
  else
    success "All Flatpaks installed successfully."
  fi
}

install_fonts() {
  section "Nerd Fonts"

  local font_dir="$HOME/.local/share/fonts"
  local new_fonts_installed=false

  for font in "${NERD_FONTS[@]}"; do
    local target_dir="$font_dir/$font"

    # 'find' is safer than 'ls' for checking file existence
    # -maxdepth 1: only look in this directory, not subdirectories
    # -name '*.ttf': look for TrueType font files
    # -print -quit: stop at first match (efficient)
    if find "$target_dir" -maxdepth 1 -name "*.ttf" -print -quit 2>/dev/null | grep -q .; then
      log "Font '$font' already installed. Skipping."
      continue
    fi

    log "Downloading Nerd Font: $font (${NERD_FONTS_VERSION})..."

    local zip_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.zip"
    local zip_path="/tmp/${font}.zip"

    # Download with progress display and fail clearly on error
    if ! curl -L --progress-bar --fail "$zip_url" -o "$zip_path"; then
      warn "Failed to download $font. Skipping."
      continue
    fi

    ensure_dir "$target_dir"

    # '-q' = quiet, '-o' = overwrite existing files without prompting
    if ! unzip -q -o "$zip_path" -d "$target_dir/"; then
      warn "Failed to extract $font. Skipping."
      rm -f "$zip_path"
      continue
    fi

    rm -f "$zip_path"
    new_fonts_installed=true
    success "Font '$font' installed."
  done

  # Rebuild font cache only if we actually installed something new
  # 'fc-cache' is expensive — no point running it unnecessarily
  if [[ "$new_fonts_installed" == true ]]; then
    log "Rebuilding font cache..."
    fc-cache -f
    success "Font cache updated."
  else
    success "All fonts were already present. No cache rebuild needed."
  fi
}

cleanup_gnome() {
  section "Removing GNOME Bloat"

  for pkg in "${BLOAT_PKGS[@]}"; do
    # 'rpm -q' only works for exact package names — not globs.
    # For glob-style removal (e.g., libreoffice*), use dnf with wildcards directly.
    if rpm -q "$pkg" &>/dev/null; then
      log "Removing $pkg..."
      sudo dnf remove -y "$pkg"
      success "Removed: $pkg"
    else
      log "Package '$pkg' not installed. Skipping."
    fi
  done

  # Handle LibreOffice separately — it's a package GROUP, not a single package.
  # 'dnf remove "libreoffice*"' lets DNF handle the glob expansion itself.
  if rpm -qa | grep -q "^libreoffice"; then
    log "Removing LibreOffice suite..."
    sudo dnf remove -y "libreoffice*"
    success "LibreOffice removed."
  else
    log "LibreOffice not installed. Skipping."
  fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
  # Print header
  echo -e "${BOLD}${GREEN}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Fedora Post-Install Setup v${SCRIPT_VERSION}"
  echo "  Log: ${LOG_FILE}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${NC}"

  # Pre-flight checks
  check_not_root
  check_sudo

  # --- Phase 1: Host System ---
  setup_local_env
  system_updates
  setup_rpm_fusion
  install_packages
  setup_multimedia
  setup_virtualization

  # --- Phase 2: User Applications ---
  install_kitty
  install_chezmoi_starship
  install_flatpaks
  install_fonts

  # --- Phase 3: Cleanup ---
  cleanup_gnome

  # Final message
  echo ""
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Host Setup Complete!${NC}"
  echo ""
  echo -e "${BLUE}  Next step — create a dev container:${NC}"
  echo -e "${BOLD}  distrobox create -n dev -i fedora:41${NC}"
  echo ""
  echo -e "${YELLOW}  ⚠  Log out and back in for group changes${NC}"
  echo -e "${YELLOW}     (libvirt) to take effect.${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

main "$@"