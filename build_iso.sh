#!/bin/bash

# ==============================================================================
# Build ISO : Arrera Linux V2 (Blue-Dev)
# ==============================================================================
# Script unique à lancer sur une VM Fedora pour générer l'ISO Arrera Linux.
#
# Usage :
#   sudo ./build_iso.sh
#
# Ce script :
#   1. Vérifie les prérequis (root, outils, espace disque)
#   2. Injecte setup-dev-env.sh dans le kickstart (remplace __SETUP_DEV_ENV__)
#   3. Encode les assets (PNG, configs) en base64 et les injecte dans le %post
#   4. Génère le .ks final dans /var/tmp/arrera-build/
#   5. Lance livemedia-creator pour créer l'ISO
# ==============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KS_TEMPLATE="$SCRIPT_DIR/arrera.ks"
SETUP_SCRIPT="$SCRIPT_DIR/setup-dev-env.sh"
ASSET_DIR="$SCRIPT_DIR/asset"
CONFIG_DIR="$SCRIPT_DIR/configs"

BUILD_DIR="/var/tmp/arrera-build"
RESULT_DIR="/var/tmp/arrera-iso"
KS_FINAL="$BUILD_DIR/arrera-final.ks"
ISO_NAME="Arrera-Linux-Blue-Dev.iso"
VOLID="Arrera_Blue_Dev"

# --------------------------------------------------------------------------
# Fonctions utilitaires
# --------------------------------------------------------------------------

info()  { echo -e "\e[1;34m[INFO]\e[0m  $*"; }
ok()    { echo -e "\e[1;32m[OK]\e[0m    $*"; }
warn()  { echo -e "\e[1;33m[WARN]\e[0m  $*"; }
error() { echo -e "\e[1;31m[ERROR]\e[0m $*"; exit 1; }

# --------------------------------------------------------------------------
# 1. Vérifications préalables
# --------------------------------------------------------------------------

info "=== Arrera Linux ISO Builder ==="
echo ""

# Root ?
if [ "$EUID" -ne 0 ]; then
    error "Ce script doit être exécuté en tant que root (sudo ./build_iso.sh)"
fi

# Fichiers requis
info "Vérification des fichiers sources..."
[ -f "$KS_TEMPLATE" ] || error "Kickstart template introuvable : $KS_TEMPLATE"
[ -f "$SETUP_SCRIPT" ] || error "Script de setup introuvable : $SETUP_SCRIPT"
[ -d "$ASSET_DIR" ]    || error "Dossier assets introuvable : $ASSET_DIR"
[ -d "$CONFIG_DIR" ]   || error "Dossier configs introuvable : $CONFIG_DIR"
ok "Tous les fichiers sources sont présents."

# Outils requis
info "Vérification des outils de compilation..."
MISSING_TOOLS=()
for tool in livemedia-creator base64 sed; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    warn "Outils manquants : ${MISSING_TOOLS[*]}"
    info "Installation des dépendances..."
    dnf install -y lorax anaconda livecd-tools
    ok "Dépendances installées."
else
    ok "Tous les outils sont disponibles."
fi

# Espace disque (minimum 10 Go dans /var/tmp)
info "Vérification de l'espace disque..."
AVAILABLE_GB=$(df --output=avail /var/tmp 2>/dev/null | tail -1 | awk '{printf "%.0f", $1/1048576}')
if [ "$AVAILABLE_GB" -lt 10 ]; then
    error "Espace insuffisant dans /var/tmp : ${AVAILABLE_GB} Go disponible, 10 Go minimum requis."
fi
ok "Espace disque suffisant (${AVAILABLE_GB} Go disponible)."

echo ""
info "=== Génération du kickstart final ==="

# --------------------------------------------------------------------------
# 2. Préparation du répertoire de build
# --------------------------------------------------------------------------

info "Préparation du répertoire de build..."
mkdir -p "$BUILD_DIR"
rm -f "$KS_FINAL"

# --------------------------------------------------------------------------
# 3. Encoder les assets en base64
# --------------------------------------------------------------------------

info "Encodage des assets en base64..."

# Fonction pour encoder un fichier et générer la commande de décodage
encode_asset() {
    local src_file="$1"
    local dest_path="$2"
    local dest_dir
    dest_dir=$(dirname "$dest_path")

    if [ ! -f "$src_file" ]; then
        warn "Asset introuvable, ignoré : $src_file"
        return
    fi

    local b64
    b64=$(base64 -w0 "$src_file")
    echo "mkdir -p $dest_dir"
    echo "echo '$b64' | base64 -d > $dest_path"
    info "  ✓ $(basename "$src_file") → $dest_path"
}

# Générer toutes les commandes de décodage des assets
ASSETS_BLOCK=""

# Assets visuels (images)
ASSETS_BLOCK+=$(encode_asset "$ASSET_DIR/arrera-logo.png" "/opt/arrera/asset/arrera-logo.png")
ASSETS_BLOCK+=$'\n'
ASSETS_BLOCK+=$(encode_asset "$ASSET_DIR/arrera_gdm_logo_dark.png" "/opt/arrera/asset/arrera_gdm_logo_dark.png")
ASSETS_BLOCK+=$'\n'
ASSETS_BLOCK+=$(encode_asset "$ASSET_DIR/logo.png" "/opt/arrera/asset/logo.png")
ASSETS_BLOCK+=$'\n'

