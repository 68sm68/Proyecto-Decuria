#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"
RETURN_OPTION="⬅️  Volver al Menú Principal"

# ─── Valor actual ─────────────────────────────────────────────────────────────
CURRENT_SWAP=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "desconocido")

# ─── Opciones con descripción ─────────────────────────────────────────────────
OPTIONS="$RETURN_OPTION
0   — Sin swap (RAM abundante)
10  — SSD / Alto rendimiento
30  — SSD / Equilibrado
60  — Valor por defecto del sistema
80  — HDD / Ahorro de RAM
100 — Swap agresivo (poca RAM)"

# ─── Menú SIN búsqueda ────────────────────────────────────────────────────────
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu \
    -p "Swappiness" \
    -mesg "Valor actual: $CURRENT_SWAP  |  Rango: 0-100" \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom)

[ -z "$CHOICE" ] && exit 0

# ─── Volver al menú principal ─────────────────────────────────────────────────
if [ "$CHOICE" = "$RETURN_OPTION" ]; then
    exec "$MASTER_SCRIPT"
    exit 0
fi

# ─── Extraer solo el número ───────────────────────────────────────────────────
VALUE=$(echo "$CHOICE" | awk '{print $1}')

# Validar que es un número entre 0 y 100
if ! [[ "$VALUE" =~ ^[0-9]+$ ]] || [ "$VALUE" -gt 100 ]; then
    notify-send "❌ Swappiness" "Valor inválido: $VALUE"
    exec "$0"
fi

# ─── Aplicar con terminal para pedir sudo ────────────────────────────────────
x-terminal-emulator -e bash -c "
    echo 'Aplicando swappiness = $VALUE...'
    echo ''

    # Aplicar en tiempo real
    echo $VALUE | sudo tee /proc/sys/vm/swappiness > /dev/null

    if [ \$? -eq 0 ]; then
        # Persistir en sysctl.conf para que sobreviva reinicios
        if grep -q 'vm.swappiness' /etc/sysctl.conf; then
            sudo sed -i 's/^vm.swappiness=.*/vm.swappiness=$VALUE/' /etc/sysctl.conf
        else
            echo 'vm.swappiness=$VALUE' | sudo tee -a /etc/sysctl.conf > /dev/null
        fi
        echo '✅ Swappiness aplicado y guardado: $VALUE'
        echo '   (Persistirá tras reinicio)'
    else
        echo '❌ Error al aplicar swappiness'
    fi

    echo ''
    read -p 'Presiona Enter para volver...'
"

# ─── Volver al mismo menú para ver el nuevo valor ────────────────────────────
exec "$0"
