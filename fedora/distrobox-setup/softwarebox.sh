#!/usr/bin/env bash

sudo dnf upgrade -y

# installing calibre
sudo dnf install libglvnd-opengl xcb-util xcb-util-cursor python3-pyqt6 qt6-qtwebengine xdg-icons

# install cmatrix
sudo dnf install cmatrix
