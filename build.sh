#!/bin/bash
set -euo pipefail

## build.sh - Script de build para SIRE (Godot 4.4 HTML5)
## Requiere: Godot 4.4.1+ en PATH (comando 'godot')

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_DIR="$SCRIPT_DIR/godot"
EXPORT_PATH="$SCRIPT_DIR/docs/godot"
PROJECT_FILE="$GODOT_DIR/project.godot"

## Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

## Verificar Godot
if ! command -v godot &>/dev/null; then
    log_error "Godot no encontrado en PATH."
    log_info "Descarga: https://godotengine.org/download"
    exit 1
fi

GODOT_VERSION=$(godot --version | head -1 || echo "unknown")
log_info "Godot detectado: $GODOT_VERSION"

## Verificar proyecto
if [ ! -f "$PROJECT_FILE" ]; then
    log_error "No se encontró project.godot en $GODOT_DIR"
    exit 1
fi

## Limpiar export anterior
if [ -d "$EXPORT_PATH" ]; then
    log_info "Limpiando export anterior..."
    rm -rf "$EXPORT_PATH"
fi

mkdir -p "$EXPORT_PATH"

## Exportar a Web
log_info "Exportando a HTML5..."
godot --headless --path "$GODOT_DIR" --export-release "Web" "$EXPORT_PATH/index.html"

## Copiar recursos estáticos si existen
if [ -d "$GODOT_DIR/assets" ]; then
    log_info "Copiando assets..."
    cp -r "$GODOT_DIR/assets" "$EXPORT_PATH/" 2>/dev/null || true
fi

## Verificar resultado
if [ -f "$EXPORT_PATH/index.html" ]; then
    log_info "Build completado exitosamente."
    log_info "Salida: $EXPORT_PATH/index.html"
    log_info "Despliegue: git push origin main (GitHub Pages desde /docs)"
else
    log_error "El build falló. No se generó index.html"
    exit 1
fi
