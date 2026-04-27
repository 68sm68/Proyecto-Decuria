#!/usr/bin/env bash

ROFI_THEME="$HOME/.config/rofi/systemctl_simple.rasi"
MASTER_SCRIPT="$HOME/.config/performance/performance_panel.sh"
SYSCTL_CONF="/etc/sysctl.conf"
RETURN_OPTION="⬅️  Volver al Menú Principal"

# Detectar configuración actual
CURRENT_TIMEOUT=$(cat /proc/sys/net/ipv4/tcp_fin_timeout 2>/dev/null || echo "?")
CURRENT_PORTS=$(cat /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null || echo "?")

if [ "$CURRENT_TIMEOUT" = "15" ]; then
    CURRENT_MODE="🟢  Baja Latencia activo"
else
    CURRENT_MODE="⚪  Por Defecto activo"
fi

# Menú SIN búsqueda
CHOICE=$(echo -e "$RETURN_OPTION\n🚀  Baja Latencia — Optimizado para escritorio\n🔄  Por Defecto — Valores del sistema" | \
    rofi -dmenu \
    -p "Latencia de Red" \
    -mesg "$CURRENT_MODE  |  tcp_fin_timeout: ${CURRENT_TIMEOUT}s  |  Puertos: $CURRENT_PORTS" \
    -theme "$ROFI_THEME" \
    -theme-str 'inputbar { enabled: false; }' \
    -filter "" -no-custom)

[ -z "$CHOICE" ] && exit 0

if [ "$CHOICE" = "$RETURN_OPTION" ]; then
    exec "$MASTER_SCRIPT"
    exit 0
fi

# Definir valores según elección
if [[ "$CHOICE" == "Baja Latencia" ]]; then
    TCP_FIN=15
    PORT_RANGE="1024 65535"
    LABEL="Baja Latencia"
    DESC="Conexiones TCP cierran más rápido, más puertos disponibles"
else
    TCP_FIN=60
    PORT_RANGE="32768 60999"
    LABEL="Por Defecto"
    DESC="Valores estándar del sistema"
fi

# Aplicar con terminal 
x-terminal-emulator -e bash -c "
    echo 'Aplicando configuración: $LABEL'
    echo '$DESC'
    echo ''

    # Aplicar en tiempo real
    echo $TCP_FIN | sudo tee /proc/sys/net/ipv4/tcp_fin_timeout > /dev/null
    echo '$PORT_RANGE' | sudo tee /proc/sys/net/ipv4/ip_local_port_range > /dev/null

    # Limpiar entradas anteriores del panel en sysctl.conf
    sudo sed -i '/^# --- Red Panel Rendimiento/d' $SYSCTL_CONF
    sudo sed -i '/^net.ipv4.tcp_fin_timeout=/d' $SYSCTL_CONF
    sudo sed -i '/^net.ipv4.ip_local_port_range=/d' $SYSCTL_CONF

    # Guardar nuevos valores
    echo '# --- Red Panel Rendimiento ---' | sudo tee -a $SYSCTL_CONF > /dev/null
    echo 'net.ipv4.tcp_fin_timeout=$TCP_FIN' | sudo tee -a $SYSCTL_CONF > /dev/null
    echo 'net.ipv4.ip_local_port_range=$PORT_RANGE' | sudo tee -a $SYSCTL_CONF > /dev/null

    # Recargar kernel
    sudo sysctl -p > /dev/null

    echo ''
    echo '✅ Configuración aplicada y guardada'
    echo ''
    echo '  tcp_fin_timeout    = $TCP_FIN'
    echo '  ip_local_port_range = $PORT_RANGE'
    echo ''
    read -p 'Presiona Enter para volver...'
"

# Volver al mismo menú mostrando nuevo estado
exec "$0"
