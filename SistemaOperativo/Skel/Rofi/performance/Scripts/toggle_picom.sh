#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"
RETURN_OPTION="⬅️  Volver al Menú Principal"

# ─── Estado actual de picom ───────────────────────────────────────────────────
if pgrep -x "picom" > /dev/null; then
    STATUS="🟢  Activo"
    ACTION_LABEL="⏹  Desactivar Picom (desactiva transparencias)"
else
    STATUS="🔴  Inactivo"
    ACTION_LABEL="▶  Activar Picom (activa transparencias)"
fi

# ─── Menú SIN búsqueda ────────────────────────────────────────────────────────
CHOICE=$(echo -e "$RETURN_OPTION\n$ACTION_LABEL" | rofi -dmenu \
    -p "Compositor Picom" \
    -mesg "Estado: $STATUS" \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom)

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    "$RETURN_OPTION")
        exec "$MASTER_SCRIPT"
        ;;
    *Desactivar*)
        pkill picom
        notify-send "Compositor OFF" "Picom desactivado. Menos uso de CPU/RAM."
        exec "$0"
        ;;
    *Activar*)
        picom -b
        notify-send "Compositor ON" "Picom activado. Transparencias habilitadas."
        exec "$0"
        ;;
    *)
        exit 0
        ;;
esac
