setup_yazi() {
local v='25.4.8'

mkdir -p Downloads/binaries/

wget -q "https://github.com/sxyazi/yazi/releases/download/v$v/yazi-x86_64-unknown-linux-gnu.zip" -P ~/Downloads/binaries/
sudo unzip -q ~/Downloads/binaries/yazi-x86_64-unknown-linux-gnu.zip -d /opt/
ln -s 

}

setup_zellij() {
local v=''

mkdir -p Downloads/binaries/

wget -q "" -P ~/Downloads/binaries/
sudo unzip -q ~/Downloads/binaries/.zip -d /opt/

ln -s 

}

setup_yazi
setup_zellij
