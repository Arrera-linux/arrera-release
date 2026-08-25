#!/bin/bash

# ==============================================================================
# Script de configuration : Environnement Arrera Linux V2 (Blue-dev 2026)
# ==============================================================================
# Ce script s'exécute depuis le %post du kickstart (ou manuellement en dev).
# Les assets graphiques, logos, Plymouth et GDM sont fournis par arrera-branding.
# Les fonds d'écran sont fournis par arrera-wallpapers.
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

# ------------------------------------------------------------------------------
# 1. Configuration de l'identité du système (os-release)
# ------------------------------------------------------------------------------
echo "[1/6] Mise à jour de /etc/os-release et /usr/lib/os-release..."
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

rm -f /etc/os-release
cp /usr/lib/os-release /etc/os-release

# Nom d'hôte par défaut
echo "arrera-blue" > /etc/hostname

# Création du fichier de release et des liens de compatibilité
echo "Arrera Blue-dev 2026" > /etc/arrera-release
for release_file in fedora-release system-release redhat-release; do
    rm -f "/etc/$release_file" 2>/dev/null || true
    ln -s /etc/arrera-release "/etc/$release_file"
done

# Sauvegarde permanente des fichiers maîtres de marque
mkdir -p /usr/share/arrera-branding
cp /usr/lib/os-release /usr/share/arrera-branding/os-release 2>/dev/null || true
cp /etc/arrera-release /usr/share/arrera-branding/arrera-release 2>/dev/null || true

# ------------------------------------------------------------------------------
# 2. Configuration du chargeur d'amorçage GRUB et des hooks noyau
# ------------------------------------------------------------------------------
echo "[2/6] Configuration du menu de démarrage GRUB..."
if [ -f /etc/default/grub ]; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Arrera Blue-dev 2026"/' /etc/default/grub
fi

# Hook kernel-install pour nommer chaque mise à jour du noyau en "Arrera Blue-dev 2026"
mkdir -p /etc/kernel/install.d
cat <<'KERNEL_INSTALL_EOF' > /etc/kernel/install.d/99-arrera-title.install
#!/bin/bash
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

# Activation du thème Plymouth Arrera
if [ -d /usr/share/plymouth/themes/arrera ]; then
    plymouth-set-default-theme -R arrera 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 3. Configuration des paramètres GNOME (dconf)
# ------------------------------------------------------------------------------
echo "[3/6] Configuration des paramètres GNOME (Claviers, Boutons, Extensions, Wallpaper)..."

mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user <<'PROFILE_EOF'
user-db:user
system-db:local
PROFILE_EOF

mkdir -p /etc/dconf/db/local.d/

# Claviers internationaux disponibles
cat > /etc/dconf/db/local.d/00-input-sources <<'DCONF_INPUT_EOF'
[org/gnome/desktop/input-sources]
show-all-sources=true
DCONF_INPUT_EOF

# Extensions activées par défaut
cat > /etc/dconf/db/local.d/01-extensions <<'DCONF_EXT_EOF'
[org/gnome/shell]
disable-user-extensions=false
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'forge@jmmaranan.com', 'GPaste@gnome-shell-extensions.gnome.org', 'gpaste-reloaded@feuerfuchs.eu']
DCONF_EXT_EOF

# Boutons Réduire, Maximiser et Fermer par défaut
cat > /etc/dconf/db/local.d/02-wm-preferences <<'DCONF_WM_EOF'
[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'
DCONF_WM_EOF

# Fond d'écran par défaut (blue.png)
BLUE_WALLPAPER=$(find /usr/share/backgrounds -name "blue.png" 2>/dev/null | head -n 1)
if [ -z "$BLUE_WALLPAPER" ]; then
    BLUE_WALLPAPER="/usr/share/backgrounds/arrera/blue.png"
fi

cat > /etc/dconf/db/local.d/03-background <<DCONF_BG_EOF
[org/gnome/desktop/background]
picture-uri='file://${BLUE_WALLPAPER}'
picture-uri-dark='file://${BLUE_WALLPAPER}'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='file://${BLUE_WALLPAPER}'
picture-options='zoom'
DCONF_BG_EOF

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
# 4. Règles Polkit pour la session Live
# ------------------------------------------------------------------------------
echo "[4/6] Configuration des autorisations Polkit pour la session Live..."
mkdir -p /etc/polkit-1/rules.d/

cat > /etc/polkit-1/rules.d/49-liveuser.rules <<'POLKIT_LIVE_EOF'
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
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.fedoraproject.anaconda") === 0 ||
        action.id.indexOf("org.freedesktop.policykit.exec") === 0 ||
        action.id.indexOf("org.freedesktop.udisks2") === 0) {
        return polkit.Result.YES;
    }
});
POLKIT_ANACONDA_EOF

