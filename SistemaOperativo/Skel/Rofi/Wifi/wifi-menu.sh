#!/usr/bin/env bash

# WiFi Manager for Rofi
# Requires: rofi, nmcli

THEME_FILE="$HOME/.config/rofi/wifi/theme.rasi"
ROFI_CMD="rofi -dmenu -theme $THEME_FILE"

# Helpers

notify() {
    echo "[WiFi] $1" >&2
    command -v notify-send &>/dev/null && \
        notify-send "WiFi Manager" "$1" 2>/dev/null || true
}

signal_bar() {
    local s=$1
    if   [ "$s" -ge 80 ]; then echo "▂▄▆█"
    elif [ "$s" -ge 60 ]; then echo "▂▄▆░"
    elif [ "$s" -ge 40 ]; then echo "▂▄░░"
    elif [ "$s" -ge 20 ]; then echo "▂░░░"
    else                        echo "░░░░"
    fi
}

current_ssid() {
    nmcli -t -f IN-USE,SSID dev wifi list 2>/dev/null \
        | grep '^\*:' \
        | head -1 \
        | cut -d: -f2
}

wifi_device() {
    local dev
    dev=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
        | grep ':wifi:connected' | cut -d: -f1 | head -1)
    if [ -z "$dev" ]; then
        dev=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
            | grep ':wifi:' | cut -d: -f1 | head -1)
    fi
    echo "$dev"
}

wifi_state() {
    nmcli radio wifi 2>/dev/null || echo "unavailable"
}

# Ethernet

ethernet_device() {
    nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
        | grep ':ethernet:' | cut -d: -f1 | head -1
}

ethernet_state() {
    local dev="$1"
    nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null \
        | grep "^${dev}:ethernet:" | cut -d: -f3 | head -1
}

ethernet_ip() {
    local dev="$1"
    nmcli -t -f IP4.ADDRESS dev show "$dev" 2>/dev/null \
        | head -1 | cut -d: -f2 | cut -d/ -f1
}

ethernet_connect() {
    local dev="$1"
    echo "" | rofi -dmenu \
        -theme "$THEME_FILE" \
        -theme-str 'entry { placeholder: ""; }' \
        -p "Ethernet..." \
        -mesg "Conectando por cable..." \
        -l 0 &
    local rofi_pid=$!
    local out
    out=$(nmcli dev connect "$dev" 2>&1)
    kill $rofi_pid 2>/dev/null
    if echo "$out" | grep -qi "activado\|activated\|successfully"; then
        notify "Ethernet conectado"
    else
        notify "Error al conectar ethernet"
    fi
}

ethernet_disconnect() {
    local dev="$1"
    nmcli dev disconnect "$dev" 2>/dev/null \
        && notify "Ethernet desconectado" \
        || notify "Error al desconectar ethernet"
}

# Menu ethernet

ethernet_menu() {
    local eth_dev="$1"
    local eth_state="$2"
    local eth_ip="$3"

    local mesg entries choice
    if [ "$eth_state" = "connected" ]; then
        mesg="Ethernet conectado"
        [ -n "$eth_ip" ] && mesg+="  |  IP: $eth_ip"
        entries="<-- Volver\nDesconectar ethernet"
    elif [ "$eth_state" = "unmanaged" ]; then
        mesg="Ethernet no gestionado por NetworkManager"
        entries="<-- Volver"
    else
        mesg="Ethernet desconectado"
        entries="<-- Volver\nConectar ethernet"
    fi

    choice=$(printf "%b" "$entries" | \
        rofi -dmenu \
        -theme "$THEME_FILE" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "[ETH] $eth_dev" \
        -mesg "$mesg")

    case "$choice" in
        "Conectar ethernet")
            ethernet_connect "$eth_dev"
            main_menu
            ;;
        "Desconectar ethernet")
            ethernet_disconnect "$eth_dev"
            main_menu
            ;;
        *)
            main_menu
            ;;
    esac
}

# Redes sin rescan bloqueante

get_networks() {
    local dev="$1"
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list ifname "$dev" 2>/dev/null \
        | grep -v '^--' \
        | awk -F: 'length($2)>0' \
        | sort -t: -k3 -rn \
        | awk -F: '!seen[$2]++'
}

# Toggle WiFi

wifi_toggle() {
    local state
    state=$(wifi_state)
    if [ "$state" = "enabled" ]; then
        local dev
        dev=$(wifi_device)
        [ -n "$dev" ] && nmcli dev disconnect "$dev" 2>/dev/null
        sleep 1
        nmcli radio wifi off 2>/dev/null
        notify "WiFi desactivado"
    else
        nmcli radio wifi on 2>/dev/null
        notify "WiFi activado"
        sleep 1
    fi
}

