#!/bin/bash

# 1. Configuration des variables
BUILD_DIR="build-imx8mp"
MACHINE_NAME="imx8mp-evk"
DEPLOY_SRC_DIR="./deploy"
REPO_URL="https://github.com/nxp-imx/imx-manifest"
REPO_BRANCH="imx-linux-scarthgap"
REPO_MANIFEST="imx-6.6.36-2.1.0.xml"

echo "-------------------------------------------------------"
echo "Installation et Configuration Yocto i.MX8MP EVK"
echo "-------------------------------------------------------"

# 2. Installation de l'outil 'repo' si nécessaire
if ! command -v repo &> /dev/null; then
    echo "Outil 'repo' non trouvé. Installation en cours..."
    mkdir -p ~/bin
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo
    export PATH=${PATH}:~/bin
    echo "Repo installé dans ~/bin et ajouté au PATH."
else
    echo "Outil 'repo' déjà présent."
fi

# 3. Initialisation et Sync du dépôt (si non fait)
if [ ! -d ".repo" ]; then
    echo "Initialisation du dépôt NXP..."
    repo init -u $REPO_URL -b $REPO_BRANCH -m $REPO_MANIFEST
    echo "Synchronisation des sources (cela peut être long)..."
    repo sync -j$(nproc)
else
    echo "Dépôt déjà initialisé. Passage à la configuration."
fi

# 4. Vérification du script de configuration NXP
if [ ! -f "imx-setup-release.sh" ]; then
    echo "Erreur : imx-setup-release.sh introuvable. Vérifiez le repo sync."
    return 1 2>/dev/null || exit 1
fi

# 5. Configuration de l'environnement Yocto
# Note : On utilise 'source' pour garder l'environnement actif
EULA=1 MACHINE=$MACHINE_NAME source imx-setup-release.sh -b $BUILD_DIR

# 6. Copie des scripts de déploiement
echo "Installation des scripts depuis $DEPLOY_SRC_DIR..."
# Nous sommes maintenant dans le dossier $BUILD_DIR, donc le dossier deploy est un niveau au-dessus
if [ -d "../$DEPLOY_SRC_DIR" ]; then
    cp ../$DEPLOY_SRC_DIR/debix.conf .
    cp ../$DEPLOY_SRC_DIR/deploy_dts.sh .
    cp ../$DEPLOY_SRC_DIR/deploy_libs.sh .
    
    chmod +x deploy_dts.sh deploy_libs.sh
    echo "Scripts de déploiement prêts dans : $(pwd)"
else
    echo "Avertissement : Dossier $DEPLOY_SRC_DIR introuvable. Scripts non copiés."
fi

echo "-------------------------------------------------------"
echo "Configuration terminée avec succès."
echo "-------------------------------------------------------"