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
echo "[1/8] Mise à jour de /etc/os-release et /usr/lib/os-release..."
mkdir -p /usr/lib
cat <<'EOF' > /usr/lib/os-release
NAME="Arrera"
VERSION="Blue-dev 2026"
RELEASE_TYPE="0.0 (Dev)"
ID=arrera
ID_LIKE=fedora
VERSION_ID=2026
VERSION_CODENAME="Blue-dev"
PRETTY_NAME="Arrera Blue-dev 2026"
ANSI_COLOR="0;38;2;60;110;180"
LOGO="arrera-logo"
CPE_NAME="cpe:/o:arrera:arrera:2026"
DEFAULT_HOSTNAME="arrera-blue"
HOME_URL="https://arrera.org/"
DOCUMENTATION_URL="https://arrera.org/"
SUPPORT_URL="https://arrera.org/"
BUG_REPORT_URL="https://arrera.org/"
REDHAT_BUGZILLA_PRODUCT="Arrera"
REDHAT_BUGZILLA_PRODUCT_VERSION=2026
REDHAT_SUPPORT_PRODUCT="Arrera"
REDHAT_SUPPORT_PRODUCT_VERSION=2026
SUPPORT_END=2027-05-19
VARIANT="Workstation Edition"
VARIANT_ID=workstation
EOF

# /etc/os-release doit pointer sur /usr/lib/os-release ou être identique
rm -f /etc/os-release
cp /usr/lib/os-release /etc/os-release

# Nom d'hôte par défaut
echo "arrera-blue" > /etc/hostname

# 2. Création du fichier de release et des liens symboliques
echo "[2/8] Création de /etc/arrera-release et des liens de compatibilité..."
echo "Arrera Blue-dev 2026" > /etc/arrera-release

# On supprime les anciens fichiers s'ils existent et on crée les liens symboliques
for release_file in fedora-release system-release redhat-release; do
    if [ -f "/etc/$release_file" ] || [ -L "/etc/$release_file" ]; then
        rm -f "/etc/$release_file"
    fi
    ln -s /etc/arrera-release "/etc/$release_file"
done

# 3. Modification du gestionnaire de démarrage GRUB et des entrées BLS de kernel-install
echo "[3/8] Configuration du menu de démarrage GRUB et des hooks de mise à jour noyau..."
if [ -f /etc/default/grub ]; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Arrera Blue-dev 2026"/' /etc/default/grub
fi

