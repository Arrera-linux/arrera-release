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

# Écrire les blocs dans des fichiers temporaires pour sed 'r'
echo "$ASSETS_BLOCK" > "$BUILD_DIR/assets_block.tmp"

# Retirer la ligne 'graphical' si présente (livemedia-creator interdit les modes d'affichage)
sed -i '/^graphical$/d' "$KS_FINAL"

# Passe 1 : remplacer __ASSETS_BASE64__ par le contenu des assets
# Les ancres ^...$ garantissent qu'on ne matche pas les commentaires
sed -e "/^__ASSETS_BASE64__$/{
    r $BUILD_DIR/assets_block.tmp
    d
}" "$KS_FINAL" > "${KS_FINAL}.tmp1"

# Passe 2 : remplacer __SETUP_DEV_ENV__ par le contenu du script
sed -e "/^__SETUP_DEV_ENV__$/{
    r $SETUP_SCRIPT
    d
}" "${KS_FINAL}.tmp1" > "$KS_FINAL"

# Nettoyage des fichiers temporaires
rm -f "${KS_FINAL}.tmp1" "$BUILD_DIR/assets_block.tmp"

ok "Kickstart final généré : $KS_FINAL"

# Vérification rapide (cherche les placeholders seuls sur une ligne)
if grep -qE "^__(SETUP_DEV_ENV|ASSETS_BASE64)__$" "$KS_FINAL"; then
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

# Désactivation temporaire de SELinux (cause des échecs de démontage)
SELINUX_WAS_ENFORCING=false
if command -v getenforce &>/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    info "Passage de SELinux en mode Permissive (temporaire)..."
    setenforce 0
    SELINUX_WAS_ENFORCING=true
fi

# Nettoyage des fichiers PID résiduels d'Anaconda (évite "anaconda.pid already exists")
for pidfile in /run/anaconda.pid /run/user/0/anaconda.pid /var/run/anaconda.pid; do
    if [ -f "$pidfile" ]; then
        warn "Suppression du fichier PID résiduel : $pidfile"
        rm -f "$pidfile"
    fi
done

# --- Indicateur de progression en arrière-plan ---
BUILD_START_TIME=$(date +%s)
LMC_LOG="$BUILD_DIR/livemedia-creator.log"

progress_reporter() {
    local start=$1
    while true; do
        sleep 30
        local now=$(date +%s)
        local elapsed=$(( now - start ))
        local mins=$(( elapsed / 60 ))
        local secs=$(( elapsed % 60 ))
        echo -e "\e[1;36m[PROGRESS]\e[0m  ⏱  Build en cours depuis ${mins}m ${secs}s..."
    done
}

# Démarrage du reporter en arrière-plan
progress_reporter "$BUILD_START_TIME" &
PROGRESS_PID=$!
# S'assurer que le reporter est tué à la fin (même en cas d'erreur)
trap "kill $PROGRESS_PID 2>/dev/null; wait $PROGRESS_PID 2>/dev/null" EXIT

info "📦 Phase 1/3 : Installation du système (Anaconda + kickstart)..."
info "📦 Phase 2/3 : Création du système de fichiers compressé (squashfs)..."
info "📦 Phase 3/3 : Assemblage de l'image ISO..."
info ""
info "Les 3 phases sont gérées automatiquement par livemedia-creator."
info "Un message de progression s'affichera toutes les 30 secondes."
info "Log détaillé : $LMC_LOG"
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
    --releasever 44 \
    --logfile "$LMC_LOG"

BUILD_STATUS=$?

# Arrêt du reporter de progression
kill "$PROGRESS_PID" 2>/dev/null
wait "$PROGRESS_PID" 2>/dev/null
trap - EXIT

# Calcul du temps total
BUILD_END_TIME=$(date +%s)
BUILD_ELAPSED=$(( BUILD_END_TIME - BUILD_START_TIME ))
BUILD_MINS=$(( BUILD_ELAPSED / 60 ))
BUILD_SECS=$(( BUILD_ELAPSED % 60 ))

# Restauration de SELinux si nécessaire
if [ "$SELINUX_WAS_ENFORCING" = true ]; then
    info "Restauration de SELinux en mode Enforcing..."
    setenforce 1
fi

# --------------------------------------------------------------------------
# 7. Résultat
# --------------------------------------------------------------------------

echo ""
if [ $BUILD_STATUS -eq 0 ] && [ -f "$RESULT_DIR/$ISO_NAME" ]; then
    ISO_SIZE=$(du -h "$RESULT_DIR/$ISO_NAME" | cut -f1)
    echo "==================================================="
    ok "🎉 L'ISO a été généré avec succès !"
    echo ""
    info "  Fichier : $RESULT_DIR/$ISO_NAME"
    info "  Taille  : $ISO_SIZE"
    info "  Volume  : $VOLID"
    info "  Durée   : ${BUILD_MINS}m ${BUILD_SECS}s"
    echo ""
    info "Pour tester, lancez dans une VM :"
    info "  qemu-system-x86_64 -m 4096 -cdrom $RESULT_DIR/$ISO_NAME -boot d"
    echo "==================================================="
else
    echo "==================================================="
    error "❌ La création de l'ISO a échoué (code: $BUILD_STATUS)."
    echo ""
    info "  Durée avant échec : ${BUILD_MINS}m ${BUILD_SECS}s"
    info ""
    info "Consultez les logs :"
    info "  - $LMC_LOG                (log livemedia-creator)"
    info "  - /var/tmp/arrera-build/  (kickstart final)"
    info "  - /var/log/anaconda/      (logs Anaconda)"
    info "  - Sortie ci-dessus        (erreurs livemedia-creator)"
    echo "==================================================="
    exit 1
fi
