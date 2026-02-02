#!/bin/bash

# 1. Chargement des identifiants
if [ -f cred.conf ]; then
    source cred.conf
else
    echo "[ERREUR] cred.conf est introuvable !"
    exit 1
fi

TARGET="$TARGET_USER@$TARGET_IP"

# 2. Verification des arguments
if [ $# -eq 0 ]; then
    echo "Usage : ./deploy_libs.sh nom_lib1 nom_lib2 ..."
    exit 1
fi

# 3. Boucle principale
for LIB in "$@"; do
    echo "------------------------------------------"
    echo "TRAITEMENT : $LIB"
    echo "------------------------------------------"

    # Preparation
    echo ">>> Preparation de $LIB..."
    
    # Verification de l'existence de la recette dans les layers
    if ! bitbake-layers show-recipes "$LIB" > /dev/null 2>&1; then
        echo "[ERREUR CRITIQUE] La recette $LIB est introuvable dans vos layers."
        echo "Verifiez votre bblayers.conf."
        continue
    fi

    # Tentative de modification (modify)
    devtool modify "$LIB" > /dev/null 2>&1
    
    # Si modify a echoue mais que le dossier n'est pas propre, on nettoie
    if [ ! -d "workspace/sources/$LIB" ]; then
        echo "[INFO] Echec de l'ajout initial. Tentative de nettoyage..."
        devtool reset "$LIB" > /dev/null 2>&1
        rm -rf "workspace/sources/$LIB"
        
        if ! devtool modify "$LIB"; then
             echo "[ERREUR] Impossible de preparer $LIB. Abandon."
             continue
        fi
    fi

    # Compilation
    echo ">>> Compilation de $LIB en cours..."
    if devtool build "$LIB"; then
        echo ">>> Deploiement vers $TARGET..."
        devtool deploy-target "$LIB" "$TARGET"
        if [ $? -eq 0 ]; then
            echo "[SUCCES] $LIB deploye."
        else
            echo "[ERREUR] Echec du transfert SSH pour $LIB."
        fi
    else
        echo "[ERREUR] La compilation de $LIB a echoue."
    fi
    
    echo ""
done