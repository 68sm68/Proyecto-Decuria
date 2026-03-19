#!/usr/bin/env bash
# Panel de Control de Rendimiento Avanzado
SCRIPT_DIR="$HOME/.config/performance/scripts"
ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"

OPTIONS="📊 Rendimiento y Hardware\n🧹 Gestion del Sistema\n⚙️ Cambiar Governor (CPU)\n🔀 Ajustar Swappiness (RAM)\n🛑 Controlar Servicios (RAM)\n🚀 Ajuste de Latencia (Red)\n🖥️ Alternar Compositor (Picom)"

CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu \
    -theme "$ROFI_THEME" \
    -p "PANEL DE RENDIMIENTO AVANZADO")

case "$CHOICE" in
    "📊 Rendimiento y Hardware")
        "$SCRIPT_DIR/hardware_info.sh"
        ;;
    "🧹 Gestion del Sistema")
        "$SCRIPT_DIR/system_manager.sh"
        ;;
    "⚙️ Cambiar Governor (CPU)")
        "$SCRIPT_DIR/set_governor.sh"
        ;;
    "🔀 Ajustar Swappiness (RAM)")
        "$SCRIPT_DIR/set_swappiness.sh"
        ;;
    "🛑 Controlar Servicios (RAM)")
        "$SCRIPT_DIR/control_services.sh"
        ;;
    "🚀 Ajuste de Latencia (Red)")
        "$SCRIPT_DIR/set_network.sh"
        ;;
    "🖥️ Alternar Compositor (Picom)")
        "$SCRIPT_DIR/toggle_picom.sh"
        ;;
    *)
        exit 0
        ;;
esac
