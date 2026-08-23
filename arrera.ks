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

# Arrêt automatique après installation (évite qu'Anaconda reste bloqué)
poweroff

lang fr_FR.UTF-8
keyboard fr
timezone Europe/Paris --utc

network --bootproto=dhcp --device=link --activate
network --hostname=arrera-linux

# Compte utilisateur
rootpw --lock
user --name=arrera --groups=wheel --plaintext --password=arrera
selinux --permissive


# --------------------------------------------------------------------------
# Dépôts
# --------------------------------------------------------------------------

url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/$basearch/os/"

# Partitionnement (taille fixe requise par livemedia-creator --no-virt)
zerombr
clearpart --all --initlabel
part / --size=10240 --fstype=ext4

# --------------------------------------------------------------------------
# Services
# --------------------------------------------------------------------------

services --enabled=NetworkManager,gdm,firewalld

# --------------------------------------------------------------------------
# Paquets
# --------------------------------------------------------------------------

%packages --ignoremissing

# === Base système ===
@core
@hardware-support

# Noyau et démarrage
kernel
dracut-live
grub2-efi-x64
grub2-efi-x64-cdboot
grub2-efi-x64-modules
shim-x64
grub2-pc-modules
grub2-tools
efibootmgr

# === Bureau GNOME minimal ===
gnome-shell
gnome-session
gnome-settings-daemon
gnome-control-center
mutter
gdm
gnome-keyring
xdg-user-dirs
xdg-desktop-portal-gnome
dbus

# === Applications demandées ===
nautilus
firefox
gnome-tweaks
gnome-extensions-app
gnome-text-editor
gnome-disk-utility
loupe
evince
gnome-calendar
gnome-clocks
ptyxis

# === Extensions GNOME ===
gnome-shell-extension-appindicator
gnome-shell-extension-forge
gnome-shell-extension-gpaste

# === Outils système ===
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
bash-completion

# Python et Qt
python3
python3-pip
qt5-qtbase

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

# Polices (évite un bureau sans texte lisible)
google-noto-sans-fonts
google-noto-sans-mono-fonts
dejavu-sans-fonts

# === Installateur (pour "Installer sur le disque dur") ===
anaconda
anaconda-install-env-deps
anaconda-live
liveinst

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

# Forcer le démarrage en mode graphique (sinon GDM ne se lance pas)
systemctl set-default graphical.target

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

# ================================================================
# Configuration de la session Live (auto-login + installateur)
# ================================================================

# Auto-login GDM pour la session Live (pas de mot de passe demandé)
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'GDM_EOF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=arrera

[security]

[xdmcp]

[chooser]

[debug]
GDM_EOF

# Raccourci "Installer Arrera Linux" sur le bureau
mkdir -p /home/arrera/Bureau
cat > /home/arrera/Bureau/install-arrera.desktop <<'DESKTOP_EOF'
[Desktop Entry]
Name=Installer Arrera Linux
Name[en]=Install Arrera Linux
Comment=Installer Arrera Linux sur le disque dur
Exec=/usr/bin/liveinst
Icon=anaconda
Terminal=false
Type=Application
Categories=System;GTK;
StartupNotify=true
DESKTOP_EOF
chmod +x /home/arrera/Bureau/install-arrera.desktop
chown -R arrera:arrera /home/arrera/Bureau

# Aussi dans /usr/share/applications pour le menu
cp /home/arrera/Bureau/install-arrera.desktop /usr/share/applications/install-arrera.desktop

# Marquer le .desktop comme fiable (GNOME 44+)
mkdir -p /home/arrera/.local/share
chown -R arrera:arrera /home/arrera/.local

echo "=========================================="
echo " FIN DE LA CONFIGURATION ARRERA LINUX    "
echo "=========================================="

%end