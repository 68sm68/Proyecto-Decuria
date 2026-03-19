#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"

CHOICE=$(printf "%s\n" \
    "<-- Volver" \
    "Ver Rendimiento (htop)" \
    "Detalles del Hardware (fastfetch)" | \
    rofi -dmenu \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom \
    -p "Rendimiento y Hardware")

case "$CHOICE" in
    "<-- Volver")
        exec "$MASTER_SCRIPT"
        ;;
    "Ver Rendimiento (htop)")
        x-terminal-emulator -e htop
        ;;
    "Detalles del Hardware (fastfetch)")
        x-terminal-emulator -e bash -c "fastfetch; read -p 'Presiona Enter para cerrar...'"
        ;;
    *)
        exit 0
        ;;
esac