# Olvidar red

forget_network() {
    local ssid="$1"
    local dev
    dev=$(wifi_device)

    if [ -n "$dev" ]; then
        nmcli dev disconnect "$dev" 2>/dev/null
        sleep 1
    fi

    while nmcli connection show "$ssid" &>/dev/null 2>&1; do
        nmcli connection delete "$ssid" 2>/dev/null
        sleep 1
    done

    notify "Red $ssid olvidada"
}

# Menu red conectada

connected_menu() {
    local ssid="$1"

    local choice
    choice=$(printf "%s\n" \
        "<-- Volver" \
        "Desconectarme" \
        "Olvidar red" | \
        rofi -dmenu \
        -theme "$THEME_FILE" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "[ CONECTADO ] $ssid" \
        -mesg "Conectado a esta red")

    case "$choice" in
        "Desconectarme")
            local dev
            dev=$(wifi_device)
            nmcli dev disconnect "$dev" 2>/dev/null \
                && notify "Desconectado de $ssid" \
                || notify "Error al desconectar"
            main_menu
            ;;
        "Olvidar red")
            forget_network "$ssid"
            main_menu
            ;;
        *)
            main_menu
            ;;
    esac
}

# Menu red guardada no conectada

saved_menu() {
    local ssid="$1" is_sec="$2"

    local choice
    choice=$(printf "%s\n" \
        "<-- Volver" \
        "Conectarme" \
        "Olvidar red" | \
        rofi -dmenu \
        -theme "$THEME_FILE" \
        -theme-str 'inputbar { enabled: false; }' \
        -filter "" -no-custom \
        -p "[GUARDADA] $ssid" \
        -mesg "Red guardada - no conectado")

    case "$choice" in
        "Conectarme")
            connect_wifi "$ssid" "$is_sec"
            ;;
        "Olvidar red")
            forget_network "$ssid"
            main_menu
            ;;
        *)
            main_menu
            ;;
    esac
}

# Conexion

connect_wifi() {
    local ssid="$1" secured="$2"
    local dev password=""
    local mesg="Introduce la contrasena para conectarte"
    dev=$(wifi_device)

    if nmcli connection show "$ssid" &>/dev/null 2>&1; then
        echo "" | rofi -dmenu \
            -theme "$THEME_FILE" \
            -theme-str 'entry { placeholder: ""; }' \
            -p "Conectando..." \
            -mesg "Conectando a $ssid..." \
            -l 0 &
        local rofi_pid=$!
        local out
        out=$(nmcli connection up "$ssid" 2>&1)
        kill $rofi_pid 2>/dev/null
        if echo "$out" | grep -qi "activado\|activated\|successfully"; then
            notify "Conectado a $ssid"
            main_menu
            return
        else
            nmcli connection delete "$ssid" 2>/dev/null
        fi
    fi

    local intentos=0
    while true; do
        if [ "$secured" = "yes" ]; then
            password=$(echo "" | rofi -dmenu \
                -theme "$THEME_FILE" \
                -theme-str 'entry { placeholder: "Introduce la contrasena..."; }' \
                -p "$ssid" \
                -mesg "$mesg" \
                -password -l 0)

            if [ -z "$password" ]; then
                notify "Conexion cancelada"
                main_menu
                return
            fi
        fi

        echo "" | rofi -dmenu \
            -theme "$THEME_FILE" \
            -theme-str 'entry { placeholder: ""; }' \
            -p "Conectando..." \
            -mesg "Conectando a $ssid..." \
            -l 0 &
        local rofi_pid=$!

        local nmcli_output
        nmcli_output=$(nmcli dev wifi connect "$ssid" \
            password "$password" \
            ifname "$dev" 2>&1)
        local exit_code=$?

        kill $rofi_pid 2>/dev/null

        if [ $exit_code -eq 0 ] && \
           echo "$nmcli_output" | grep -qi "activado\|activated\|successfully"; then
            notify "Conectado a $ssid"
            main_menu
            return
        fi

        if echo "$nmcli_output" | grep -qi \
            "secrets\|password\|contrasena\|incorrecto\|wrong\|failed\|no-secrets"; then
            nmcli connection delete "$ssid" 2>/dev/null
            intentos=$((intentos + 1))
            mesg="Contrasena incorrecta - Intento $intentos de 3"

            if [ "$intentos" -ge 3 ]; then
                echo "" | rofi -dmenu \
                    -theme "$THEME_FILE" \
                    -p "Error" \
                    -mesg "Demasiados intentos fallidos" \
                    -l 0
                main_menu
                return
            fi
        else
            notify "Conectado a $ssid (sin IP)"
            main_menu
            return
        fi
    done
}

