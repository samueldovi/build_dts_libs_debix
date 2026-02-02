#!/bin/bash

# 1. Chargement des identifiants
if [ -f debix.conf ]; then
    source debix.conf
else
    echo "Erreur : debix.conf est introuvable !"
    exit 1
fi

TARGET="$TARGET_USER@$TARGET_IP"

# 2. Vérification des arguments
if [ $# -eq 0 ]; then
    echo "Usage : ./deploy_libs.sh nom_lib1 nom_lib2 ..."
    exit 1
fi

# 3. Boucle principale
for LIB in "$@"; do
    echo "------------------------------------------"
    echo "TRAITEMENT : $LIB"
    echo "------------------------------------------"

    # Tentative d'ajout. Si cela échoue, on tente une réparation.
    if ! devtool add "$LIB" 2>/dev/null; then
        echo "Attention : Echec de l'ajout initial de $LIB."
        echo "Tentative de nettoyage et de re-ajout..."
        
        # On force le reset pour nettoyer la recette cassée
        devtool reset "$LIB" > /dev/null 2>&1
        # On supprime le dossier source potentiellement corrompu
        rm -rf "workspace/sources/$LIB"
        
        # On réessaie d'ajouter proprement
        if ! devtool add "$LIB"; then
            echo "Erreur critique : Impossible d'ajouter la recette $LIB. Passage a la suivante."
            continue
        fi
    fi

    echo "Compilation de $LIB en cours..."
    if devtool build "$LIB"; then
        echo "Deploiement vers $TARGET..."
        devtool deploy-target "$LIB" "$TARGET"
        if [ $? -eq 0 ]; then
            echo "Succes pour $LIB."
        else
            echo "Erreur lors du transfert SSH pour $LIB."
        fi
    else
        echo "Erreur : La compilation de $LIB a echoue."
    fi
    
    echo ""
done