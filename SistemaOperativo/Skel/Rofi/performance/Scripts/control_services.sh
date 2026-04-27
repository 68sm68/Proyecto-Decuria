#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"
RETURN_OPTION="⬅️  Volver al Menú Principal"

PINNED_CANDIDATES=(
    "NetworkManager.service"
    "bluetooth.service"
    "ssh.service"
    "sshd.service"
    "ufw.service"
    "cron.service"
    "cups.service"
    "avahi-daemon.service"
    "docker.service"
    "apache2.service"
    "nginx.service"
    "mysql.service"
    "postgresql.service"
    "mariadb.service"
    "lightdm.service"
    "gdm.service"
    "sddm.service"
    "firewalld.service"
)

# Una sola llamada para obtener TODO
ALL_UNIT_FILES=$(systemctl list-unit-files --type=service --plain --no-legend 2>/dev/null)
ALL_ACTIVE=$(systemctl list-units --type=service --plain --no-legend 2>/dev/null \
    | awk '{print $1}')

# Función para obtener estado desde caché 
get_status() {
    local svc="$1"
    if echo "$ALL_ACTIVE" | grep -q "^${svc}$"; then
        echo "active"
    elif echo "$ALL_UNIT_FILES" | grep -q "^${svc}"; then
        echo "inactive"
    else
        echo "unknown"
    fi
}

# Construir lista destacados desde caché 
pinned_entries=""
for svc in "${PINNED_CANDIDATES[@]}"; do
    if echo "$ALL_UNIT_FILES" | awk '{print $1}' | grep -q "^${svc}$"; then
        status=$(get_status "$svc")
        case "$status" in
            active)   icon="✅" ;;
            inactive) icon="⛔" ;;
            failed)   icon="💀" ;;
            *)        icon="⚪" ;;
        esac
        pinned_entries+="${icon} | ${svc}\n"
    fi
done

# Lista completa desde caché 
all_services=$(echo "$ALL_UNIT_FILES" | awk '{print $1}' | sort -u)

# Construir opciones 
ALL_OPTIONS="$RETURN_OPTION\n"

if [ -n "$pinned_entries" ]; then
    ALL_OPTIONS+="=====  Servicios destacados  =====\n"
    ALL_OPTIONS+="$pinned_entries"
fi

ALL_OPTIONS+="=====  Todos los servicios  =====\n"
ALL_OPTIONS+="$all_services"

# Menú principal CON búsqueda
SERVICE_CHOICE=$(echo -e "$ALL_OPTIONS" | rofi -dmenu \
    -p "🔍  Buscar servicio" \
    -mesg "✅ Activo   ⛔ Inactivo   💀 Error   ⚪ Desconocido" \
    -theme "$ROFI_THEME")

[ -z "$SERVICE_CHOICE" ] && exit 0

if [ "$SERVICE_CHOICE" = "$RETURN_OPTION" ]; then
    exec "$MASTER_SCRIPT"
    exit 0
fi

# Ignorar separadores 
if [[ "$SERVICE_CHOICE" == "=====" ]] || \
   [[ "$SERVICE_CHOICE" == "Servicios" ]] || \
   ! [[ "$SERVICE_CHOICE" == ".service" ]]; then
    exec "$0"
fi

# Extraer nombre limpio usando | como separador
if [[ "$SERVICE_CHOICE" == "|" ]]; then
    # Viene de destacados: "✅ | ssh.service"
    SERVICE_NAME=$(echo "$SERVICE_CHOICE" | cut -d'|' -f2 | xargs)
else
    # Viene de lista completa: "ssh.service"
    SERVICE_NAME=$(echo "$SERVICE_CHOICE" | xargs)
fi

# Validar que es un servicio real
if [ -z "$SERVICE_NAME" ] || \
   ! echo "$ALL_UNIT_FILES" | awk '{print $1}' | grep -q "^${SERVICE_NAME}$"; then
    exec "$0"
fi

# Estado desde caché 
STATUS=$(get_status "$SERVICE_NAME")
ENABLED=$(echo "$ALL_UNIT_FILES" | grep "^${SERVICE_NAME}" | awk '{print $2}')
MESG="Estado: $STATUS  |  Arranque: $ENABLED"

# Menú de acciones SIN búsqueda 
ACTION=$(echo -e "▶  Iniciar\n⏹  Detener\n✅  Habilitar en arranque\n🚫  Deshabilitar en arranque\nℹ  Ver estado" | \
    rofi -dmenu \
    -p "$SERVICE_NAME" \
    -mesg "$MESG" \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom)

[ -z "$ACTION" ] && exec "$0"

# Ejecutar en terminal y esperar antes de volver
run_as_root() {
    local action="$1"
    local service="$2"
    x-terminal-emulator -e bash -c \
        "sudo systemctl $action $service \
        && echo '✅ $action en $service completado' \
        || echo '❌ Error al ejecutar $action en $service'; \
        echo ''; \
        read -p 'Presiona Enter para volver...'"
}

case "$ACTION" in
    Iniciar)
        run_as_root "start" "$SERVICE_NAME" ;;
    Detener)
        run_as_root "stop" "$SERVICE_NAME" ;;
    Habilitar)
        run_as_root "enable" "$SERVICE_NAME" ;;
    Deshabilitar)
        run_as_root "disable" "$SERVICE_NAME" ;;
    estado)
        FULL_STATUS=$(systemctl status "$SERVICE_NAME" --no-pager 2>/dev/null | head -15)
        echo "" | rofi -dmenu \
            -p "ℹ  $SERVICE_NAME" \
            -mesg "$FULL_STATUS" \
            -theme "$ROFI_THEME" \
            -theme-str 'inputbar { enabled: false; }' \
            -filter "" -no-custom \
            -l 0
        ;;
esac

exec "$0"
