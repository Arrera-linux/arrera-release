# ==============================================================================
# Arrera Linux - Kickstart autonome basé sur Fedora Workstation
# ==============================================================================

# --------------------------------------------------------------------------
# Configuration générale
# --------------------------------------------------------------------------

lang fr_FR.UTF-8
keyboard fr
timezone Europe/Paris --utc

network --bootproto=dhcp --device=link --activate
network --hostname=arrera-linux

# Compte utilisateur
rootpw --lock
user --name=arrera --groups=wheel --plaintext --password=arrera

# Mode graphique
graphical

# --------------------------------------------------------------------------
# Dépôts
# --------------------------------------------------------------------------

url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/$basearch/os/"

# --------------------------------------------------------------------------
# Partitionnement
# --------------------------------------------------------------------------

zerombr
clearpart --all --initlabel
autopart --type=plain

# --------------------------------------------------------------------------
# Services
# --------------------------------------------------------------------------

services --enabled=NetworkManager,gdm,firewalld

# --------------------------------------------------------------------------
# Paquets
# --------------------------------------------------------------------------

%packages --ignoremissing

@^workstation-product-environment

# Noyau et démarrage
kernel
dracut-live
grub2-efi-x64
shim-x64

# Outils système
sudo
vim-enhanced
nano
git
curl
wget
rsync
tar
unzip
gzip
bzip2
 htop
fastfetch

# Python et Qt
python3
python3-pip
qt5-qtbase

# Extensions GNOME
gnome-shell-extension-appindicator
gnome-shell-extension-forge
gnome-shell-extension-gpaste
gnome-tweaks

# Identité visuelle
chafa
ImageMagick
plymouth
plymouth-plugin-script

# Audio, vidéo et réseau
pipewire
pipewire-pulseaudio
wireplumber
NetworkManager-wifi
firewalld

%end

# --------------------------------------------------------------------------
# Configuration après installation
# --------------------------------------------------------------------------

%post --log=/root/arrera-post-install.log
set -eux

echo "=========================================="
echo " DÉBUT DE LA CONFIGURATION ARRERA LINUX  "
echo "=========================================="

# Configuration sudo
echo "arrera ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arrera
chmod 0440 /etc/sudoers.d/arrera

# Activation des services
systemctl enable NetworkManager
systemctl enable gdm
systemctl enable firewalld

# Création du dossier Arrera
mkdir -p /opt/arrera

# Le contenu de setup-dev-env.sh sera inséré ici
cat > /opt/setup-dev-env.sh <<'SETUP_SCRIPT_EOF'
__SETUP_DEV_ENV__
SETUP_SCRIPT_EOF

chmod +x /opt/setup-dev-env.sh

# Exécution du script de configuration
/opt/setup-dev-env.sh

# Nettoyage
rm -f /opt/setup-dev-env.sh

echo "=========================================="
echo " FIN DE LA CONFIGURATION ARRERA LINUX    "
echo "=========================================="

%end