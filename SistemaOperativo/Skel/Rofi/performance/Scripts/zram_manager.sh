bash
#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"
ZRAM_CONFIG="/etc/default/zramswap"

# Leer config actual 

get_current_algo() {
    grep "^ALGO=" "$ZRAM_CONFIG" 2>/dev/null | cut -d= -f2 || echo "lzo-rle"
}

get_current_percent() {
    grep "^PERCENT=" "$ZRAM_CONFIG" 2>/dev/null | cut -d= -f2 || echo "50"
}

# Menu principal 

main_menu() {
    local algo percent mesg
    algo=$(get_current_algo)
    percent=$(get_current_percent)
    mesg="Algoritmo: $algo  |  Tamaño: $percent% de RAM"

    CHOICE=$(printf "%s\n" \
        "<-- Volver al Menu Principal" \
        "Ver estado en tiempo real" \
        "Cambiar algoritmo" \
        "Cambiar tamaño" | \
        rofi -dmenu \
        -theme "$ROFI_THEME" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "ZRAM" \
        -mesg "$mesg")

    case "$CHOICE" in
        "<-- Volver al Menu Principal")
            exec "$MASTER_SCRIPT"
            ;;
        "Ver estado en tiempo real")
            x-terminal-emulator -e bash -c \
                "watch -n1 'echo \"=== RAM ===\"; free -h; echo \"\"; echo \"=== ZRAM ===\"; zramctl; echo \"\"; echo \"=== SWAP ===\"; cat /proc/swaps'"
            main_menu
            ;;
        "Cambiar algoritmo")
            algo_menu
            ;;
        "Cambiar tamaño")
            size_menu
            ;;
        *)
            exit 0
            ;;
    esac
}

# Menu algoritmo 

algo_menu() {
    local current
    current=$(get_current_algo)

    local lzo_mark lz4_mark zstd_mark
    lzo_mark=""; lz4_mark=""; zstd_mark=""
    [ "$current" = "lzo-rle" ] && lzo_mark=" - activo"
    [ "$current" = "lz4" ]     && lz4_mark=" - activo"
    [ "$current" = "zstd" ]    && zstd_mark=" - activo"

    CHOICE=$(printf "%s\n" \
        "<-- Volver" \
        "lzo-rle  (rapido, compresion media)${lzo_mark}" \
        "lz4      (muy rapido, menos compresion)${lz4_mark}" \
        "zstd     (mejor compresion, algo mas lento)${zstd_mark}" | \
        rofi -dmenu \
        -theme "$ROFI_THEME" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "Algoritmo ZRAM" \
        -mesg "Mayor compresion = mas RAM disponible | Mayor velocidad = sistema mas fluido")

    case "$CHOICE" in
        "<-- Volver")
            main_menu
            ;;
        *"lzo-rle"*)
            x-terminal-emulator -e bash -c \
                "sudo swapoff /dev/zram0 2>/dev/null; \
                sudo systemctl stop zramswap; \
                sudo sed -i 's/^#*ALGO=.*/ALGO=lzo-rle/' $ZRAM_CONFIG && \
                sudo systemctl start zramswap && \
                echo '✓ Algoritmo cambiado a lzo-rle' || \
                echo '✗ Error al cambiar algoritmo'; \
                read -p 'Presiona Enter para volver...'"
            main_menu
            ;;
        *"lz4"*)
            x-terminal-emulator -e bash -c \
                "sudo swapoff /dev/zram0 2>/dev/null; \
                sudo systemctl stop zramswap; \
                sudo sed -i 's/^#*ALGO=.*/ALGO=lz4/' $ZRAM_CONFIG && \
                sudo systemctl start zramswap && \
                echo '✓ Algoritmo cambiado a lz4' || \
                echo '✗ Error al cambiar algoritmo'; \
                read -p 'Presiona Enter para volver...'"
            main_menu
            ;;
        *"zstd"*)
            x-terminal-emulator -e bash -c \
                "sudo swapoff /dev/zram0 2>/dev/null; \
                sudo systemctl stop zramswap; \
                sudo sed -i 's/^#*ALGO=.*/ALGO=zstd/' $ZRAM_CONFIG && \
                sudo systemctl start zramswap && \
                echo '✓ Algoritmo cambiado a zstd' || \
                echo '✗ Error al cambiar algoritmo'; \
                read -p 'Presiona Enter para volver...'"
            main_menu
            ;;
        *)
            main_menu
            ;;
    esac
}

# Menu tamaño

size_menu() {
    local current
    current=$(get_current_percent)

    local p25 p50 p75
    p25=""; p50=""; p75=""
    [ "$current" = "25" ] && p25=" - activo"
    [ "$current" = "50" ] && p50=" - activo"
    [ "$current" = "75" ] && p75=" - activo"

    CHOICE=$(printf "%s\n" \
        "<-- Volver" \
        "25%  (conservador, mas RAM libre)${p25}" \
        "50%  (recomendado, equilibrado)${p50}" \
        "75%  (agresivo, mas swap virtual)${p75}" | \
        rofi -dmenu \
        -theme "$ROFI_THEME" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "Tamaño ZRAM" \
        -mesg "Actual: $current% de RAM  |  Requiere reiniciar el servicio")

    case "$CHOICE" in
        "<-- Volver")
            main_menu
            ;;
        *"25%"*)
            x-terminal-emulator -e bash -c \
                "sudo swapoff /dev/zram0 2>/dev/null; \
                sudo systemctl stop zramswap; \
                sudo sed -i 's/^#*PERCENT=.*/PERCENT=25/' $ZRAM_CONFIG && \
                sudo systemctl start zramswap && \
                echo '✓ Tamaño cambiado a 25%' || \
                echo '✗ Error al cambiar tamaño'; \
                read -p 'Presiona Enter para volver...'"
            main_menu
            ;;
        *"50%"*)
            x-terminal-emulator -e bash -c \
                "sudo swapoff /dev/zram0 2>/dev/null; \
                sudo systemctl stop zramswap; \
                sudo sed -i 's/^#*PERCENT=.*/PERCENT=50/' $ZRAM_CONFIG && \
                sudo systemctl start zramswap && \
                echo '✓ Tamaño cambiado a 50%' || \
                echo '✗ Error al cambiar tamaño'; \
                read -p 'Presiona Enter para volver...'"
            main_menu
            ;;
        *"75%"*)
            x-terminal-emulator -e bash -c \
                "sudo swapoff /dev/zram0 2>/dev/null; \
                sudo systemctl stop zramswap; \
                sudo sed -i 's/^#*PERCENT=.*/PERCENT=75/' $ZRAM_CONFIG && \
                sudo systemctl start zramswap && \
                echo '✓ Tamaño cambiado a 75%' || \
                echo '✗ Error al cambiar tamaño'; \
                read -p 'Presiona Enter para volver...'"
            main_menu
            ;;
        *)
            main_menu
            ;;
    esac
}

# Inicio
main_menu
