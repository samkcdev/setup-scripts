#!/usr/bin/env bash

sudo dnf upgrade -y

# installing calibre
sudo dnf install -y libglvnd-opengl xcb-util xcb-util-cursor python3-pyqt6 qt6-qtwebengine xdg-utils cmatrix vim

sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin

echo "installation done"



