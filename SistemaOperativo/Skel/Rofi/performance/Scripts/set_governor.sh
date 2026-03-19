#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"
RETURN_OPTION="⬅️  Volver al Menú Principal"

# ─── Governors que queremos mostrar ──────────────────────────────────────────
WANTED_GOVERNORS=("performance" "schedutil" "powersave")

# ─── Obtener governor actual ──────────────────────────────────────────────────
CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null \
    || echo "no disponible")

# ─── Obtener governors disponibles en este sistema ───────────────────────────
AVAILABLE=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)

# Si no hay governors disponibles (VM sin cpufreq)
if [ -z "$AVAILABLE" ]; then
    echo "" | rofi -dmenu \
        -p "Governor" \
        -mesg "⚠ Este sistema no soporta control de governor
(Normal en máquinas virtuales)" \
        -theme "$ROFI_THEME" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -l 0
    exec "$MASTER_SCRIPT"
    exit 0
fi

# ─── Construir opciones solo con los governors que queremos ──────────────────
OPTIONS="$RETURN_OPTION\n"

for gov in "${WANTED_GOVERNORS[@]}"; do
    # Solo mostrar si está disponible en el sistema
    if echo "$AVAILABLE" | grep -qw "$gov"; then
        case "$gov" in
            performance) desc="Máximo rendimiento, siempre al máximo" ;;
            schedutil)   desc="Inteligente, recomendado para escritorio" ;;
            powersave)   desc="Ahorro de energía, mínima velocidad" ;;
        esac

        # Marcar el governor activo
        if [ "$gov" = "$CURRENT_GOV" ]; then
            OPTIONS+="✅  $gov — $desc\n"
        else
            OPTIONS+="⚡  $gov — $desc\n"
        fi
    fi
done

# ─── Menú SIN búsqueda ────────────────────────────────────────────────────────
CHOICE=$(echo -e "$OPTIONS" | rofi -dmenu \
    -p "Governor CPU" \
    -mesg "Actual: $CURRENT_GOV  |  CPU: $(nproc) núcleos" \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom)

[ -z "$CHOICE" ] && exit 0

# ─── Volver al menú principal ─────────────────────────────────────────────────
if [ "$CHOICE" = "$RETURN_OPTION" ]; then
    exec "$MASTER_SCRIPT"
    exit 0
fi

# ─── Extraer nombre del governor ─────────────────────────────────────────────
GOV_NAME=$(echo "$CHOICE" | sed 's/^[✅⚡]  //' | awk '{print $1}')

# ─── Aplicar con terminal ─────────────────────────────────────────────────────
x-terminal-emulator -e bash -c "
    echo 'Aplicando governor: $GOV_NAME en todos los núcleos...'
    echo ''

    SUCCESS=true
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo '$GOV_NAME' | sudo tee \$cpu > /dev/null
        if [ \$? -ne 0 ]; then
            SUCCESS=false
            echo '❌ Error en \$cpu'
        fi
    done

    if \$SUCCESS; then
        echo '✅ Governor aplicado: $GOV_NAME'
        echo '   Núcleos actualizados: \$(nproc)'
        echo ''
        echo '⚠  Nota: este cambio no persiste tras reinicio'
        echo '   Para hacerlo permanente instala cpupower:'
        echo '   sudo apt install linux-tools-common'
    fi

    echo ''
    read -p 'Presiona Enter para volver...'
"

# ─── Volver al mismo menú mostrando el nuevo governor ────────────────────────
exec "$0"
