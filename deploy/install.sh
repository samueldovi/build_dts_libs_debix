#!/bin/bash
set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
MACHINE_NAME="imx8mpevk"
GIT_URL="https://github.com/debix-tech/yocto-nxp-debix"
GIT_BRANCH="L6.6.36-2.1.0-debix_model_ab"
PROJECT_DIR="debix-yocto-bsp"
BUILD_DIR="build-debix"
DEPLOY_SRC_DIR="./deploy"

# Couleurs pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 disponible"
        return 0
    else
        log_error "$1 non trouvé"
        return 1
    fi
}

# ============================================================================
# DÉBUT DE L'INSTALLATION
# ============================================================================
echo "======================================================================="
echo "   INSTALLATION YOCTO : DEBIX MODEL A (iMX8MP EVK)"
echo "======================================================================="
echo ""

# ============================================================================
# 1. VÉRIFICATION DES DÉPENDANCES SYSTÈME
# ============================================================================
log_info "Vérification des dépendances système..."

MISSING_DEPS=0

# Dépendances essentielles pour Yocto
REQUIRED_COMMANDS=(
    "git"
    "dtc"
    "scp"
    "ssh"
)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! check_command "$cmd"; then
        MISSING_DEPS=1
    fi
done

if [ $MISSING_DEPS -eq 1 ]; then
    log_error "Dépendances manquantes. Installez les paquets requis avant de continuer."
    log_info "Sur Arch/EndeavourOS: sudo pacman -S git dtc openssh"
    exit 1
fi

# ============================================================================
# 2. GESTION PYTHON (PYENV)
# ============================================================================
log_info "Vérification de l'environnement Python..."

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

if command -v pyenv &> /dev/null; then
    eval "$(pyenv init -)"
    
    # Essayer d'activer Python 3.12
    pyenv shell 3.12.8 2>/dev/null || pyenv shell 3.12 2>/dev/null || true
    
    PYTHON_VERSION=$(python --version 2>&1)
    if [[ "$PYTHON_VERSION" == *"3.12"* ]]; then
        log_success "Python actif : $PYTHON_VERSION"
    else
        log_warning "Python 3.12 non actif. Version actuelle : $PYTHON_VERSION"
        log_info "Yocto requiert Python 3.8-3.12. Continuons..."
    fi
else
    log_warning "Pyenv non trouvé. Vérification de Python système..."
    PYTHON_VERSION=$(python3 --version 2>&1 || python --version 2>&1)
    log_info "Python système : $PYTHON_VERSION"
fi

# ============================================================================
# 3. CLONAGE DU DÉPÔT
# ============================================================================
if [ ! -d "$PROJECT_DIR" ]; then
    log_info "Clonage du dépôt Git (branche: $GIT_BRANCH)..."
    git clone -b "$GIT_BRANCH" "$GIT_URL" "$PROJECT_DIR"
    
    if [ $? -ne 0 ]; then
        log_error "Échec du clonage Git."
        exit 1
    fi
    log_success "Dépôt cloné avec succès"
else
    log_warning "Dossier $PROJECT_DIR déjà existant"
    read -p "Voulez-vous continuer ? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        log_info "Installation annulée"
        exit 0
    fi
fi

# ============================================================================
# 4. ENTRÉE DANS LE DOSSIER CLONÉ
# ============================================================================
cd "$PROJECT_DIR" || {
    log_error "Impossible d'entrer dans $PROJECT_DIR"
    exit 1
}
log_success "Dossier de travail : $(pwd)"

# ============================================================================
# 5. VÉRIFICATION DU SCRIPT DE SETUP
# ============================================================================
if [ ! -f "imx-setup-release.sh" ]; then
    log_error "imx-setup-release.sh introuvable dans le dépôt cloné"
    log_info "Structure du dépôt actuelle :"
    ls -la
    exit 1
fi
log_success "Script de setup trouvé"

# ============================================================================
# 6. INITIALISATION DE L'ENVIRONNEMENT YOCTO
# ============================================================================
log_info "Configuration de la machine : $MACHINE_NAME"
log_info "Création de l'environnement de build..."

# Lancement du setup (crée le dossier build-debix)
EULA=1 MACHINE=$MACHINE_NAME source imx-setup-release.sh -b "$BUILD_DIR"

if [ ! -d "$BUILD_DIR" ]; then
    log_error "Le dossier de build n'a pas été créé"
    exit 1
fi
log_success "Environnement de build initialisé"

