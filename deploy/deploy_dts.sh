#!/bin/bash
set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
CRED_FILE="cred.conf"
DEFAULT_BOOT_PATH="/boot"

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
# AFFICHAGE DE L'USAGE
# ============================================================================
usage() {
    echo "======================================================================="
    echo "  Script de compilation et déploiement de Device Tree"
    echo "======================================================================="
    echo ""
    echo "Usage: $0 [OPTIONS] fichier.dts"
    echo ""
    echo "Options:"
    echo "  --help              Afficher cette aide"
    echo "  --no-deploy         Compiler uniquement (pas de déploiement SSH)"
    echo "  --boot-path PATH    Chemin de déploiement sur l'EVK (défaut: /boot)"
    echo ""
    echo "Exemples:"
    echo "  $0 imx8mp-custom.dts"
    echo "  $0 --no-deploy imx8mp-custom.dts"
    echo "  $0 --boot-path /boot/dtbs imx8mp-custom.dts"
    echo ""
    echo "Configuration:"
    echo "  Les identifiants SSH sont dans : $CRED_FILE"
    echo "======================================================================="
    exit 0
}

# ============================================================================
# ANALYSE DES ARGUMENTS
# ============================================================================
DEPLOY=true
BOOT_PATH="$DEFAULT_BOOT_PATH"
DTS_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            usage
            ;;
        --no-deploy)
            DEPLOY=false
            shift
            ;;
        --boot-path)
            BOOT_PATH="$2"
            shift 2
            ;;
        *)
            if [ -z "$DTS_FILE" ]; then
                DTS_FILE="$1"
            else
                log_error "Argument inattendu : $1"
                usage
            fi
            shift
            ;;
    esac
done

# Vérifier qu'un fichier DTS a été spécifié
if [ -z "$DTS_FILE" ]; then
    log_error "Aucun fichier DTS spécifié"
    usage
fi

# ============================================================================
# VÉRIFICATION DU FICHIER DTS
# ============================================================================
echo "======================================================================="
echo "  COMPILATION ET DÉPLOIEMENT DE DEVICE TREE"
echo "======================================================================="
echo ""

log_info "Fichier source : $DTS_FILE"

if [ ! -f "$DTS_FILE" ]; then
    log_error "Fichier introuvable : $DTS_FILE"
    exit 1
fi
log_success "Fichier DTS trouvé"

# Générer le nom du fichier DTB
DTB_FILE="${DTS_FILE%.dts}.dtb"
log_info "Fichier de sortie : $DTB_FILE"

# ============================================================================
# VÉRIFICATION DE L'ENVIRONNEMENT YOCTO
# ============================================================================
log_info "Vérification de l'environnement Yocto..."

# Vérifier que le Device Tree Compiler est disponible
if ! command -v dtc &> /dev/null; then
    log_error "dtc (Device Tree Compiler) introuvable"
    log_info "Installez-le avec : sudo pacman -S dtc"
    exit 1
fi
log_success "dtc disponible (version: $(dtc --version 2>&1 | head -1))"

# Vérifier que bitbake est disponible (environnement Yocto)
if ! command -v bitbake &> /dev/null; then
    log_error "bitbake introuvable - environnement Yocto non sourcé"
    echo ""
    echo "Veuillez d'abord sourcer l'environnement Yocto :"
    echo "  cd debix-yocto-bsp/build-debix"
    echo "  source setup-environment"
    echo ""
    exit 1
fi
log_success "Environnement Yocto détecté"

# ============================================================================
# DÉTECTION DU RÉPERTOIRE DES INCLUDES DU KERNEL
# ============================================================================
log_info "Recherche des fichiers d'include du kernel..."

