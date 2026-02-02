#!/bin/bash

# 1. Chargement des identifiants
if [ -f cred.conf ]; then
    source cred.conf
else
    echo "Erreur : cred.conf introuvable !"
    exit 1
fi
TARGET="$TARGET_USER@$TARGET_IP"

# 2. Vérification des arguments
if [ $# -eq 0 ]; then
    echo "Usage : ./deploy_dts.sh mon_fichier.dts"
    exit 1
fi

DTS_FILE=$1
DTB_FILE="${DTS_FILE%.dts}.dtb"

# 3. Vérification de l'environnement Yocto
if [ -z "$CC" ]; then
    echo "Erreur : Environnement Yocto non détecté."
    echo "Lancez d'abord : source setup-environment build-imx8mp"
    exit 1
fi

echo "------------------------------------------"
echo "COMPILATION DTS DANS YOCTO : $DTS_FILE"
echo "------------------------------------------"

# 4. Compilation avec les includes du Kernel Yocto
# On cherche le dossier source du kernel pour les fichiers .dtsi
KERNEL_INCLUDE=$(bitbake -e virtual/kernel | grep ^STAGING_KERNEL_DIR | cut -d'=' -f2 | tr -d '"')

echo "Utilisation des includes : $KERNEL_INCLUDE"

dtc -I dts -O dtb -p 1024 \
    -i "$KERNEL_INCLUDE/arch/arm64/boot/dts/freescale" \
    -i "$KERNEL_INCLUDE/scripts/dtc/include-prefixes" \
    -o "$DTB_FILE" "$DTS_FILE"

if [ $? -eq 0 ]; then
    echo "Compilation réussie : $DTB_FILE"
else
    echo "Erreur lors de la compilation."
    exit 1
fi

# 5. Déploiement SSH
echo "Envoi vers l'EVK ($TARGET)..."
scp "$DTB_FILE" "$TARGET":/boot/

if [ $? -eq 0 ]; then
    echo "Fichier déployé avec succès dans /boot/ sur l'EVK."
else
    echo "Erreur de transfert SSH."
fi