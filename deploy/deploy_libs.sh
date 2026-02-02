#!/bin/bash
set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
SOURCES="../sources"
BUILD_CONF="conf/bblayers.conf"
WORKSPACE="workspace/sources"

# URLs des dépôts de layers
META_OE_URL="https://git.openembedded.org/meta-openembedded"
META_FS_URL="https://github.com/Freescale/meta-freescale"
META_FS_DISTRO_URL="https://github.com/Freescale/meta-freescale-distro"
META_FS_3P_URL="https://github.com/Freescale/meta-freescale-3rdparty"

# Chemins des layers
META_OE="$SOURCES/meta-openembedded"
META_FS="$SOURCES/meta-freescale"
META_FS_DISTRO="$SOURCES/meta-freescale-distro"
META_FS_3P="$SOURCES/meta-freescale-3rdparty"

# Liste des sous-layers meta-openembedded à ajouter
LAYERS=(
    "$META_OE/meta-oe"
    "$META_OE/meta-python"
    "$META_OE/meta-networking"
    "$META_OE/meta-multimedia"
    "$META_FS"
    "$META_FS_DISTRO"
    "$META_FS_3P"
)

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERREUR]${NC} $1"
}

# ============================================================================
# FONCTION : RECHERCHE SUR OPENEMBEDDED LAYER INDEX
# ============================================================================
search_layer_index() {
    local RECIPE=$1
    log_info "Recherche de $RECIPE sur layers.openembedded.org..."
    
    # Note: Cette fonction affiche l'URL pour une recherche manuelle
    # Une implémentation complète nécessiterait curl/wget et parsing HTML/API
    local SEARCH_URL="https://layers.openembedded.org/layerindex/branch/master/recipes/?q=$RECIPE"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Recherche manuelle recommandée :"
    echo "  $SEARCH_URL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Si curl est disponible, on peut tenter une recherche basique
    if command -v curl &> /dev/null; then
        log_info "Tentative de recherche automatique..."
        local RESULT=$(curl -s "$SEARCH_URL" 2>/dev/null | grep -o "meta-[a-zA-Z0-9-]*" | sort -u | head -5)
        
        if [ ! -z "$RESULT" ]; then
            echo "Layers potentiels trouvés :"
            echo "$RESULT" | while read layer; do
                echo "  - $layer"
            done
            echo ""
        fi
    fi
}

