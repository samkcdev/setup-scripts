#! /bin/bash

# update the system
##
update_system_packages() {
echo "System updates.."
echo ""
sudo dnf upgrade -y 
}

install_packages() {
echo "Installing necessary packages"
sudo dnf install -y gh lsd neovim btop fzf fastfetch distrobox keepassxc bat nautilus evince flatpak power-profiles-daemon SwayNotificationCenter gnome-calculator qbittorrent @virtualization
}
remove_packages() {
		dnf remove -y dunst 
}

install_free_nonfree_repositories() {
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

}
install_openh264_library() {
		sudo dnf -y config-manager setopt fedora-cisco-openh264.enabled=1
}

install_ffmpeg() {
		sudo dnf -y swap ffmpeg-free ffmpeg --allowerasing
}

install_additional_codec() {
		sudo dnf -y update @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
}

install_hardware_accelerated_codec_intel() {
		sudo dnf install intel-media-driver
}

# synchthing available in fedora repo is outdated
# so download from their website

##
echo "Now lets install Kitty, Chezmoi and starship"


#start creating the bin folder in .local

setup_local_dirs(){
echo "Local folder creations"

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

}

install_starship() {
echo "installing starship prompt"
#install starship prompt
curl -sS https://starship.rs/install.sh | sh 
}


update_system_packages
install_packages
install_free_nonfree_repositories
install_openh264_library
install_ffmpeg
install_additional_codec
setup_local_dirs
install_kitty
install_starship





