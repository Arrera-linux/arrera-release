#!/bin/bash

# ==============================================================================
# Script de configuration : Environnement Arrera Linux V2 (Blue-dev 2026)
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
echo " Configuration de l'environnement         "
echo " Arrera Blue-dev 2026                     "
echo "=========================================="

# En mode kickstart, ARRERA_ROOT est défini par le %post.
# En mode manuel, on utilise le répertoire courant.
REPO_DIR="${ARRERA_ROOT:-$(pwd)}"
ASSET_DIR="$REPO_DIR/asset"

# ------------------------------------------------------------------------------
# 0. Mise à jour complète des paquets et nettoyage des anciens noyaux
# (Doit être exécuté EN PREMIER pour ne pas écraser la personnalisation Arrera)
# ------------------------------------------------------------------------------
echo "[0/10] Mise à jour complète des paquets (dnf upgrade)..."
dnf -y upgrade --refresh 2>/dev/null || true

# Ne conserver UNIQUEMENT que le noyau le plus récent (supprimer l'ancien noyau d'origine en doublon)
echo "       Nettoyage des anciens noyaux pour ne garder que le plus récent..."
if rpm -q kernel-core &>/dev/null; then
    KERNEL_COUNT=$(rpm -q kernel-core | wc -l)
    if [ "$KERNEL_COUNT" -gt 1 ]; then
        LATEST_KERNEL=$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)
        OLD_KERNELS=$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | head -n -1)
        for old_k in $OLD_KERNELS; do
            echo "       Suppression de l'ancien noyau : $old_k"
            rpm -e --nodeps "kernel-core-$old_k" "kernel-modules-$old_k" "kernel-modules-core-$old_k" "kernel-$old_k" "kernel-modules-extra-$old_k" 2>/dev/null || true
            rm -rf "/lib/modules/$old_k" "/boot/*$old_k*" 2>/dev/null || true
            rm -f /boot/loader/entries/*"$old_k"*.conf 2>/dev/null || true
        done
        echo "       Noyau conservé : $LATEST_KERNEL"
    fi
fi
dnf clean all 2>/dev/null || true

# ------------------------------------------------------------------------------
# 1. Configuration de l'identité du système (os-release)
# ------------------------------------------------------------------------------
echo "[1/10] Mise à jour de /etc/os-release et /usr/lib/os-release..."
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

# ------------------------------------------------------------------------------
# 2. Création du fichier de release et des liens symboliques
# ------------------------------------------------------------------------------
echo "[2/10] Création de /etc/arrera-release et des liens de compatibilité..."
echo "Arrera Blue-dev 2026" > /etc/arrera-release

for release_file in fedora-release system-release redhat-release; do
    if [ -f "/etc/$release_file" ] || [ -L "/etc/$release_file" ]; then
        rm -f "/etc/$release_file"
    fi
    ln -s /etc/arrera-release "/etc/$release_file"
done

# ------------------------------------------------------------------------------
# 3. Modification du gestionnaire de démarrage GRUB et des entrées BLS
# ------------------------------------------------------------------------------
echo "[3/10] Configuration du menu de démarrage GRUB et des hooks de mise à jour noyau..."
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

# Corriger immédiatement les entrées BLS existantes
if [ -d /boot/loader/entries ]; then
    for conf in /boot/loader/entries/*.conf; do
        [ -f "$conf" ] || continue
        sed -i 's/^title Fedora Linux/title Arrera Blue-dev 2026/g' "$conf"
        sed -i 's/^title Fedora/title Arrera Blue-dev 2026/g' "$conf"
    done
fi

# ------------------------------------------------------------------------------
# 4. Installation des assets visuels (Logos PNG, SVG, Fastfetch)
# ------------------------------------------------------------------------------
echo "[4/10] Installation des assets visuels et remplacement complet du branding Fedora..."

if [ -f "$ASSET_DIR/arrera-logo.png" ]; then
    # 1. Copie dans /usr/share/pixmaps (utilisé par Anaconda, GDM, Paramètres GNOME / À Propos)
    mkdir -p /usr/share/pixmaps
    for name in arrera-logo arrera-logo-text arrera-logo-text-dark system-logo-icon fedora-logo-icon fedora-logo fedora_logo fedora-logo-text fedora-logo-text-dark anaconda_header; do
        cp "$ASSET_DIR/arrera-logo.png" "/usr/share/pixmaps/${name}.png" 2>/dev/null || true
        if [ -f "$ASSET_DIR/arrera-logo.svg" ]; then
            cp "$ASSET_DIR/arrera-logo.svg" "/usr/share/pixmaps/${name}.svg" 2>/dev/null || true
        fi
    done

    # 2. Copie dans tous les répertoires d'icônes hicolor (16x16 -> 512x512)
    for size in 16x16 22x22 24x24 32x32 48x48 64x64 96x96 128x128 256x256 512x512; do
        mkdir -p "/usr/share/icons/hicolor/$size/apps"
        for name in arrera-logo arrera-logo-text arrera-logo-text-dark system-logo-icon fedora-logo-icon fedora-logo fedora-logo-text fedora-logo-text-dark; do
            cp "$ASSET_DIR/arrera-logo.png" "/usr/share/icons/hicolor/$size/apps/${name}.png" 2>/dev/null || true
        done
    done

    # 3. Répertoire scalable (CRITIQUE pour GNOME Control Center et Anaconda WebUI)
    mkdir -p /usr/share/icons/hicolor/scalable/apps
    if [ -f "$ASSET_DIR/arrera-logo.svg" ]; then
        for name in arrera-logo arrera-logo-text arrera-logo-text-dark system-logo-icon fedora-logo-icon fedora-logo fedora-logo-text fedora-logo-text-dark; do
            cp "$ASSET_DIR/arrera-logo.svg" "/usr/share/icons/hicolor/scalable/apps/${name}.svg" 2>/dev/null || true
        done
    fi

    # 4. Remplacer tout fichier SVG ou PNG Fedora existant dans /usr/share/icons
    if [ -f "$ASSET_DIR/arrera-logo.svg" ]; then
        find /usr/share/icons -type f \( -iname "*fedora*logo*.svg" -o -iname "*fedora*text*.svg" \) -exec cp "$ASSET_DIR/arrera-logo.svg" {} \; 2>/dev/null || true
    fi
    find /usr/share/icons -type f \( -iname "*fedora*logo*.png" -o -iname "*fedora*text*.png" \) -exec cp "$ASSET_DIR/arrera-logo.png" {} \; 2>/dev/null || true

    # 5. Dossiers spécifiques de branding Anaconda
    mkdir -p /usr/share/anaconda/pixmaps
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/anaconda/pixmaps/sidebar-logo.png 2>/dev/null || true
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/anaconda/pixmaps/anaconda_header.png 2>/dev/null || true
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/anaconda/pixmaps/topbar-bg.png 2>/dev/null || true

    # 6. Mise à jour du cache pour tous les thèmes d'icônes
    for theme_dir in /usr/share/icons/*; do
        if [ -d "$theme_dir" ]; then
            gtk-update-icon-cache -f -t "$theme_dir" 2>/dev/null || true
        fi
    done
fi

# Sauvegarde permanente des fichiers maîtres de marque Arrera (pour restauration automatique en cas d'update)
mkdir -p /usr/share/arrera-branding
cp /usr/lib/os-release /usr/share/arrera-branding/os-release 2>/dev/null || true
cp /etc/arrera-release /usr/share/arrera-branding/arrera-release 2>/dev/null || true
if [ -f "$ASSET_DIR/arrera-logo.png" ]; then
    cp "$ASSET_DIR/arrera-logo.png" /usr/share/arrera-branding/ 2>/dev/null || true
fi
if [ -f "$ASSET_DIR/arrera-logo.svg" ]; then
    cp "$ASSET_DIR/arrera-logo.svg" /usr/share/arrera-branding/ 2>/dev/null || true
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

# ------------------------------------------------------------------------------
# 5. Configuration de l'écran de démarrage (Plymouth - Style macOS)
# ------------------------------------------------------------------------------
echo "[5/10] Configuration du thème Plymouth (Style macOS)..."

if [ -d "$REPO_DIR/configs/plymouth" ] && \
   [ -f "$REPO_DIR/configs/plymouth/arrera.plymouth" ] && \
   [ -f "$REPO_DIR/configs/plymouth/arrera.script" ]; then

    mkdir -p /usr/share/plymouth/themes/arrera/
    cp "$REPO_DIR/configs/plymouth/"* /usr/share/plymouth/themes/arrera/ 2>/dev/null || true

    if [ -f "$ASSET_DIR/logo.png" ]; then
        cp "$ASSET_DIR/logo.png" /usr/share/plymouth/themes/arrera/
    fi

    plymouth-set-default-theme -R arrera 2>/dev/null || true
else
    echo "  [SKIP] Fichiers Plymouth non trouvés dans $REPO_DIR/configs/plymouth/"
fi

# ------------------------------------------------------------------------------
# 6. Configuration de l'écran de connexion (GDM)
# ------------------------------------------------------------------------------
echo "[6/10] Configuration de GDM..."
mkdir -p /etc/dconf/db/gdm.d/

if [ -f "$REPO_DIR/configs/99-arrera-login" ]; then
    cp "$REPO_DIR/configs/99-arrera-login" /etc/dconf/db/gdm.d/
fi

if [ -f "$ASSET_DIR/arrera_gdm_logo_dark.png" ]; then
    cp "$ASSET_DIR/arrera_gdm_logo_dark.png" /usr/share/pixmaps/
fi

# ------------------------------------------------------------------------------
# 7. Configuration des paramètres GNOME (Claviers, Boutons, Extensions, dconf)
# ------------------------------------------------------------------------------
echo "[7/10] Configuration des paramètres GNOME (Claviers + Boutons + Extensions)..."

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

# Activation des boutons Réduire (minimize), Maximiser (maximize) et Fermer (close) par défaut
cat > /etc/dconf/db/local.d/02-wm-preferences <<'DCONF_WM_EOF'
[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'
DCONF_WM_EOF

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

# ------------------------------------------------------------------------------
# 8. Règles Polkit pour la session Live (Pas de mot de passe demandé)
# ------------------------------------------------------------------------------
echo "[8/10] Configuration des autorisations Polkit pour la session Live..."
mkdir -p /etc/polkit-1/rules.d/

cat > /etc/polkit-1/rules.d/49-liveuser.rules <<'POLKIT_LIVE_EOF'
/* Autoriser les actions d'administration sans mot de passe sur la session Live */
polkit.addAdminRule(function(action, subject) {
    return ["unix-group:wheel"];
});

polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT_LIVE_EOF

cat > /etc/polkit-1/rules.d/50-anaconda.rules <<'POLKIT_ANACONDA_EOF'
/* Lancement direct d'Anaconda et liveinst sans demande de mot de passe */
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.fedoraproject.anaconda") === 0 ||
        action.id.indexOf("org.freedesktop.policykit.exec") === 0 ||
        action.id.indexOf("org.freedesktop.udisks2") === 0) {
        return polkit.Result.YES;
    }
});
POLKIT_ANACONDA_EOF

# ------------------------------------------------------------------------------
# 9. Protection permanente de la marque Arrera (résiste à tous les dnf update futurs)
# ------------------------------------------------------------------------------
echo "[9/10] Mise en place de la protection permanente de la marque Arrera..."

# 1. Empêcher DNF de réinstaller les paquets de marque Fedora qui écraseraient les logos
if [ -f /etc/dnf/dnf.conf ]; then
    if ! grep -q "excludepkgs=" /etc/dnf/dnf.conf; then
        echo "excludepkgs=fedora-release-identity-basic,fedora-logos" >> /etc/dnf/dnf.conf
    fi
fi

# 2. Service systemd permanent : restaure os-release et logos s'ils sont modifiés
cat > /usr/libexec/arrera-branding-guard.sh <<'GUARD_EOF'
#!/bin/bash
# Arrera Branding Guard : Restaure automatiquement l'identité Arrera après toute mise à jour
if [ -f /usr/share/arrera-branding/os-release ]; then
    if ! grep -q 'PRETTY_NAME="Arrera Blue-dev 2026"' /usr/lib/os-release 2>/dev/null; then
        cp -f /usr/share/arrera-branding/os-release /usr/lib/os-release
        cp -f /usr/share/arrera-branding/os-release /etc/os-release
    fi