# ------------------------------------------------------------------------------
# 5. Dépôt Copr persistant et service de protection de marque
# ------------------------------------------------------------------------------
echo "[5/6] Configuration du dépôt Copr et du service de protection Arrera..."

mkdir -p /etc/yum.repos.d
cat > /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:arrera-software:arrera_blue.repo <<'COPR_REPO_EOF'
[copr:copr.fedorainfracloud.org:arrera-software:arrera_blue]
name=Copr repo for arrera_blue owned by arrera-software
baseurl=https://download.copr.fedorainfracloud.org/results/arrera-software/arrera_blue/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/arrera-software/arrera_blue/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
cost=100
COPR_REPO_EOF

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
# 6. Service de nettoyage post-installation (exécuté 1 seule fois sur disque)
# ------------------------------------------------------------------------------
echo "[6/6] Mise en place du service de nettoyage post-installation..."

mkdir -p /usr/libexec
cat > /usr/libexec/arrera-post-install-cleanup.sh <<'CLEANUP_SCRIPT_EOF'
#!/bin/bash
# 1. Désactiver l'auto-login GDM (retour au login utilisateur avec mot de passe)
if [ -f /etc/gdm/custom.conf ]; then
    sed -i '/AutomaticLoginEnable=True/d' /etc/gdm/custom.conf
    sed -i '/AutomaticLogin=arrera/d' /etc/gdm/custom.conf
    sed -i 's/AutomaticLoginEnable=True/AutomaticLoginEnable=False/g' /etc/gdm/custom.conf
fi

# 2. Supprimer le compte live "arrera" et conserver le compte créé lors de l'installation
if id "arrera" &>/dev/null; then
    OTHER_USER=$(awk -F: '$3 >= 1000 && $1 != "arrera" && $1 != "nobody" {print $1}' /etc/passwd | head -n 1)
    if [ -n "$OTHER_USER" ]; then
        pkill -9 -u arrera 2>/dev/null || true
        userdel -r -f arrera 2>/dev/null || true
        rm -rf /home/arrera
        rm -f /etc/sudoers.d/arrera
    fi
fi

# 3. Supprimer les raccourcis et autostarts de l'installateur
rm -f /home/arrera/Bureau/install-arrera.desktop
rm -f /home/arrera/Desktop/install-arrera.desktop
rm -f /home/arrera/.config/autostart/install-arrera.desktop
rm -f /home/arrera/.config/autostart/liveinst.desktop
rm -f /etc/xdg/autostart/install-arrera.desktop
rm -f /etc/xdg/autostart/liveinst.desktop
rm -f /usr/share/applications/install-arrera.desktop
rm -f /usr/share/applications/liveinst.desktop
rm -f /usr/share/applications/*anaconda*.desktop

# 4. Supprimer les règles Polkit du Live
rm -f /etc/polkit-1/rules.d/49-liveuser.rules
rm -f /etc/polkit-1/rules.d/50-anaconda.rules

# 5. Supprimer Anaconda du système installé
rpm -e --nodeps anaconda anaconda-live anaconda-install-env-deps anaconda-gui anaconda-tui liveinst 2>/dev/null || true

# 6. Auto-suppression de ce service
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

# Nettoyage des caches DNF
dnf clean all 2>/dev/null || true

# Régénération finale de GRUB (si présent)
if [ -f /etc/default/grub ]; then
    echo "Régénération de grub.cfg..."
    grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
fi

echo "=========================================="
echo " Terminé ! L'environnement est configuré. "
echo "=========================================="