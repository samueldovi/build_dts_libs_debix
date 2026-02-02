#!/bin/bash

# --- CONFIGURATION ---
MACHINE_NAME="imx8mp-debix-model-a"
BUILD_DIR="build-debix"
REPO_URL="https://github.com/debix-tech/yocto-nxp-debix"
REPO_BRANCH="L6.6.36-2.1.0-debix_model_ab"
MANIFEST="imx-6.6.36-2.1.0.xml"
DEPLOY_SRC_DIR="./deploy"

echo "======================================================="
echo "   INSTALLATION YOCTO : DEBIX MODEL A  "
echo "======================================================="

# 1. GESTION PYTHON (PYENV)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &> /dev/null; then
    eval "$(pyenv init -)"
    # Tente d'activer la 3.12
    pyenv shell 3.12.8 2>/dev/null || pyenv shell 3.12 2>/dev/null
    if [[ $(python --version) == *"3.12"* ]]; then
        echo "[OK] Python actif : $(python --version)"
    else
        echo "[ERREUR] Python 3.12 n'est pas actif. Installez-le avec 'pyenv install 3.12'"
        return 1 2>/dev/null || exit 1
    fi
else
    echo "[INFO] Pyenv non trouve. Assurez-vous d'utiliser Python 3.12."
fi

# 2. INSTALLATION OUTIL REPO
if ! command -v repo &> /dev/null; then
    mkdir -p ~/bin
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
    chmod a+x ~/bin/repo
    export PATH=${PATH}:~/bin
fi

# 3. TELECHARGEMENT SOURCES
if [ ! -d "sources" ]; then
    echo ">>> Initialisation du depot Debix..."
    repo init -u $REPO_URL -b $REPO_BRANCH -m $MANIFEST
    echo ">>> Synchronisation des sources..."
    repo sync -j$(nproc)
else
    echo "[OK] Sources detectees."
fi

# 4. INITIALISATION BUILD
if [ ! -f "imx-setup-release.sh" ]; then
    echo "[ERREUR] imx-setup-release.sh introuvable."
    return 1 2>/dev/null || exit 1
fi

echo ">>> Configuration de la machine : $MACHINE_NAME"
EULA=1 MACHINE=$MACHINE_NAME source imx-setup-release.sh -b $BUILD_DIR

# 5. PATCH ENDEAVOUROS
CONF_FILE="conf/local.conf"
if ! grep -q "SANITY_TESTED_DISTROS" "$CONF_FILE"; then
    echo "" >> "$CONF_FILE"
    echo "# Patch pour EndeavourOS / Arch Linux" >> "$CONF_FILE"
    echo 'SANITY_TESTED_DISTROS = ""' >> "$CONF_FILE"
    echo "[OK] Patch de compatibilite OS applique."
fi

# 6. INSTALLATION DES SCRIPTS UTILISATEUR
echo ">>> Installation des outils de deploiement..."
if [ -d "../$DEPLOY_SRC_DIR" ]; then
    cp "../$DEPLOY_SRC_DIR/cred.conf" .
    cp "../$DEPLOY_SRC_DIR/deploy_libs.sh" .
    cp "../$DEPLOY_SRC_DIR/deploy_dts.sh" .
    chmod +x *.sh
    echo "[OK] Scripts copies dans $BUILD_DIR"
else
    echo "[ATTENTION] Dossier $DEPLOY_SRC_DIR introuvable."
fi

echo "======================================================="
echo " INSTALLATION TERMINEE. Vous etes dans : $(pwd)"
echo "======================================================="