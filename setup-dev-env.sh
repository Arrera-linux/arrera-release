#!/bin/bash

# ==============================================================================
# Script de configuration : Environnement de développement Arrera Linux 
# ==============================================================================

# Vérification des privilèges root (nécessaire pour écrire dans /etc)
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Veuillez exécuter ce script en tant que root (ex: sudo ./setup-dev-env.sh)"
  exit 1
fi

echo "=========================================="
echo " Configuration de l'environnement de dev  "
echo " Arrera Linux                          "
echo "=========================================="

# 1. Configuration de l'identité du système
echo "[1/4] Mise à jour de /etc/os-release..."
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
LOGO=fedora-logo-icon
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
echo "[2/4] Création de /etc/arrera-release et des liens de compatibilité..."
echo "Arrera release 0.0 (Blue-Dev)" > /etc/arrera-release

# On supprime les anciens fichiers s'ils existent et on crée les liens symboliques
for release_file in fedora-release system-release redhat-release; do
    if [ -f "/etc/$release_file" ] || [ -L "/etc/$release_file" ]; then
        rm -f "/etc/$release_file"
    fi
    ln -s /etc/arrera-release "/etc/$release_file"
done

# 3. Modification du gestionnaire de démarrage GRUB
echo "[3/4] Configuration du menu de démarrage GRUB..."
# On remplace la ligne GRUB_DISTRIBUTOR par le nom du projet
sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Arrera Linux"/' /etc/default/grub

# Régénération du fichier de configuration GRUB
echo "Régénération de grub.cfg..."
grub2-mkconfig -o /boot/grub2/grub.cfg

echo "=========================================="
echo " Terminé ! L'environnement est configuré. "
echo " Veuillez redémarrer la machine si vous   "
echo " souhaitez vérifier le menu GRUB.         "
echo "=========================================="