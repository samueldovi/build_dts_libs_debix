#!/bin/bash

# --- CONFIGURATION ---
MACHINE_NAME="imx8mpevk"
GIT_URL="https://github.com/debix-tech/yocto-nxp-debix"
GIT_BRANCH="L6.6.36-2.1.0-debix_model_ab"
PROJECT_DIR="debix-yocto-bsp"
BUILD_DIR="build-debix"
DEPLOY_SRC_DIR="./deploy"

echo "======================================================="
echo "   INSTALLATION YOCTO : DEBIX MODEL A (GIT CLONE)      "
echo "======================================================="

# 1. GESTION PYTHON (PYENV)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &> /dev/null; then
    eval "$(pyenv init -)"
    pyenv shell 3.12.8 2>/dev/null || pyenv shell 3.12 2>/dev/null
    if [[ $(python --version) == *"3.12"* ]]; then
        echo "[OK] Python actif : $(python --version)"
    else
        echo "[ERREUR] Python 3.12 n'est pas actif."
        return 1 2>/dev/null || exit 1
    fi
else
    echo "[INFO] Pyenv non trouve. Assurez-vous d'utiliser Python 3.12."
fi

# 2. CLONAGE DU DEPOT (Au lieu de Repo Sync)
if [ ! -d "$PROJECT_DIR" ]; then
    echo ">>> Clonage du depot Git ($GIT_BRANCH)..."
    git clone -b "$GIT_BRANCH" "$GIT_URL" "$PROJECT_DIR"
    
    if [ $? -ne 0 ]; then
        echo "[ERREUR] Echec du clonage Git."
        exit 1
    fi
else
    echo "[INFO] Dossier $PROJECT_DIR existant."
fi

# Entree dans le dossier clone
cd "$PROJECT_DIR" || exit 1

# 3. INITIALISATION BUILD
if [ ! -f "imx-setup-release.sh" ]; then
    echo "[ERREUR] imx-setup-release.sh introuvable dans le depot clone."
    return 1 2>/dev/null || exit 1
fi

echo ">>> Configuration de la machine : $MACHINE_NAME"
# On lance le setup qui va creer le dossier build-debix
EULA=1 MACHINE=$MACHINE_NAME source imx-setup-release.sh -b "$BUILD_DIR"

# 4. PATCH ENDEAVOUROS
CONF_FILE="conf/local.conf"
if ! grep -q "SANITY_TESTED_DISTROS" "$CONF_FILE"; then
    echo "" >> "$CONF_FILE"
    echo "# Patch pour EndeavourOS / Arch Linux" >> "$CONF_FILE"
    echo 'SANITY_TESTED_DISTROS = ""' >> "$CONF_FILE"
    echo "[OK] Patch de compatibilite OS applique."
fi

# 5. INSTALLATION DES SCRIPTS UTILISATEUR
# Note : Nous sommes maintenant dans debix-yocto-bsp/build-debix
echo ">>> Installation des outils de deploiement..."

# Le dossier deploy est deux niveaux au-dessus (../../deploy) 
# car : racine -> debix-yocto-bsp -> build-debix
SRC_PATH="../../$DEPLOY_SRC_DIR"

if [ -d "$SRC_PATH" ]; then
    cp "$SRC_PATH/cred.conf" .
    cp "$SRC_PATH/deploy_libs.sh" .
    cp "$SRC_PATH/deploy_dts.sh" .
    chmod +x *.sh
    echo "[OK] Scripts copies dans $(pwd)"
else
    echo "[ATTENTION] Dossier deploy introuvable a l'emplacement prevu ($SRC_PATH)."
fi

echo "======================================================="
echo " INSTALLATION TERMINEE."
echo " Dossier de travail : $(pwd)"
echo "======================================================="