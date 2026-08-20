# ==============================================================================
# Arrera Linux - Kickstart autonome basé sur Fedora Workstation
# ==============================================================================
# IMPORTANT : Ce fichier est un TEMPLATE.
# Le script build_iso.sh remplace les placeholders par le contenu réel
# de setup-dev-env.sh et des assets, puis génère le .ks final.
# NE PAS utiliser ce fichier directement avec livemedia-creator.
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

# Création du dossier Arrera pour les assets
mkdir -p /opt/arrera/asset
mkdir -p /opt/arrera/configs/plymouth

# --- DÉBUT : Assets encodés en base64 (injectés par build_iso.sh) ---
__ASSETS_BASE64__
# --- FIN : Assets encodés en base64 ---

# Le contenu du script de setup est injecté ci-dessous par build_iso.sh
cat > /opt/arrera/setup-dev-env.sh <<'SETUP_SCRIPT_EOF'
__SETUP_DEV_ENV__
SETUP_SCRIPT_EOF

chmod +x /opt/arrera/setup-dev-env.sh

# Exécution du script de configuration avec le bon répertoire racine
export ARRERA_ROOT="/opt/arrera"
/opt/arrera/setup-dev-env.sh

# Nettoyage
rm -rf /opt/arrera

echo "=========================================="
echo " FIN DE LA CONFIGURATION ARRERA LINUX    "
echo "=========================================="

%end