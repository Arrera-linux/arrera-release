#!/bin/bash

# ==============================================================================
# Script de configuration : Environnement de développement Arrera Linux V2
# ==============================================================================

# Vérification des privilèges root (nécessaire pour écrire dans /etc)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Veuillez exécuter ce script en tant que root (ex: sudo ./setup-dev-env.sh)"
  exit 1
fi

echo "=========================================="
echo " Configuration de l'environnement de dev  "
echo " Arrera Linux                             "
echo "=========================================="

REPO_DIR=$(pwd)
ASSET_DIR="$REPO_DIR/assets"

# 1. Configuration de l'identité du système
echo "[1/7] Mise à jour de /etc/os-release..."
cat <<EOF > /etc/os-release
NAME="Arrera"
VERSION="2026 (Blue-dev)"
RELEASE_TYPE="0.0 (Dev)"
ID=arrera
ID_LIKE=fedora
VERSION_ID=1
VERSION_CODENAME="Blue-dev"
PRETTY_NAME="Arrera Blue 2027"
ANSI_COLOR="0;38;2;60;110;180"
LOGO="arrera-logo"
CPE_NAME="cpe:/o:fedoraproject:fedora:44"
DEFAULT_HOSTNAME="arrera-blue"
HOME_URL="https://fedoraproject.org/"
DOCUMENTATION_URL="https://docs.fedoraproject.org/en-US/fedora/f44/"
SUPPORT_URL="https://ask.fedoraproject.org/"
BUG_REPORT_URL="https://bugzilla.redhat.com/"
REDHAT_BUGZILLA_PRODUCT="Fedora"
REDHAT_BUGZILLA_PRODUCT_VERSION=44
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=44
SUPPORT_END=2027-05-19
VARIANT="Workstation Edition"
VARIANT_ID=workstation
EOF

# 2. Création du fichier de release et des liens symboliques
echo "[2/7] Création de /etc/arrera-release et des liens de compatibilité..."
echo "Arrera release 0.0 (Blue-Dev)" > /etc/arrera-release

# On supprime les anciens fichiers s'ils existent et on crée les liens symboliques
for release_file in fedora-release system-release redhat-release; do
    if [ -f "/etc/$release_file" ] || [ -L "/etc/$release_file" ]; then
        rm -f "/etc/$release_file"
    fi
    ln -s /etc/arrera-release "/etc/$release_file"
done

# 3. Modification du gestionnaire de démarrage GRUB
echo "[3/7] Configuration du menu de démarrage GRUB..."
sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Arrera Linux"/' /etc/default/grub

# 4. Installation des assets locaux et configuration Fastfetch
echo "[4/7] Installation des assets visuels et configuration Fastfetch..."

# Installation du logo système depuis le dossier local
if [ -f "$ASSET_DIR/arrera-logo.png" ]; then
    mkdir -p /usr/share/icons/hicolor/512x512/apps/
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/icons/hicolor/512x512/apps/
    gtk-update-icon-cache /usr/share/icons/hicolor/
fi

# Installation de Fastfetch (JSON et logo ASCII)
if [ -d "$REPO_DIR/configs" ]; then
    mkdir -p /etc/fastfetch
    if [ -f "$REPO_DIR/configs/fastfetch-config.jsonc" ]; then
        cp "$REPO_DIR/configs/fastfetch-config.jsonc" /etc/fastfetch/config.jsonc
    fi
    if [ -f "$REPO_DIR/configs/arrera-logo.txt" ]; then
        cp "$REPO_DIR/configs/arrera-logo.txt" /etc/fastfetch/arrera-logo.txt
    fi
fi

# 5. Configuration de l'écran de démarrage (Plymouth)
echo "[5/7] Configuration du thème Plymouth..."
mkdir -p /usr/share/plymouth/themes/arrera/

# Fichiers de configuration Plymouth
if [ -d "$REPO_DIR/configs/plymouth" ]; then
    cp "$REPO_DIR/configs/plymouth/arrera.plymouth" /usr/share/plymouth/themes/arrera/
    cp "$REPO_DIR/configs/plymouth/arrera.script" /usr/share/plymouth/themes/arrera/
fi

# Récupération de l'animation Fedora (Spinner) depuis le système
cp /usr/share/plymouth/themes/spinner/throbber-*.png /usr/share/plymouth/themes/arrera/

# Installation du logo Plymouth local
if [ -f "$ASSET_DIR/logo.png" ]; then
    cp "$ASSET_DIR/logo.png" /usr/share/plymouth/themes/arrera/
fi

# Application de Plymouth et reconstruction de l'initramfs
plymouth-set-default-theme -R arrera

# 6. Configuration de l'écran de connexion (GDM)
echo "[6/7] Configuration de GDM..."
mkdir -p /etc/dconf/db/gdm.d/

# Règle dconf pour GDM
if [ -f "$REPO_DIR/configs/99-arrera-login" ]; then
    cp "$REPO_DIR/configs/99-arrera-login" /etc/dconf/db/gdm.d/
fi

# Logo GDM blanc local
if [ -f "$ASSET_DIR/arrera_gdm_logo_white.png" ]; then
    cp "$ASSET_DIR/arrera_gdm_logo_white.png" /usr/share/pixmaps/
fi

dconf update

# Régénération finale de GRUB
echo "Régénération de grub.cfg..."
grub2-mkconfig -o /boot/grub2/grub.cfg

# 7. Désactivation des pop-ups GPaste
echo "[7/7] Configuration des paramètres utilisateur GNOME..."
if [ -n "$SUDO_USER" ]; then
    su - "$SUDO_USER" -c "
        gsettings set org.gnome.GPaste.keybindings launch-ui ''
        gsettings set org.gnome.GPaste.keybindings pop-from-history ''
        gsettings set org.gnome.GPaste.keybindings show-history ''
        gsettings set org.gnome.GPaste.keybindings sync-clipboard-to-primary ''
        gsettings set org.gnome.GPaste.keybindings sync-primary-to-clipboard ''
        gsettings set org.gnome.GPaste.keybindings upload-to-pastebin ''
        gsettings set org.gnome.GPaste.keybindings convert-to-password ''
    "
fi

echo "=========================================="
echo " Terminé ! L'environnement est configuré. "
echo "=========================================="