# Configs texte
ASSETS_BLOCK+=$(encode_asset "$CONFIG_DIR/fastfetch-config.jsonc" "/opt/arrera/configs/fastfetch-config.jsonc")
ASSETS_BLOCK+=$'\n'
ASSETS_BLOCK+=$(encode_asset "$CONFIG_DIR/arrera-logo.txt" "/opt/arrera/configs/arrera-logo.txt")
ASSETS_BLOCK+=$'\n'
ASSETS_BLOCK+=$(encode_asset "$CONFIG_DIR/99-arrera-login" "/opt/arrera/configs/99-arrera-login")
ASSETS_BLOCK+=$'\n'

# Plymouth configs
if [ -f "$CONFIG_DIR/plymouth/arrera.plymouth" ]; then
    ASSETS_BLOCK+=$(encode_asset "$CONFIG_DIR/plymouth/arrera.plymouth" "/opt/arrera/configs/plymouth/arrera.plymouth")
    ASSETS_BLOCK+=$'\n'
fi
if [ -f "$CONFIG_DIR/plymouth/arrera.script" ]; then
    ASSETS_BLOCK+=$(encode_asset "$CONFIG_DIR/plymouth/arrera.script" "/opt/arrera/configs/plymouth/arrera.script")
    ASSETS_BLOCK+=$'\n'
fi

ok "Assets encodés."

# --------------------------------------------------------------------------
# 4. Assembler le kickstart final
# --------------------------------------------------------------------------

info "Assemblage du kickstart final..."

# Lire le template
cp "$KS_TEMPLATE" "$KS_FINAL"

# Remplacer __ASSETS_BASE64__ par les commandes de décodage
# On utilise un fichier temporaire pour le remplacement multi-lignes
ASSETS_ESCAPED=$(echo "$ASSETS_BLOCK" | sed 's/[&/\]/\\&/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Méthode plus fiable : utiliser awk pour le remplacement
awk -v assets="$ASSETS_BLOCK" '{
    if ($0 ~ /__ASSETS_BASE64__/) {
        print assets
    } else {
        print
    }
}' "$KS_TEMPLATE" > "${KS_FINAL}.tmp1"

# Remplacer __SETUP_DEV_ENV__ par le contenu du script
SETUP_CONTENT=$(cat "$SETUP_SCRIPT")
awk -v script="$SETUP_CONTENT" '{
    if ($0 ~ /__SETUP_DEV_ENV__/) {
        print script
    } else {
        print
    }
}' "${KS_FINAL}.tmp1" > "$KS_FINAL"

# Nettoyage des fichiers temporaires
rm -f "${KS_FINAL}.tmp1"

ok "Kickstart final généré : $KS_FINAL"

# Vérification rapide
if grep -q "__SETUP_DEV_ENV__\|__ASSETS_BASE64__" "$KS_FINAL"; then
    error "Des placeholders n'ont pas été remplacés dans le kickstart final !"
fi
ok "Vérification des placeholders OK — tous remplacés."

# --------------------------------------------------------------------------
# 5. Nettoyage de l'ancien résultat
# --------------------------------------------------------------------------

if [ -d "$RESULT_DIR" ]; then
    info "Nettoyage du dossier de compilation précédent..."
    rm -rf "$RESULT_DIR"
fi

# --------------------------------------------------------------------------
# 6. Lancement de livemedia-creator
# --------------------------------------------------------------------------

echo ""
info "=== Lancement de la création de l'ISO ==="
info "Cette opération peut prendre 15 à 45 minutes. Veuillez patienter..."
echo ""

# ATTENTION : --no-virt exécute l'installation sur le système hôte.
# Ce script est prévu pour être lancé dans une VM dédiée.
warn "Mode --no-virt : l'installation s'exécute directement sur ce système."
warn "Assurez-vous d'être dans une VM dédiée à la compilation."
echo ""

livemedia-creator \
    --ks "$KS_FINAL" \
    --no-virt \
    --resultdir "$RESULT_DIR" \
    --project "Arrera Linux" \
    --make-iso \
    --volid "$VOLID" \
    --iso-only \
    --iso-name "$ISO_NAME" \
    --releasever 44

BUILD_STATUS=$?

# --------------------------------------------------------------------------
# 7. Résultat
# --------------------------------------------------------------------------

echo ""
if [ $BUILD_STATUS -eq 0 ] && [ -f "$RESULT_DIR/$ISO_NAME" ]; then
    ISO_SIZE=$(du -h "$RESULT_DIR/$ISO_NAME" | cut -f1)
    echo "==================================================="
    ok "L'ISO a été généré avec succès !"
    echo ""
    info "  Fichier : $RESULT_DIR/$ISO_NAME"
    info "  Taille  : $ISO_SIZE"
    info "  Volume  : $VOLID"
    echo ""
    info "Pour tester, lancez dans une VM :"
    info "  qemu-system-x86_64 -m 4096 -cdrom $RESULT_DIR/$ISO_NAME -boot d"
    echo "==================================================="
else
    echo "==================================================="
    error "La création de l'ISO a échoué (code: $BUILD_STATUS)."
    echo ""
    info "Consultez les logs :"
    info "  - /var/tmp/arrera-build/ (kickstart final)"
    info "  - /var/log/anaconda/    (logs Anaconda)"
    info "  - Sortie ci-dessus      (erreurs livemedia-creator)"
    echo "==================================================="
    exit 1
fi
