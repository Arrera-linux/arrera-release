# ==============================================================================
# Préparation de la VM pour la compilation de l'ISO Arrera Linux
# ==============================================================================
#
# Ce script prépare une VM Fedora fraîche pour compiler l'ISO Arrera Linux.
# À exécuter UNE SEULE FOIS sur la VM avant de lancer build_iso.sh.
#
# Usage :
#   sudo ./prepare-vm.sh
#
# ==============================================================================

#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Erreur : Exécuter avec sudo (sudo ./prepare-vm.sh)"
    exit 1
fi

echo "=========================================="
echo " Préparation de la VM de compilation      "
echo "=========================================="

# 1. Mise à jour du système
echo "[1/4] Mise à jour du système..."
dnf upgrade -y --refresh

# 2. Installation des outils de création d'ISO
echo "[2/4] Installation des outils de compilation..."
dnf install -y \
    lorax \
    livecd-tools \
    anaconda \
    pykickstart \
    squashfs-tools \
    genisoimage \
    isomd5sum \
    syslinux \
    grub2-pc-modules \
    grub2-tools-extra \
    git

# 3. Vérification
echo "[3/4] Vérification de l'installation..."
echo ""

TOOLS=("livemedia-creator" "ksvalidator" "mksquashfs" "genisoimage" "git")
ALL_OK=true

for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo "  ✅ $tool"
    else
        echo "  ❌ $tool — MANQUANT"
        ALL_OK=false
    fi
done

echo ""

# 4. Vérification de l'espace disque
echo "[4/4] Vérification de l'espace disque..."
AVAILABLE_GB=$(df --output=avail /var/tmp | tail -1 | awk '{printf "%.0f", $1/1048576}')
if [ "$AVAILABLE_GB" -ge 10 ]; then
    echo "  ✅ Espace disque : ${AVAILABLE_GB} Go disponible (minimum 10 Go)"
else
    echo "  ⚠️  Espace disque : ${AVAILABLE_GB} Go disponible — INSUFFISANT (minimum 10 Go)"
    ALL_OK=false
fi

echo ""

if [ "$ALL_OK" = true ]; then
    echo "=========================================="
    echo " ✅ VM prête ! Vous pouvez maintenant :   "
    echo "                                          "
    echo "   1. Cloner le repo :                    "
    echo "      git clone <url> && cd arrera-release"
    echo "                                          "
    echo "   2. Lancer la compilation :             "
    echo "      sudo ./build_iso.sh                 "
    echo "=========================================="
else
    echo "=========================================="
    echo " ⚠️  Des problèmes ont été détectés.       "
    echo " Corrigez-les avant de lancer build_iso.sh"
    echo "=========================================="
    exit 1
fi
