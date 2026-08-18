#!/bin/bash

# ==============================================================================
# Script de compilation : Arrera Linux V2 (Blue-Dev)
# ==============================================================================

# 1. Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
  echo "Erreur : Veuillez exécuter ce script avec sudo (ex: sudo ./build-iso.sh)"
  exit 1
fi

echo "==================================================="
echo " Lancement de la création de l'ISO Arrera Linux... "
echo "==================================================="

# 2. Nettoyage de l'ancien dossier de compilation
# Indispensable car livemedia-creator refuse d'écrire dans un dossier plein
if [ -d "/var/tmp/arrera-iso" ]; then
    echo "[*] Nettoyage du dossier de compilation précédent..."
    rm -rf /var/tmp/arrera-iso
fi

# 3. Lancement de livemedia-creator
echo "[*] Génération de l'image en cours..."
echo "[*] Cette opération peut prendre 10 à 30 minutes. Veuillez patienter..."
echo "---------------------------------------------------"

livemedia-creator \
    --ks arrera.ks \
    --no-virt \
    --resultdir /var/tmp/arrera-iso \
    --project "Arrera Linux" \
    --make-iso \
    --volid "Arrera_Blue_Dev" \
    --iso-only \
    --iso-name Arrera-Linux-Blue-Dev.iso

# 4. Vérification du résultat
if [ $? -eq 0 ]; then
    echo "---------------------------------------------------"
    echo " SUCCESS ! L'ISO a été généré avec succès.         "
    echo " Chemin : /var/tmp/arrera-iso/Arrera-Linux-Blue-Dev.iso"
    echo "==================================================="
else
    echo "---------------------------------------------------"
    echo " ERREUR : La création de l'ISO a échoué.           "
    echo " Consultez les logs au-dessus pour voir le problème."
    echo "==================================================="
fi