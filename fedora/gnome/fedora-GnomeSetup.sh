#! /bin/bash

update_system_packages() {
echo "System updates Starts"
echo ""
sudo dnf upgrade -y 
echo ""
echo "System updates Complete"
}

install_packages() {
echo "Installing necessary packages"
sudo dnf install -y gh lsd neovim btop fzf fastfetch mpv distrobox keepassxc bat qbittorrent gnome-tweaks @virtualization
echo "Finished Installing packages"
}

install_free_nonfree_repositories() {
echo "Installing free and Non free repos"
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

}
install_openh264_library() {
echo "Installing open264 library"
		sudo dnf -y config-manager setopt fedora-cisco-openh264.enabled=1
echo "Done"
}

install_ffmpeg() {
echo "Installing ffmpeg"
		sudo dnf -y swap ffmpeg-free ffmpeg --allowerasing
echo "Done"
}

install_additional_codec() {
echo "installing addiotional multimedia codecs"
		sudo dnf -y update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
echo "Done"
}

install_hardware_accelerated_codec_intel_new() {
echo "hwa intel new"
		sudo dnf -y install intel-media-driver
}

install_hardware_accelerated_codec_intel_older(){
echo "hwa intel older"
sudo dnf install libva-intel-driver
}

# synchthing available in fedora repo is outdated
# so download from their website

##
echo "Now lets install Kitty, Chezmoi and starship"


#start creating the bin folder in .local

setup_local_dirs(){
local local_bin="$HOME/.local/bin/"
local local_applications="$HOME/.local/share/applications/"

if [[ ! -d $local_bin ]]; then
	mkdir -p $local_bin
	echo ".local/bin created"
else
		echo "Directory already exists"
fi

if [[ ! -d $local_applications ]]; then
		mkdir -p $local_applications
		echo ".local/share/applications created"
else
		echo "Directory already exists"
fi

}



install_kitty() {

		echo "Starting Kitty terminal installations"
#install kitty terminal
curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin

# Create symbolic links to add kitty and kitten to PATH (assuming ~/.local/bin is in
# your system-wide PATH)
ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten $HOME/.local/bin/

# Place the kitty.desktop file somewhere it can be found by the OS
cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/

# If you want to open text files and images in kitty via your file manager also add the kitty-open.desktop file
cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/

# Update the paths to the kitty and its icon in the kitty.desktop file(s)
sed -i "s|Icon=kitty|Icon=/home/$USER/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop
sed -i "s|Exec=kitty|Exec=/home/$USER/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop
		echo "Done"
}

install_chezmoi() {
echo "Installing Chezmoi"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
echo "Chezmoi Installed"
}

install_starship() {
echo "installing starship prompt"
#install starship prompt
curl -sS https://starship.rs/install.sh | sh 
}

install_flatpak_apps() {
echo "Installing flatpak applications"
# packages variables
local obsidian='md.obsidian.Obsidian'
local zen='app.zen_browser.zen'
local flatseal='com.github.tchx84.Flatseal'
local stremio='com.stremio.Stremio'
local bottles='com.usebottles.bottles'
local pikabk='org.gnome.World.PikaBackup'
#local onlyoffice='org.onlyoffice.desktopeditors'
local jellyfinMediaPlayer='com.github.iwalton3.jellyfin-media-player'
local extension='com.mattjakeman.ExtensionManager '
local dconf='ca.desrt.dconf-editor'

flatpak install -y $obsidian $zen $flatseal $stremio $bottles $pikabk $jellyfinMediaPlayer $extension $dconf

echo "Flatpak apps Installation Done"
}

install_nerd_fonts() {
echo "Installing fonts"

mkdir -p $HOME/.local/share/fonts/

fonts=( "FiraCode" "FiraMono" "JetBrainsMono" "3270" "0xProto" )

for font in "${fonts[@]}"; do
		if ls $HOME/.local/share/fonts/$font/*.ttf &>/dev/null; then
				echo "Font $font is already installed. Skipping"
		else
				echo "Installing font: $font"
				wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/$font.zip" -P /tmp || {
						echo "Warning: Error downloading font $font"
						continue
				}
				unzip -q /tmp/$font.zip -d $HOME/.local/share/fonts/$font/ || {
						echo "Warning:Error extracting font $font."
						continue
		}
		rm /tmp/$font.zip
		fi
done

fc-cache -f || {echo "Warning: Error rebuilding font cache"}

echo "Font installation completed"

}

remove_packages() {
		echo "removing useless gnome packages"
		sudo dnf remove -y gnome-connections gnome-tour gnome-boxes gnome-maps rhythmbox 
		echo "removed"
		echo ""
		echo "Cleaning Up unwanted hanging packages"
		sudo dnf autoremove -y
		echo "Auto remove done"
}



update_system_packages
install_packages
install_free_nonfree_repositories
install_openh264_library
install_ffmpeg
install_additional_codec
install_hardware_accelerated_codec_intel_new
install_nerd_fonts
setup_local_dirs
install_kitty
install_chezmoi
install_starship
install_flatpak_apps
remove_packages


