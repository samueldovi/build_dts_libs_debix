#!/bin/bash

# 1. Chargement des identifiants
if [ -f cred.conf ]; then
    source cred.conf
else
    echo "Erreur : cred.conf est introuvable !"
    exit 1
fi

TARGET="$TARGET_USER@$TARGET_IP"

# 2. Vérification des arguments
if [ $# -eq 0 ]; then
    echo "Usage : ./deploy_libs.sh nom_lib1 nom_lib2 ..."
    exit 1
fi

# 3. Traitement de chaque bibliothèque passée en argument
for LIB in "$@"; do
    echo "------------------------------------------"
    echo "CIBLE : $LIB"
    echo "------------------------------------------"

    # Ajout au workspace (ignore l'erreur si déjà présent)
    devtool add "$LIB" 2>/dev/null || echo "Info : $LIB est déjà dans le workspace."

    # Compilation de la bibliothèque
    echo "Compilation de $LIB en cours..."
    if devtool build "$LIB"; then
        # Déploiement vers la carte
        echo "Déploiement vers $TARGET..."
        devtool deploy-target "$LIB" "$TARGET"
    else
        echo "Erreur : La compilation de $LIB a échoué. Déploiement annulé."
    fi
    
    echo -e "Traitement de $LIB terminé.\n"
done