fi
if [ -f /usr/share/arrera-branding/arrera-release ]; then
    cp -f /usr/share/arrera-branding/arrera-release /etc/arrera-release
    for f in fedora-release system-release redhat-release; do
        ln -sf /etc/arrera-release "/etc/$f" 2>/dev/null || true
    done
fi
if [ -d /boot/loader/entries ]; then
    for conf in /boot/loader/entries/*.conf; do
        [ -f "$conf" ] || continue
        sed -i 's/^title Fedora Linux/title Arrera Blue-dev 2026/g' "$conf"
        sed -i 's/^title Fedora/title Arrera Blue-dev 2026/g' "$conf"
    done
fi
exit 0
GUARD_EOF
chmod +x /usr/libexec/arrera-branding-guard.sh

cat > /etc/systemd/system/arrera-branding-guard.service <<'GUARD_SERVICE_EOF'
[Unit]
Description=Arrera Linux Branding Guard
DefaultDependencies=no
After=local-fs.target
Before=gdm.service display-manager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/arrera-branding-guard.sh

[Install]
WantedBy=multi-user.target graphical.target
GUARD_SERVICE_EOF

systemctl enable arrera-branding-guard.service 2>/dev/null || true

# ------------------------------------------------------------------------------
# 10. Script et service de nettoyage post-installation
# ------------------------------------------------------------------------------
echo "[10/10] Mise en place du service de nettoyage post-installation..."

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

# 2. Supprimer l'utilisateur temporaire "arrera" de la session Live
# et ne conserver que le compte utilisateur créé par l'utilisateur lors de l'installation
if id "arrera" &>/dev/null; then
    OTHER_USER=$(awk -F: '$3 >= 1000 && $1 != "arrera" && $1 != "nobody" {print $1}' /etc/passwd | head -n 1)
    if [ -n "$OTHER_USER" ]; then
        pkill -9 -u arrera 2>/dev/null || true
        userdel -r -f arrera 2>/dev/null || true
        rm -rf /home/arrera
        rm -f /etc/sudoers.d/arrera
    fi
fi

# 3. Supprimer les raccourcis et l'auto-démarrage de l'installateur
rm -f /home/arrera/Bureau/install-arrera.desktop
rm -f /home/arrera/Desktop/install-arrera.desktop
rm -f /home/arrera/.config/autostart/install-arrera.desktop
rm -f /home/arrera/.config/autostart/liveinst.desktop
rm -f /etc/xdg/autostart/install-arrera.desktop
rm -f /etc/xdg/autostart/liveinst.desktop
rm -f /usr/share/applications/install-arrera.desktop
rm -f /usr/share/applications/liveinst.desktop
rm -f /usr/share/applications/*anaconda*.desktop

# 4. Supprimer les règles Polkit de la session Live
rm -f /etc/polkit-1/rules.d/49-liveuser.rules
rm -f /etc/polkit-1/rules.d/50-anaconda.rules

# 5. Supprimer Anaconda et les composants d'installation résiduels
rpm -e --nodeps anaconda anaconda-live anaconda-install-env-deps anaconda-gui anaconda-tui liveinst 2>/dev/null || true

# 6. Désactiver et supprimer ce service de nettoyage
systemctl disable arrera-post-install-cleanup.service 2>/dev/null || true
rm -f /etc/systemd/system/arrera-post-install-cleanup.service
rm -f /usr/libexec/arrera-post-install-cleanup.sh
systemctl daemon-reload 2>/dev/null || true

exit 0
CLEANUP_SCRIPT_EOF

chmod +x /usr/libexec/arrera-post-install-cleanup.sh

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