# ============================================================================
# 7. PATCH POUR ENDEAVOUROS/ARCH LINUX
# ============================================================================
CONF_FILE="conf/local.conf"
if [ -f "$CONF_FILE" ]; then
    if ! grep -q "SANITY_TESTED_DISTROS" "$CONF_FILE"; then
        log_info "Application du patch de compatibilité OS..."
        echo "" >> "$CONF_FILE"
        echo "# Patch pour EndeavourOS / Arch Linux" >> "$CONF_FILE"
        echo 'SANITY_TESTED_DISTROS = ""' >> "$CONF_FILE"
        log_success "Patch de compatibilité appliqué"
    else
        log_success "Patch de compatibilité déjà présent"
    fi
else
    log_error "Fichier de configuration introuvable : $CONF_FILE"
    exit 1
fi

# ============================================================================
# 8. CRÉATION DU RÉPERTOIRE SOURCES
# ============================================================================
SOURCES_DIR="../sources"
if [ ! -d "$SOURCES_DIR" ]; then
    log_info "Création du répertoire sources..."
    mkdir -p "$SOURCES_DIR"
    log_success "Répertoire sources créé"
fi

# ============================================================================
# 9. INSTALLATION DES SCRIPTS DE DÉPLOIEMENT
# ============================================================================
log_info "Installation des scripts de déploiement..."

# Nous sommes dans debix-yocto-bsp/build-debix
# Les scripts sources sont dans ../../deploy (depuis la racine initiale)
SRC_PATH="../../$DEPLOY_SRC_DIR"

SCRIPTS_INSTALLED=0

if [ -d "$SRC_PATH" ]; then
    # Copie de cred.conf
    if [ -f "$SRC_PATH/cred.conf" ]; then
        cp "$SRC_PATH/cred.conf" .
        log_success "cred.conf copié"
        SCRIPTS_INSTALLED=1
    else
        log_warning "cred.conf non trouvé dans $SRC_PATH"
        log_info "Création d'un template cred.conf..."
        cat > cred.conf << 'EOF'
# Configuration pour le déploiement sur l'EVK
TARGET_USER="root"
TARGET_IP="192.168.1.100"
EOF
        log_success "Template cred.conf créé - à configurer manuellement"
    fi
    
    # Copie des scripts de déploiement
    if [ -f "$SRC_PATH/deploy_libs.sh" ]; then
        cp "$SRC_PATH/deploy_libs.sh" .
        chmod +x deploy_libs.sh
        log_success "deploy_libs.sh installé"
        SCRIPTS_INSTALLED=1
    fi
    
    if [ -f "$SRC_PATH/deploy_dts.sh" ]; then
        cp "$SRC_PATH/deploy_dts.sh" .
        chmod +x deploy_dts.sh
        log_success "deploy_dts.sh installé"
        SCRIPTS_INSTALLED=1
    fi
else
    log_warning "Dossier deploy introuvable à : $SRC_PATH"
fi

if [ $SCRIPTS_INSTALLED -eq 0 ]; then
    log_warning "Aucun script de déploiement trouvé"
    log_info "Vous devrez copier manuellement :"
    log_info "  - deploy_libs.sh"
    log_info "  - deploy_dts.sh"
    log_info "  - cred.conf"
fi

# ============================================================================
# 10. VÉRIFICATIONS FINALES
# ============================================================================
log_info "Vérifications finales..."

# Vérifier que bitbake est disponible
if command -v bitbake &> /dev/null; then
    log_success "bitbake disponible"
else
    log_warning "bitbake non disponible - réouvrez votre terminal et sourcez l'environnement"
fi

# Vérifier que devtool est disponible
if command -v devtool &> /dev/null; then
    log_success "devtool disponible"
else
    log_warning "devtool non disponible - réouvrez votre terminal et sourcez l'environnement"
fi

# ============================================================================
# RÉSUMÉ DE L'INSTALLATION
# ============================================================================
echo ""
echo "======================================================================="
echo "   INSTALLATION TERMINÉE"
echo "======================================================================="
echo ""
log_success "Dossier de travail : $(pwd)"
echo ""
echo "Prochaines étapes :"
echo "  1. Fermez et rouvrez votre terminal"
echo "  2. cd $PROJECT_DIR/$BUILD_DIR"
echo "  3. source setup-environment"
echo "  4. Éditez cred.conf avec vos identifiants EVK"
echo "  5. Utilisez deploy_libs.sh et deploy_dts.sh"
echo ""
echo "Exemples d'utilisation :"
echo "  ./deploy_libs.sh libgpiod i2c-tools"
echo "  ./deploy_dts.sh mon_devicetree.dts"
echo ""
echo "======================================================================="