# ============================================================================
# AFFICHAGE DE L'USAGE
# ============================================================================
if [ $# -eq 0 ]; then
    echo "======================================================================="
    echo "  Script de build et déploiement de bibliothèques Yocto"
    echo "======================================================================="
    echo ""
    echo "Usage: $0 [OPTIONS] lib1 lib2 lib3 ..."
    echo ""
    echo "Options:"
    echo "  --search    Rechercher les recettes sur OpenEmbedded Layer Index"
    echo "  --help      Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0 libgpiod i2c-tools"
    echo "  $0 --search libusb"
    echo ""
    echo "======================================================================="
    exit 1
fi

# ============================================================================
# MODE RECHERCHE
# ============================================================================
if [ "$1" = "--search" ]; then
    shift
    if [ $# -eq 0 ]; then
        log_error "Spécifiez au moins une recette à rechercher"
        exit 1
    fi
    
    for RECIPE in "$@"; do
        search_layer_index "$RECIPE"
    done
    exit 0
fi

if [ "$1" = "--help" ]; then
    $0
    exit 0
fi

# ============================================================================
# VÉRIFICATIONS PRÉALABLES
# ============================================================================
log_info "Vérification de l'environnement Yocto..."

# Vérifier que bitbake est disponible
if ! command -v bitbake &> /dev/null; then
    log_error "bitbake introuvable - environnement Yocto non sourcé"
    echo ""
    echo "Veuillez d'abord sourcer l'environnement Yocto :"
    echo "  cd debix-yocto-bsp/build-debix"
    echo "  source setup-environment"
    echo ""
    exit 1
fi
log_success "bitbake disponible"

# Vérifier que devtool est disponible
if ! command -v devtool &> /dev/null; then
    log_error "devtool introuvable"
    exit 1
fi
log_success "devtool disponible"

# Vérifier la présence du fichier de configuration
if [ ! -f "$BUILD_CONF" ]; then
    log_error "Fichier de configuration introuvable : $BUILD_CONF"
    log_info "Êtes-vous dans le bon répertoire de build ?"
    exit 1
fi
log_success "Configuration de build trouvée"

# ============================================================================
# CLONAGE DES LAYERS SI NÉCESSAIRE
# ============================================================================
log_info "Vérification et clonage des layers requis..."

clone_layer() {
    local LAYER_PATH=$1
    local LAYER_URL=$2
    local LAYER_NAME=$(basename "$LAYER_PATH")
    
    if [ ! -d "$LAYER_PATH" ]; then
        log_info "Clonage de $LAYER_NAME..."
        
        # Créer le répertoire parent si nécessaire
        mkdir -p "$(dirname "$LAYER_PATH")"
        
        git clone "$LAYER_URL" "$LAYER_PATH"
        
        if [ $? -eq 0 ]; then
            log_success "$LAYER_NAME cloné"
        else
            log_error "Échec du clonage de $LAYER_NAME"
            return 1
        fi
    else
        log_success "$LAYER_NAME déjà présent"
    fi
    return 0
}

# Cloner les layers principaux
clone_layer "$META_OE" "$META_OE_URL" || exit 1
clone_layer "$META_FS" "$META_FS_URL" || exit 1
clone_layer "$META_FS_DISTRO" "$META_FS_DISTRO_URL" || exit 1
clone_layer "$META_FS_3P" "$META_FS_3P_URL" || exit 1

# ============================================================================
# AJOUT DES LAYERS À LA CONFIGURATION
# ============================================================================
log_info "Ajout des layers à la configuration de build..."

for L in "${LAYERS[@]}"; do
    LAYER_NAME=$(basename "$L")
    
    if [ ! -d "$L" ]; then
        log_warning "Layer introuvable : $L"
        continue
    fi
    
    # Vérifier si le layer est déjà ajouté
    if grep -q "$LAYER_NAME" "$BUILD_CONF" 2>/dev/null; then
        log_success "$LAYER_NAME déjà configuré"
    else
        log_info "Ajout de $LAYER_NAME..."
        
        if bitbake-layers add-layer "$L" 2>&1; then
            log_success "$LAYER_NAME ajouté"
        else
            log_warning "Impossible d'ajouter $LAYER_NAME (peut-être déjà présent)"
        fi
    fi
done

# Afficher les layers actifs
echo ""
log_info "Layers actuellement actifs :"
bitbake-layers show-layers | grep -E "^(meta-|path)" || true
echo ""

# ============================================================================
# BUILD DES BIBLIOTHÈQUES
# ============================================================================
log_info "Démarrage du build des bibliothèques..."
echo ""

BUILT_SUCCESS=()
BUILT_FAILED=()
NOT_FOUND=()

for LIB in "$@"; do
    echo "=========================================================================="
    echo "  BUILD : $LIB"
    echo "=========================================================================="
    
    # Vérifier que la recette existe
    log_info "Vérification de la recette $LIB..."
    
    if ! bitbake-layers show-recipes "$LIB" &> /dev/null; then
        log_error "Recette $LIB introuvable dans les layers actuels"
        NOT_FOUND+=("$LIB")
        
        # Proposer une recherche
        echo ""
        log_info "Vous pouvez rechercher cette recette avec :"
        echo "  $0 --search $LIB"
        echo ""
        continue
    fi
    
    log_success "Recette $LIB trouvée"
    
    # Afficher les informations sur la recette
    echo ""
    log_info "Informations sur la recette :"
    bitbake-layers show-recipes "$LIB" | head -10 || true
    echo ""
    
    # Utiliser devtool pour modifier la recette (setup workspace)
    if [ ! -d "$WORKSPACE/$LIB" ]; then
        log_info "Initialisation de l'espace de travail avec devtool..."
        
        if devtool modify "$LIB" 2>&1; then
            log_success "Espace de travail initialisé pour $LIB"
        else
            log_error "Échec de l'initialisation de l'espace de travail"
            BUILT_FAILED+=("$LIB")
            continue
        fi
    else
        log_success "Espace de travail déjà initialisé pour $LIB"
    fi
    
    # Build de la bibliothèque
    log_info "Compilation de $LIB en cours..."
    echo ""
    
    if devtool build "$LIB" 2>&1; then
        log_success "✓ $LIB compilé avec succès"
        BUILT_SUCCESS+=("$LIB")
        
        # Afficher le chemin des artefacts
        echo ""
        log_info "Artefacts de build disponibles dans :"
        echo "  $WORKSPACE/$LIB"
        
    else
        log_error "✗ Échec de la compilation de $LIB"
        BUILT_FAILED+=("$LIB")
        
        # Nettoyer l'espace de travail en cas d'échec
        log_info "Nettoyage de l'espace de travail..."
        devtool reset "$LIB" 2>&1 || true
    fi
    
    echo ""
done

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================
echo "=========================================================================="
echo "  RÉSUMÉ DU BUILD"
echo "=========================================================================="
echo ""

if [ ${#BUILT_SUCCESS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Compilés avec succès (${#BUILT_SUCCESS[@]}) :${NC}"
    for lib in "${BUILT_SUCCESS[@]}"; do
        echo "  - $lib"
    done
    echo ""
fi

if [ ${#BUILT_FAILED[@]} -gt 0 ]; then
    echo -e "${RED}✗ Échecs de compilation (${#BUILT_FAILED[@]}) :${NC}"
    for lib in "${BUILT_FAILED[@]}"; do
        echo "  - $lib"
    done
    echo ""
fi

if [ ${#NOT_FOUND[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Recettes introuvables (${#NOT_FOUND[@]}) :${NC}"
    for lib in "${NOT_FOUND[@]}"; do
        echo "  - $lib"
    done
    echo ""
    echo "Pour rechercher ces recettes :"
    echo "  $0 --search ${NOT_FOUND[@]}"
    echo ""
fi

echo "=========================================================================="

# Code de sortie
if [ ${#BUILT_FAILED[@]} -gt 0 ] || [ ${#NOT_FOUND[@]} -gt 0 ]; then
    exit 1
else
    exit 0
fi