# Obtenir le répertoire de staging du kernel depuis bitbake
KERNEL_INCLUDE=$(bitbake -e virtual/kernel 2>/dev/null | grep "^STAGING_KERNEL_DIR=" | cut -d'=' -f2 | tr -d '"' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$KERNEL_INCLUDE" ] || [ ! -d "$KERNEL_INCLUDE" ]; then
    log_warning "Impossible de trouver STAGING_KERNEL_DIR automatiquement"
    log_info "Tentative de détection manuelle..."
    
    # Chemins alternatifs possibles
    POSSIBLE_PATHS=(
        "../tmp/work-shared/*/kernel-source"
        "../tmp/work/*/linux-imx/*/git"
        "../downloads/git2/git.kernel.org.*"
    )
    
    for pattern in "${POSSIBLE_PATHS[@]}"; do
        FOUND=$(eval "ls -d $pattern 2>/dev/null | head -1")
        if [ ! -z "$FOUND" ] && [ -d "$FOUND" ]; then
            KERNEL_INCLUDE="$FOUND"
            break
        fi
    done
    
    if [ -z "$KERNEL_INCLUDE" ] || [ ! -d "$KERNEL_INCLUDE" ]; then
        log_error "Impossible de trouver le répertoire des sources du kernel"
        log_info "Compilez d'abord le kernel avec : bitbake virtual/kernel"
        exit 1
    fi
fi

log_success "Répertoire du kernel trouvé : $KERNEL_INCLUDE"

# Vérifier les répertoires d'include critiques
DTS_INCLUDE_DIR="$KERNEL_INCLUDE/arch/arm64/boot/dts/freescale"
if [ ! -d "$DTS_INCLUDE_DIR" ]; then
    log_error "Répertoire d'include DTS introuvable : $DTS_INCLUDE_DIR"
    exit 1
fi
log_success "Répertoire DTS Freescale : $DTS_INCLUDE_DIR"

# ============================================================================
# COMPILATION DU DEVICE TREE
# ============================================================================
echo ""
log_info "Compilation du Device Tree en cours..."
echo ""

# Options de compilation
DTC_OPTIONS=(
    -I dts                    # Input format: Device Tree Source
    -O dtb                    # Output format: Device Tree Blob
    -p 1024                   # Padding
    -i "$DTS_INCLUDE_DIR"     # Include path pour les .dtsi Freescale
)

# Ajouter le répertoire des include-prefixes si disponible
INCLUDE_PREFIXES="$KERNEL_INCLUDE/scripts/dtc/include-prefixes"
if [ -d "$INCLUDE_PREFIXES" ]; then
    DTC_OPTIONS+=(-i "$INCLUDE_PREFIXES")
fi

# Compilation
echo "Commande de compilation :"
echo "dtc ${DTC_OPTIONS[@]} -o $DTB_FILE $DTS_FILE"
echo ""

if dtc "${DTC_OPTIONS[@]}" -o "$DTB_FILE" "$DTS_FILE" 2>&1; then
    echo ""
    log_success "✓ Compilation réussie : $DTB_FILE"
    
    # Afficher les informations sur le fichier généré
    if [ -f "$DTB_FILE" ]; then
        DTB_SIZE=$(stat -c %s "$DTB_FILE" 2>/dev/null || stat -f %z "$DTB_FILE" 2>/dev/null || echo "?")
        log_info "Taille du DTB : $DTB_SIZE octets"
    fi
else
    log_error "✗ Échec de la compilation"
    exit 1
fi

# ============================================================================
# DÉPLOIEMENT SSH (SI ACTIVÉ)
# ============================================================================
if [ "$DEPLOY" = false ]; then
    echo ""
    log_info "Mode compilation uniquement - pas de déploiement"
    log_success "Fichier DTB disponible : $(pwd)/$DTB_FILE"
    exit 0
fi

echo ""
log_info "Préparation du déploiement SSH..."

# Chargement des identifiants
if [ ! -f "$CRED_FILE" ]; then
    log_error "Fichier de configuration introuvable : $CRED_FILE"
    echo ""
    echo "Créez un fichier $CRED_FILE avec le contenu suivant :"
    echo ""
    echo "TARGET_USER=\"root\""
    echo "TARGET_IP=\"192.168.1.100\""
    echo ""
    exit 1
fi

source "$CRED_FILE"

# Vérifier que les variables sont définies
if [ -z "$TARGET_USER" ] || [ -z "$TARGET_IP" ]; then
    log_error "Variables TARGET_USER ou TARGET_IP non définies dans $CRED_FILE"
    exit 1
fi

TARGET="$TARGET_USER@$TARGET_IP"
log_info "Cible de déploiement : $TARGET"
log_info "Répertoire de destination : $BOOT_PATH"

# Vérifier que SSH est disponible
if ! command -v ssh &> /dev/null; then
    log_error "ssh introuvable - installez openssh"
    exit 1
fi

if ! command -v scp &> /dev/null; then
    log_error "scp introuvable - installez openssh"
    exit 1
fi

# Test de connectivité SSH
log_info "Test de connexion SSH..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "$TARGET" "echo 'OK'" &> /dev/null; then
    log_success "Connexion SSH établie"
else
    log_error "Impossible de se connecter à $TARGET"
    log_info "Vérifiez :"
    log_info "  - L'adresse IP dans $CRED_FILE"
    log_info "  - La connexion réseau"
    log_info "  - L'authentification SSH (clés ou mot de passe)"
    exit 1
fi

# Vérifier que le répertoire de destination existe
log_info "Vérification du répertoire de destination..."
if ssh "$TARGET" "test -d $BOOT_PATH" &> /dev/null; then
    log_success "Répertoire $BOOT_PATH existe sur la cible"
else
    log_warning "Répertoire $BOOT_PATH introuvable sur la cible"
    log_info "Création du répertoire..."
    
    if ssh "$TARGET" "mkdir -p $BOOT_PATH" &> /dev/null; then
        log_success "Répertoire créé"
    else
        log_error "Impossible de créer le répertoire $BOOT_PATH"
        exit 1
    fi
fi

# Transfert du fichier
echo ""
log_info "Transfert du DTB vers l'EVK..."

REMOTE_PATH="$BOOT_PATH/$(basename $DTB_FILE)"

if scp "$DTB_FILE" "$TARGET:$REMOTE_PATH" 2>&1; then
    log_success "✓ Fichier déployé avec succès"
    log_info "Emplacement sur l'EVK : $REMOTE_PATH"
    
    # Vérifier la taille du fichier déployé
    REMOTE_SIZE=$(ssh "$TARGET" "stat -c %s $REMOTE_PATH 2>/dev/null || stat -f %z $REMOTE_PATH 2>/dev/null" 2>/dev/null || echo "?")
    log_info "Taille sur l'EVK : $REMOTE_SIZE octets"
    
else
    log_error "✗ Échec du transfert SSH"
    exit 1
fi

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================
echo ""
echo "======================================================================="
echo "  DÉPLOIEMENT TERMINÉ"
echo "======================================================================="
echo ""
log_success "Fichier local  : $(pwd)/$DTB_FILE"
log_success "Fichier distant : $TARGET:$REMOTE_PATH"
echo ""
log_info "Pour utiliser ce Device Tree :"
log_info "  1. Connectez-vous à l'EVK : ssh $TARGET"
log_info "  2. Configurez U-Boot pour charger ce DTB"
log_info "  3. Redémarrez la carte"
echo ""
echo "======================================================================="