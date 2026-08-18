# ==============================================================================
# Fichier Kickstart : Arrera Linux (Base Fedora Workstation)
# ==============================================================================

# 1. Inclusion de la base officielle Fedora Workstation (Dossier local)
%include /root/arrera-release/fedora-kickstarts/fedora-live-workstation.ks

# 2. Source d'installation principale, dépôts et Réseau
url --url="https://download.fedoraproject.org/pub/fedora/linux/releases/$releasever/Everything/$basearch/os/"
repo --name=cachyos --baseurl=https://mirror.cachyos.org/fedora/$releasever/$basearch/ --install
network --bootproto=dhcp --device=link --activate

# --- DÉFINITION DE LA PARTITION VIRTUELLE POUR L'ISO ---
clearpart --all
part / --size=8192 --fstype=ext4

# 3. Sélection des paquets supplémentaires
%packages
# Noyau optimisé
kernel-cachyos

# Outils de création Live (Requis pour l'ISO)
dracut-live

# Dépendances système pour les assistants IA et le gestionnaire d'applications
python3
qt5-qtbase

# Dépendances pour les extensions GNOME internes
gpaste
forge

# Dépendances pour l'identité visuelle Arrera
chafa
plymouth-plugin-script
ImageMagick
git
%end

# 4. Script de post-installation (exécuté dans la bulle isolée de l'ISO)
%post --log=/root/arrera-post-install.log
echo "=========================================="
echo " DÉBUT DE LA CONFIGURATION ARRERA LINUX   "
echo "=========================================="

# Clonage de ton dépôt builder public contenant les configurations et le script
git clone https://github.com/Arrera-linux/arrera-release.git /tmp/builder

# Exécution du script de déploiement
cd /tmp/builder
chmod +x setup-dev-env.sh
./setup-dev-env.sh

# Nettoyage des fichiers temporaires
cd /
rm -rf /tmp/builder

echo "=========================================="
echo " FIN DE LA CONFIGURATION ARRERA LINUX     "
echo "=========================================="
%end