#! /bin/bash
echo "Welcome to the initial setup script"

#update the system with latest package
sudo apt update && sudo apt upgrade

echo "Remove Libre Office"

#remove Libre Office packages
sudo apt-get remove --purge libreoffice*
sudo apt-get clean
sudo apt-get autoremove

echo "Libre Office removed"
echo ""
echo "Now Installling nala and exa"

#install nala and exa
sudo apt install nala && sudo nala install exa 

echo "nala and exa installed"
echo ""

echo "Now installing kitty"

mkdir -p $HOME/.local/bin
ls .local

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

# set kitty as default terminal
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator $HOME/.local/bin/kitty 50
sudo update-alternatives --config x-terminal-emulator

echo "done with kitty"
echo ""

#install starship prompt
curl -sS https://starship.rs/install.sh | sh && echo 'eval "$(starship init bash)"' >> ~/.bashrc

#install 'n' for nodejs version manager
curl -L https://bit.ly/n-install | bash 