# Menu principal

main_menu() {
    local state current dev mesg entries=""
    declare -A net_map

    state=$(wifi_state)
    current=$(current_ssid)
    dev=$(wifi_device)

    # Seccion ethernet
    local eth_dev eth_state eth_ip eth_label
    eth_dev=$(ethernet_device)

    if [ -n "$eth_dev" ]; then
        eth_state=$(ethernet_state "$eth_dev")
        eth_ip=$(ethernet_ip "$eth_dev")

        case "$eth_state" in
            connected)
                eth_label="[ETH] Conectado"
                [ -n "$eth_ip" ] && eth_label+="  |  $eth_ip"
                ;;
            unmanaged)
                eth_label="[ETH] No gestionado"
                ;;
            disconnected)
                eth_label="[ETH] Desconectado  -  Conectar cable"
                ;;
            *)
                eth_label="[ETH] $eth_state"
                ;;
        esac
        entries+="${eth_label}\n"
        entries+="-----------------------------\n"
    fi

    #  Seccion wifi
    if [ "$state" = "enabled" ]; then

        if [ -n "$current" ]; then
            mesg="WiFi ON | [CONECTADO] $current"
        else
            mesg="WiFi ON | Sin conexion"
        fi

        entries+="[OFF] Desactivar WiFi\n"
        entries+="[ R ] Actualizar lista\n"
        entries+="-----------------------------\n"

        if [ -z "$dev" ]; then
            entries+="[!] No se detecto adaptador WiFi\n"
        else
            local saved_nets net_list
            saved_nets=$(nmcli -t -f NAME connection show 2>/dev/null)
            net_list=$(get_networks "$dev")

            if [ -z "$net_list" ]; then
                entries+="[!] No se encontraron redes\n"
            else
                while IFS=: read -r inuse ssid signal security; do
                    [ -z "$ssid" ] && continue

                    local bar lock label is_sec saved
                    bar=$(signal_bar "$signal")
                    lock=""
                    [ -n "$security" ] && \
                        [ "$security" != "--" ] && lock=" [*]"
                    is_sec="no"
                    [ -n "$security" ] && \
                        [ "$security" != "--" ] && is_sec="yes"
                    saved=""
                    echo "$saved_nets" | grep -q "^${ssid}$" && saved=" [G]"

                    if [ "$ssid" = "$current" ]; then
                        label="${bar}${lock}  ${ssid}  (${signal}%) - conectado"
                    else
                        label="${bar}${lock}${saved}  ${ssid}  (${signal}%)"
                    fi

                    net_map["$label"]="${ssid}|||${is_sec}"
                    entries+="${label}\n"

                done <<< "$net_list"
            fi
        fi

    elif [ "$state" = "disabled" ]; then
        mesg="WiFi OFF | Sin conexion"
        entries+="[ON] Activar WiFi\n"
    else
        mesg="WiFi no disponible"
        entries+="[!] No se detecto hardware WiFi\n"
    fi

    local choice
    choice=$(printf "%b" "$entries" | $ROFI_CMD -p "Red" -mesg "$mesg" -i)
    [ -z "$choice" ] && exit 0

    case "$choice" in
        *"[ETH]"*)
            [ -n "$eth_dev" ] && ethernet_menu "$eth_dev" "$eth_state" "$eth_ip"
            ;;
        *"Desactivar WiFi"*|*"Activar WiFi"*)
            wifi_toggle
            main_menu
            ;;
        *"Actualizar lista"*)
            local rescan_dev
            rescan_dev=$(wifi_device)
            [ -n "$rescan_dev" ] && \
                nmcli dev wifi rescan ifname "$rescan_dev" 2>/dev/null &
            main_menu
            ;;
        "-----------------------------"|*"[!]"*)
            main_menu
            ;;
        *)
            local entry="${net_map[$choice]}"
            if [ -n "$entry" ]; then
                local ssid is_sec
                ssid="${entry%|||*}"
                is_sec="${entry#*|||}"

                if [ "$ssid" = "$current" ]; then
                    connected_menu "$ssid"
                elif nmcli connection show "$ssid" &>/dev/null 2>&1; then

                    saved_menu "$ssid" "$is_sec"
                else
                    connect_wifi "$ssid" "$is_sec"
                fi
            else
                main_menu
            fi
            ;;
    esac
}

# Inicio
main_menu
