#!/usr/bin/env bash
# =============================================================================
#  build.sh — Totally Human · macOS Build-Skript
#  Baut die App komplett via Kommandozeile, ohne Xcode-GUI zu öffnen.
#  Benötigt: Xcode (mit Command Line Tools) auf macOS
# =============================================================================

set -euo pipefail

# ── Farben ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[FEHLER]${RESET} $*" >&2; exit 1; }

# ── Konfiguration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${SCRIPT_DIR}/TotallyHuman.xcodeproj"
SCHEME="TotallyHuman"
CONFIGURATION="${1:-Release}"          # Debug oder Release (Standard: Release)
BUILD_DIR="${SCRIPT_DIR}/build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
PRODUCTS_DIR="${BUILD_DIR}/Products"

echo -e ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         Totally Human — Build-Skript             ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# ── 1. Voraussetzungen prüfen ────────────────────────────────────────────────
info "Prüfe Voraussetzungen..."

# Betriebssystem
if [[ "$(uname)" != "Darwin" ]]; then
    error "Dieses Skript läuft nur auf macOS (aktuell: $(uname))."
fi

# Xcode / xcodebuild
if ! command -v xcodebuild &>/dev/null; then
    error "xcodebuild nicht gefunden. Bitte Xcode aus dem App Store installieren."
fi
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)
success "Gefunden: ${XCODE_VERSION}"

# Command Line Tools
if ! xcode-select -p &>/dev/null; then
    warn "Xcode Command Line Tools fehlen. Installiere jetzt..."
    xcode-select --install
    error "Bitte erneut ausführen nachdem die Installation abgeschlossen ist."
fi
success "Command Line Tools: $(xcode-select -p)"

# Projekt
if [[ ! -d "${PROJECT}" ]]; then
    error "Projektdatei nicht gefunden: ${PROJECT}"
fi
success "Projekt: ${PROJECT}"

# ── 2. Scheme & SDK ermitteln ────────────────────────────────────────────────
info "Verfügbare Schemes:"
xcodebuild -project "${PROJECT}" -list 2>/dev/null \
    | grep -A 20 "Schemes:" | grep "    " | sed 's/^/         /'

# Prüfen ob das gewünschte Scheme existiert
if ! xcodebuild -project "${PROJECT}" -list 2>/dev/null | grep -q "${SCHEME}"; then
    warn "Scheme '${SCHEME}' nicht gefunden. Verwende erstes verfügbares Scheme."
    SCHEME=$(xcodebuild -project "${PROJECT}" -list 2>/dev/null \
        | grep -A 20 "Schemes:" | grep "    " | head -1 | xargs)
    info "Verwende Scheme: ${SCHEME}"
fi

SDK="macosx"
DEPLOYMENT_TARGET="13.0"

# ── 3. Build-Verzeichnisse anlegen ───────────────────────────────────────────
info "Erstelle Build-Verzeichnisse..."
mkdir -p "${DERIVED_DATA}"
mkdir -p "${PRODUCTS_DIR}"
success "Build-Dir: ${BUILD_DIR}"

# ── 4. Bauen ─────────────────────────────────────────────────────────────────
echo ""
info "Starte Build (Konfiguration: ${BOLD}${CONFIGURATION}${RESET})..."
echo ""

BUILD_LOG="${BUILD_DIR}/build.log"

xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -sdk "${SDK}" \
    -derivedDataPath "${DERIVED_DATA}" \
    DEPLOYMENT_POSTPROCESSING=YES \
    STRIP_INSTALLED_PRODUCT=NO \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGN_IDENTITY="-" \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
    build \
    2>&1 | tee "${BUILD_LOG}" | grep -E "^(Build|error:|warning:|CompileSwift|Ld |note:|\*\*)" \
    || true

# Prüfen ob Build erfolgreich war (im Log)
if grep -q "BUILD SUCCEEDED" "${BUILD_LOG}"; then
    echo ""
    success "BUILD SUCCEEDED ✓"
elif grep -q "BUILD FAILED" "${BUILD_LOG}"; then
    echo ""
    echo -e "${RED}BUILD FAILED ✗${RESET}"
    echo ""
    echo "Relevante Fehler:"
    grep "error:" "${BUILD_LOG}" | head -30
    echo ""
    echo -e "Vollständiges Log: ${BUILD_LOG}"
    exit 1
else
    # Fallback: prüfe ob .app vorhanden
    :
fi

# ── 5. .app-Bundle finden und kopieren ───────────────────────────────────────
APP_FOUND=$(find "${DERIVED_DATA}" -name "TotallyHuman.app" -type d 2>/dev/null | head -1)

if [[ -z "${APP_FOUND}" ]]; then
    warn "TotallyHuman.app nicht unter DerivedData gefunden."
    warn "Vollständiges Log: ${BUILD_LOG}"
    exit 1
fi

success "App gebaut: ${APP_FOUND}"

# In /build/Products kopieren
DEST="${PRODUCTS_DIR}/TotallyHuman.app"
rm -rf "${DEST}"
cp -R "${APP_FOUND}" "${DEST}"
success "Kopiert nach: ${DEST}"

# ── 6. Optionale Ad-hoc Code-Signierung ──────────────────────────────────────
info "Signiere App (Ad-hoc, ohne Developer-Account)..."
if codesign --force --deep --sign "-" "${DEST}" 2>/dev/null; then
    success "Ad-hoc Signierung erfolgreich"
else
    warn "Signierung übersprungen (läuft auch unsigned in Entwicklung)"
fi

# ── 7. Zusammenfassung ───────────────────────────────────────────────────────
APP_SIZE=$(du -sh "${DEST}" | cut -f1)
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║              BUILD ABGESCHLOSSEN                 ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  App:          ${BOLD}${DEST}${RESET}"
echo -e "  Größe:        ${APP_SIZE}"
echo -e "  Konfiguration: ${CONFIGURATION}"
echo -e "  Log:          ${BUILD_LOG}"
echo ""
echo -e "  ${BOLD}Zum Starten:${RESET}"
echo -e "  open \"${DEST}\""
echo ""
echo -e "  ${BOLD}Oder direkt:${RESET}"
echo -e "  \"${DEST}/Contents/MacOS/TotallyHuman\""
echo ""

# ── 8. Optionaler Auto-Start ─────────────────────────────────────────────────
if [[ "${2:-}" == "--run" ]]; then
    info "Starte App..."
    open "${DEST}"
fi
