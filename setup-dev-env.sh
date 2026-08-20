#!/bin/bash

# ==============================================================================
# Script de configuration : Environnement de développement Arrera Linux V2
# ==============================================================================
# Ce script peut être exécuté :
#   - Manuellement sur un système existant : sudo ./setup-dev-env.sh
#   - Depuis le %post du kickstart : le build_iso.sh l'injecte automatiquement
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

# En mode kickstart, ARRERA_ROOT est défini par le %post.
# En mode manuel, on utilise le répertoire courant.
REPO_DIR="${ARRERA_ROOT:-$(pwd)}"
ASSET_DIR="$REPO_DIR/asset"

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
if [ -f /etc/default/grub ]; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Arrera Linux"/' /etc/default/grub
fi

# 4. Installation des assets locaux et configuration Fastfetch
echo "[4/7] Installation des assets visuels et configuration Fastfetch..."

# Installation du logo système depuis le dossier local
if [ -f "$ASSET_DIR/arrera-logo.png" ]; then
    mkdir -p /usr/share/icons/hicolor/512x512/apps/
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/icons/hicolor/512x512/apps/
    # gtk-update-icon-cache peut échouer dans le chroot, on l'ignore
    gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
fi

# Installation de Fastfetch (JSON et logo ASCII)
if [ -d "$REPO_DIR/configs" ]; then
    mkdir -p /etc/fastfetch
    if [ -f "$REPO_DIR/configs/fastfetch-config.jsonc" ]; then
        cp "$REPO_DIR/configs/fastfetch-config.jsonc" /etc/fastfetch/config.jsonc
    fi
    if [ -f "$REPO_DIR/configs/arrera-logo.txt" ]; then
        # Le fichier de config fastfetch attend /etc/fastfetch/arrera-logo.txt
        cp "$REPO_DIR/configs/arrera-logo.txt" /etc/fastfetch/arrera-logo.txt
    fi
fi

# 5. Configuration de l'écran de démarrage (Plymouth)
echo "[5/7] Configuration du thème Plymouth..."

if [ -d "$REPO_DIR/configs/plymouth" ] && \
   [ -f "$REPO_DIR/configs/plymouth/arrera.plymouth" ] && \
   [ -f "$REPO_DIR/configs/plymouth/arrera.script" ]; then

    mkdir -p /usr/share/plymouth/themes/arrera/
    cp "$REPO_DIR/configs/plymouth/arrera.plymouth" /usr/share/plymouth/themes/arrera/
    cp "$REPO_DIR/configs/plymouth/arrera.script" /usr/share/plymouth/themes/arrera/

    # Récupération de l'animation Fedora (Spinner) depuis le système
    if [ -d /usr/share/plymouth/themes/spinner ]; then
        cp /usr/share/plymouth/themes/spinner/throbber-*.png /usr/share/plymouth/themes/arrera/ 2>/dev/null || true
    fi

    # Installation du logo Plymouth local
    if [ -f "$ASSET_DIR/logo.png" ]; then
        cp "$ASSET_DIR/logo.png" /usr/share/plymouth/themes/arrera/
    fi

    # Application de Plymouth et reconstruction de l'initramfs
    plymouth-set-default-theme -R arrera 2>/dev/null || true
else
    echo "  [SKIP] Fichiers Plymouth non trouvés dans $REPO_DIR/configs/plymouth/"
    echo "         Le thème Plymouth personnalisé ne sera pas installé."
fi

# 6. Configuration de l'écran de connexion (GDM)
echo "[6/7] Configuration de GDM..."
mkdir -p /etc/dconf/db/gdm.d/

# Règle dconf pour GDM
if [ -f "$REPO_DIR/configs/99-arrera-login" ]; then
    cp "$REPO_DIR/configs/99-arrera-login" /etc/dconf/db/gdm.d/
fi

# Logo GDM depuis les assets locaux
if [ -f "$ASSET_DIR/arrera_gdm_logo_dark.png" ]; then
    cp "$ASSET_DIR/arrera_gdm_logo_dark.png" /usr/share/pixmaps/
fi

dconf update 2>/dev/null || true

# Régénération finale de GRUB (peut échouer dans le chroot)
if [ -f /etc/default/grub ]; then
    echo "Régénération de grub.cfg..."
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

# 7. Configuration des paramètres GNOME via dconf (fonctionne sans session graphique)
echo "[7/7] Configuration des paramètres GNOME (dconf)..."

# Désactivation des raccourcis GPaste via un fichier dconf utilisateur
mkdir -p /etc/dconf/db/local.d/
cat > /etc/dconf/db/local.d/99-arrera-gpaste <<'DCONF_EOF'
[org/gnome/GPaste/keybindings]
launch-ui=''
pop-from-history=''
show-history=''
sync-clipboard-to-primary=''
sync-primary-to-clipboard=''
upload-to-pastebin=''
convert-to-password=''
DCONF_EOF

dconf update 2>/dev/null || true

echo "=========================================="
echo " Terminé ! L'environnement est configuré. "
echo "=========================================="