# Création d'un hook kernel-install pour que chaque mise à jour du noyau nomme l'entrée "Arrera Blue-dev 2026"
mkdir -p /etc/kernel/install.d
cat <<'KERNEL_INSTALL_EOF' > /etc/kernel/install.d/99-arrera-title.install
#!/bin/bash
# Hook Arrera Linux : renomme toujours l'entrée de boot en Arrera Blue-dev 2026
COMMAND="$1"
if [ "$COMMAND" = "add" ] || [ -d "/boot/loader/entries" ]; then
    for conf in /boot/loader/entries/*.conf; do
        [ -f "$conf" ] || continue
        sed -i 's/^title Fedora Linux/title Arrera Blue-dev 2026/g' "$conf"
        sed -i 's/^title Fedora/title Arrera Blue-dev 2026/g' "$conf"
    done
fi
exit 0
KERNEL_INSTALL_EOF
chmod +x /etc/kernel/install.d/99-arrera-title.install

# Corriger immédiatement les entrées BLS existantes si présentes
if [ -d /boot/loader/entries ]; then
    for conf in /boot/loader/entries/*.conf; do
        [ -f "$conf" ] || continue
        sed -i 's/^title Fedora Linux/title Arrera Blue-dev 2026/g' "$conf"
        sed -i 's/^title Fedora/title Arrera Blue-dev 2026/g' "$conf"
    done
fi

# 4. Installation des assets locaux et configuration Fastfetch
echo "[4/8] Installation des assets visuels et configuration Fastfetch..."

# Installation du logo système et remplacement du branding Fedora / Anaconda / GNOME
if [ -f "$ASSET_DIR/arrera-logo.png" ]; then
    # Copie dans /usr/share/pixmaps (utilisé par Anaconda, GDM, Paramètres GNOME / À Propos)
    mkdir -p /usr/share/pixmaps
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/arrera-logo.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/arrera-logo-text.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/arrera-logo-text-dark.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/system-logo-icon.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/fedora-logo-icon.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/fedora-logo.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/fedora_logo.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/fedora-logo-text.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/fedora-logo-text-dark.png
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/pixmaps/anaconda_header.png

    # Copie dans tous les répertoires d'icônes hicolor (16x16 -> 512x512 et scalable)
    for size in 16x16 22x22 24x24 32x32 48x48 64x64 96x96 128x128 256x256 512x512 scalable; do
        mkdir -p "/usr/share/icons/hicolor/$size/apps"
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/arrera-logo.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/arrera-logo-text.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/arrera-logo-text-dark.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/system-logo-icon.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/fedora-logo-icon.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/fedora-logo.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/fedora-logo-text.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/fedora-logo-text-dark.png" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/fedora-logo-icon.svg" 2>/dev/null || true
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/fedora-logo-text.svg" 2>/dev/null || true
    done

    # Dossiers spécifiques de branding Anaconda
    mkdir -p /usr/share/anaconda/pixmaps
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/anaconda/pixmaps/sidebar-logo.png 2>/dev/null || true
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/anaconda/pixmaps/anaconda_header.png 2>/dev/null || true
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/anaconda/pixmaps/topbar-bg.png 2>/dev/null || true

    # Mise à jour du cache des icônes
    gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true
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

# 5. Configuration de l'écran de démarrage (Plymouth - Style macOS)
echo "[5/8] Configuration du thème Plymouth (Style macOS)..."

if [ -d "$REPO_DIR/configs/plymouth" ] && \
   [ -f "$REPO_DIR/configs/plymouth/arrera.plymouth" ] && \
   [ -f "$REPO_DIR/configs/plymouth/arrera.script" ]; then

    mkdir -p /usr/share/plymouth/themes/arrera/
    cp "$REPO_DIR/configs/plymouth/"* /usr/share/plymouth/themes/arrera/ 2>/dev/null || true

    # Installation du logo Plymouth local
    if [ -f "$ASSET_DIR/logo.png" ]; then
        cp "$ASSET_DIR/logo.png" /usr/share/plymouth/themes/arrera/
    fi

    # Application de Plymouth et reconstruction de l'initramfs
    plymouth-set-default-theme -R arrera 2>/dev/null || true
else
    echo "  [SKIP] Fichiers Plymouth non trouvés dans $REPO_DIR/configs/plymouth/"
fi

# 6. Configuration de l'écran de connexion (GDM)
echo "[6/8] Configuration de GDM..."
mkdir -p /etc/dconf/db/gdm.d/

# Règle dconf pour GDM
if [ -f "$REPO_DIR/configs/99-arrera-login" ]; then
    cp "$REPO_DIR/configs/99-arrera-login" /etc/dconf/db/gdm.d/
fi

# Logo GDM depuis les assets locaux
if [ -f "$ASSET_DIR/arrera_gdm_logo_dark.png" ]; then
    cp "$ASSET_DIR/arrera_gdm_logo_dark.png" /usr/share/pixmaps/
fi

# 7. Configuration des paramètres GNOME (Claviers, Extensions, dconf)
echo "[7/8] Configuration des paramètres GNOME (Claviers + Extensions activées)..."

# Configuration du profil dconf
mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user <<'PROFILE_EOF'
user-db:user
system-db:local
PROFILE_EOF

mkdir -p /etc/dconf/db/local.d/

# Activation de tous les claviers avec raccourci et affichage de tous les layouts
cat > /etc/dconf/db/local.d/00-input-sources <<'DCONF_INPUT_EOF'
[org/gnome/desktop/input-sources]
sources=[('xkb', 'fr'), ('xkb', 'us')]
show-all-sources=true
DCONF_INPUT_EOF

# Activation des extensions GNOME par défaut
cat > /etc/dconf/db/local.d/01-extensions <<'DCONF_EXT_EOF'
[org/gnome/shell]
disable-user-extensions=false
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'forge@jmmaranan.com', 'GPaste@gnome-shell-extensions.gnome.org', 'gpaste-reloaded@feuerfuchs.eu']
DCONF_EXT_EOF

# Désactivation des raccourcis GPaste conflictuels
cat > /etc/dconf/db/local.d/99-arrera-gpaste <<'DCONF_GPASTE_EOF'
[org/gnome/GPaste/keybindings]
launch-ui=''
pop-from-history=''
show-history=''
sync-clipboard-to-primary=''
sync-primary-to-clipboard=''
upload-to-pastebin=''
convert-to-password=''
DCONF_GPASTE_EOF

dconf update 2>/dev/null || true

# 8. Script et service de nettoyage post-installation (s'exécute UNIQUEMENT sur le système installé, pas le Live)
echo "[8/8] Mise en place du service de nettoyage post-installation..."

mkdir -p /usr/libexec
cat > /usr/libexec/arrera-post-install-cleanup.sh <<'CLEANUP_SCRIPT_EOF'
#!/bin/bash
# ==============================================================================
# Arrera Linux - Nettoyage post-installation automatique
# ==============================================================================
# Ce script s'exécute UNIQUEMENT au premier démarrage du système installé sur disque.
# Il ne s'exécute JAMAIS sur l'environnement Live ISO.
# ==============================================================================

# 1. Désactiver l'auto-login GDM (retour au login avec mot de passe)
if [ -f /etc/gdm/custom.conf ]; then
    sed -i '/AutomaticLoginEnable=True/d' /etc/gdm/custom.conf
    sed -i '/AutomaticLogin=arrera/d' /etc/gdm/custom.conf
    sed -i 's/AutomaticLoginEnable=True/AutomaticLoginEnable=False/g' /etc/gdm/custom.conf
fi

# 2. Supprimer les raccourcis et l'auto-démarrage de l'installateur
rm -f /home/arrera/Bureau/install-arrera.desktop
rm -f /home/arrera/Desktop/install-arrera.desktop
rm -f /home/arrera/.config/autostart/install-arrera.desktop
rm -f /home/arrera/.config/autostart/liveinst.desktop
rm -f /etc/xdg/autostart/install-arrera.desktop
rm -f /etc/xdg/autostart/liveinst.desktop
rm -f /usr/share/applications/install-arrera.desktop
rm -f /usr/share/applications/liveinst.desktop
rm -f /usr/share/applications/*anaconda*.desktop

# 3. Supprimer Anaconda et les composants d'installation résiduels
rpm -e --nodeps anaconda anaconda-live anaconda-install-env-deps anaconda-gui anaconda-tui liveinst 2>/dev/null || true

# 4. Désactiver et supprimer ce service de nettoyage
systemctl disable arrera-post-install-cleanup.service 2>/dev/null || true
rm -f /etc/systemd/system/arrera-post-install-cleanup.service
rm -f /usr/libexec/arrera-post-install-cleanup.sh
systemctl daemon-reload 2>/dev/null || true

exit 0
CLEANUP_SCRIPT_EOF

chmod +x /usr/libexec/arrera-post-install-cleanup.sh

# Création du service systemd one-shot
cat > /etc/systemd/system/arrera-post-install-cleanup.service <<'SERVICE_EOF'
[Unit]
Description=Arrera Linux Post-Install Cleanup
DefaultDependencies=no
After=local-fs.target
Before=gdm.service display-manager.service
ConditionKernelCommandLine=!rd.live.image
ConditionPathExists=!/run/initramfs/live

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/arrera-post-install-cleanup.sh

[Install]
WantedBy=multi-user.target graphical.target
SERVICE_EOF

systemctl enable arrera-post-install-cleanup.service 2>/dev/null || true

# Régénération finale de GRUB (si présent)
if [ -f /etc/default/grub ]; then
    echo "Régénération de grub.cfg..."
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

echo "=========================================="
echo " Terminé ! L'environnement est configuré. "
echo "=========================================="