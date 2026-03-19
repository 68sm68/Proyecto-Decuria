#!/usr/bin/env bash

THEME_FILE="$HOME/.config/rofi/wifi/theme.rasi"

# ─── Detectar backlight ───────────────────────────────────────────────────────

find_backlight() {
    for dev in /sys/class/backlight/*/; do
        [ -f "${dev}brightness" ] && echo "$dev" && return
    done
    echo ""
}

get_brightness() {
    local dev="$1" current max pct
    current=$(cat "${dev}brightness" 2>/dev/null || echo 0)
    max=$(cat "${dev}max_brightness" 2>/dev/null || echo 100)
    pct=$(( current * 100 / max ))
    echo "$pct"
}

brightness_bar() {
    local pct=$1
    local filled=$(( pct / 10 ))
    local empty=$(( 10 - filled ))
    local bar=""
    for i in $(seq 1 $filled); do bar+="#"; done
    for i in $(seq 1 $empty); do bar+="-"; done
    echo "[$bar]"
}

# ─── Detectar bateria ─────────────────────────────────────────────────────────

find_battery() {
    for bat in /sys/class/power_supply/BAT*; do
        [ -f "$bat/capacity" ] && echo "$bat" && return
    done
    echo ""
}

find_ac() {
    for ac in /sys/class/power_supply/AC* \
              /sys/class/power_supply/ADP* \
              /sys/class/power_supply/ACAD*; do
        [ -f "$ac/online" ] && echo "$ac" && return
    done
    echo ""
}

battery_bar() {
    local pct=$1
    local filled=$(( pct / 10 ))
    local empty=$(( 10 - filled ))
    local bar=""
    for i in $(seq 1 $filled); do bar+="#"; done
    for i in $(seq 1 $empty); do bar+="-"; done
    echo "[$bar]"
}

# ─── Leer datos bateria ───────────────────────────────────────────────────────

BAT=$(find_battery)
AC=$(find_ac)
BACKLIGHT=$(find_backlight)

ac_online=0
[ -n "$AC" ] && ac_online=$(cat "$AC/online" 2>/dev/null || echo 0)

# ─── Menu principal ───────────────────────────────────────────────────────────

main_menu() {
    local entries="" mesg=""

    # ── Seccion brillo ────────────────────────────────────────────────────────
    if [ -n "$BACKLIGHT" ]; then
        local bri bri_bar
        bri=$(get_brightness "$BACKLIGHT")
        bri_bar=$(brightness_bar "$bri")
        mesg="Brillo: $bri%  $bri_bar"
        entries+="[+] Subir brillo\n"
        entries+="[-] Bajar brillo\n"
    else
        mesg="Brillo: no disponible"
        entries+="[+] Subir brillo\n"
        entries+="[-] Bajar brillo\n"
    fi

    entries+="-----------------------------\n"

    # ── Seccion bateria ───────────────────────────────────────────────────────
    if [ -n "$BAT" ]; then
        local capacity status bar estado enchufe tiempo=""
        capacity=$(cat "$BAT/capacity" 2>/dev/null || echo "?")
        status=$(cat "$BAT/status" 2>/dev/null || echo "Desconocido")
        bar=$(battery_bar "$capacity")

        if [ -f "$BAT/energy_now" ] && [ -f "$BAT/power_now" ]; then
            energy_now=$(cat "$BAT/energy_now")
            power_now=$(cat "$BAT/power_now")
            energy_full=$(cat "$BAT/energy_full" 2>/dev/null || echo 0)
            if [ "$power_now" -gt 0 ]; then
                if [ "$status" = "Discharging" ] || [ "$status" = "Descargando" ]; then
                    mins=$(( energy_now * 60 / power_now ))
                else
                    mins=$(( (energy_full - energy_now) * 60 / power_now ))
                fi
                horas=$(( mins / 60 ))
                minutos=$(( mins % 60 ))
                tiempo="${horas}h ${minutos}min"
            fi
        fi

        if   [ "$capacity" -ge 80 ]; then icon="[====]"
        elif [ "$capacity" -ge 60 ]; then icon="[=== ]"
        elif [ "$capacity" -ge 40 ]; then icon="[==  ]"
        elif [ "$capacity" -ge 20 ]; then icon="[=   ]"
        else                              icon="[!   ]"
        fi

        case "$status" in
            Charging|Cargando)       estado="Cargando"    ;;
            Discharging|Descargando) estado="Descargando" ;;
            Full|Completo)           estado="Completo"    ;;
            *)                       estado="$status"     ;;
        esac

        [ "$ac_online" = "1" ] && enchufe="Enchufado" || enchufe="Sin corriente"

        mesg+="  |  Bateria: $capacity%  $bar"
        entries+="$icon  $capacity%  -  $estado\n"
        entries+="Corriente:  $enchufe\n"
        [ -n "$tiempo" ] && entries+="Tiempo restante:  $tiempo\n"

    else
        [ "$ac_online" = "1" ] && enchufe="Enchufado" || enchufe="Sin corriente"
        mesg+="  |  Sin bateria"
        entries+="[AC]  Solo corriente alterna\n"
        entries+="Corriente:  $enchufe\n"
    fi

    entries+="-----------------------------\n"
    entries+="Cerrar"

    local choice
    choice=$(printf "%b" "$entries" | rofi -dmenu \
        -theme "$THEME_FILE" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "Energia" \
        -mesg "$mesg")

    case "$choice" in
        *"Subir brillo"*)
            if [ -n "$BACKLIGHT" ]; then
                brightnessctl set +20% 2>/dev/null
            fi
            main_menu
            ;;
        *"Bajar brillo"*)
            if [ -n "$BACKLIGHT" ]; then
                brightnessctl set 20%- 2>/dev/null
            fi
            main_menu
            ;;
        "Cerrar"|"-----------------------------"|*)
            exit 0
            ;;
    esac
}

# ─── Inicio ───────────────────────────────────────────────────────────────────
main_menu
