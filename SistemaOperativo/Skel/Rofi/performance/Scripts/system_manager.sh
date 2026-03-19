#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"

CHOICE=$(printf "%s\n" \
    "<-- Volver al Menu Principal" \
    "Actualizar sistema" \
    "Limpiar sistema" | \
    rofi -dmenu \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom \
    -p "Gestion del Sistema")

case "$CHOICE" in
    "<-- Volver al Menu Principal")
        exec "$MASTER_SCRIPT"
        ;;
    "Actualizar sistema")
        x-terminal-emulator -e bash -c "
            echo '=== Actualizando lista de paquetes ===' &&
            sudo apt update &&
            echo '' &&
            echo '=== Instalando actualizaciones ===' &&
            sudo apt upgrade -y &&
            echo '' &&
            echo '✓ Sistema actualizado correctamente' ||
            echo '✗ Error durante la actualizacion'
            echo ''
            read -p 'Presiona Enter para cerrar...'
        "
        ;;
    "Limpiar sistema")
        x-terminal-emulator -e bash -c "
            echo '=== Liberando cache de RAM ===' &&
            sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null &&
            echo '' &&
            echo '=== Eliminando paquetes huerfanos ===' &&
            sudo apt autoremove --purge -y &&
            echo '' &&
            echo '=== Limpiando cache de apt ===' &&
            sudo apt autoclean -y &&
            sudo apt clean &&
            echo '' &&
            echo '=== Limpiando logs antiguos ===' &&
            sudo journalctl --vacuum-time=7d &&
            echo '' &&
            echo '=== Limpiando archivos temporales ===' &&
            sudo rm -rf /tmp/*.tmp 2>/dev/null || true &&
            rm -rf ~/.cache/thumbnails/* 2>/dev/null || true &&
            echo '' &&
            echo '✓ Limpieza completada correctamente' ||
            echo '✗ Error durante la limpieza'
            echo ''
            read -p 'Presiona Enter para cerrar...'
        "
        ;;
    *)
        exit 0
        ;;
esac
