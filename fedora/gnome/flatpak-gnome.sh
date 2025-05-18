#! /bin/bash

#install these basic flatpak apps
# packages variables
obsidian='md.obsidian.Obsidian'
zen='app.zen_browser.zen'
flatseal='com.github.tchx84.Flatseal'
stremio='com.stremio.Stremio'
bottles='com.usebottles.bottles'
warehouse='io.github.flattool.Warehouse'
pikabk='org.gnome.World.PikaBackup'
onlyoffice='org.onlyoffice.desktopeditors'
jellyfinMediaPlayer='com.github.iwalton3.jellyfin-media-player'
extension='com.mattjakeman.ExtensionManager '
dconf='ca.desrt.dconf-editor'

install_basic() {
flatpak install flathub -y $obsidian $zen $flatseal $stremio $bottles $pikabk $jellyfinMediaPlayer $extension $dconf
}

#remove_flatpaks() {
#	flatpak uninstall --unused -y $zen $flatseal $stremio $bottles $pikabk $jellyfinMediaPlayer $extension $dconf
#}
#remove_flatpaks

install_basic


#flatpak install -y com.jgraph.drawio.desktop com.usebottles.bottles md.obsidian.Obsidian org.onlyoffice.desktopeditors org.qbittorrent.qbittorrent ca.desrt.dconf-editor com.github.iwalton3.jellyfin-media-player com.github.tchx84.Flatseal com.ktechpit.colorwall com.mattjakeman.ExtensionManager com.stremio.Stremio org.gnome.World.PikaBackup io.github.alainm23.planify com.rafaelmardojai.Blanket

# org.telegram.desktop us.zoom.zoom



