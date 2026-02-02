#!/bin/bash
set -e

# ==========================================
# CONFIG
# ==========================================
SOURCES="../sources"
BUILD_CONF="conf/bblayers.conf"
WORKSPACE="workspace/sources"

META_OE="$SOURCES/meta-openembedded"
META_FS="$SOURCES/meta-freescale"
META_FS_DISTRO="$SOURCES/meta-freescale-distro"
META_FS_3P="$SOURCES/meta-freescale-3rdparty"

LAYERS=(
    "$META_OE/meta-oe"
    "$META_OE/meta-python"
    "$META_OE/meta-networking"
    "$META_OE/meta-multimedia"
    "$META_FS"
    "$META_FS_DISTRO"
    "$META_FS_3P"
)

# ==========================================
# USAGE
# ==========================================
if [ $# -eq 0 ]; then
    echo "Usage: $0 lib1 lib2 ..."
    exit 1
fi

# ==========================================
# PRECHECK
# ==========================================
command -v bitbake >/dev/null || {
    echo "[ERREUR] Environnement Yocto non sourcé"
    exit 1
}

command -v devtool >/dev/null || {
    echo "[ERREUR] devtool introuvable"
    exit 1
}

# ==========================================
# CLONE LAYERS SI NECESSAIRE
# ==========================================
[ -d "$META_OE" ] || git clone https://git.openembedded.org/meta-openembedded "$META_OE"
[ -d "$META_FS" ] || git clone https://github.com/Freescale/meta-freescale "$META_FS"
[ -d "$META_FS_DISTRO" ] || git clone https://github.com/Freescale/meta-freescale-distro "$META_FS_DISTRO"
[ -d "$META_FS_3P" ] || git clone https://github.com/Freescale/meta-freescale-3rdparty "$META_FS_3P"

# ==========================================
# AJOUT DES LAYERS
# ==========================================
echo "=== Vérification des layers i.MX8 ==="

for L in "${LAYERS[@]}"; do
    NAME=$(basename "$L")
    if ! grep -q "$NAME" "$BUILD_CONF"; then
        echo "[ADD] $NAME"
        bitbake-layers add-layer "$L"
    else
        echo "[OK] $NAME"
    fi
done

# ==========================================
# BUILD DES LIBS
# ==========================================
for LIB in "$@"; do
    echo "=========================================="
    echo "LIB : $LIB"
    echo "=========================================="

    if ! bitbake-layers show-recipes "$LIB" >/dev/null 2>&1; then
        echo "[ERREUR] Recette $LIB introuvable (layer manquant ?)"
        continue
    fi

    if [ ! -d "$WORKSPACE/$LIB" ]; then
        echo "[INFO] devtool modify $LIB"
        devtool modify "$LIB" || continue
    fi

    echo "[INFO] devtool build $LIB"
    if devtool build "$LIB"; then
        echo "[SUCCES] $LIB compilée"
    else
        echo "[ERREUR] Build échoué pour $LIB"
        devtool reset "$LIB" || true
    fi

    echo
done
