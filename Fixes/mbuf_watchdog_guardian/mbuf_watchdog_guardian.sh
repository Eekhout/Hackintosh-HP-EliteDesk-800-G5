#!/bin/bash
# ==============================================================================
# mbuf_watchdog_guardian.sh  —  Daemon de Protección contra Kernel Panic
# HP EliteDesk 800 G5 Mini — macOS Sequoia 15.7.5 — itlwm (Intel 9560)
#
# Este daemon monitoriza activamente el consumo de mbufs de red del kernel.
# Cuando detecta que el uso de clusters de 4KB supera un umbral crítico
# (señal de la fuga de memoria del driver itlwm), recicla automáticamente
# la interfaz Wi-Fi para liberar los buffers ANTES de que el kernel entre
# en pánico con mbuf_watchdog.
#
# Lógica:
#   1. Cada 30 segundos lee netstat -m
#   2. Calcula el porcentaje de uso de clusters 4KB
#   3. Si supera el 80% → registra advertencia
#   4. Si supera el 85% → recicla la interfaz Wi-Fi (ifconfig down/up)
#   5. Si supera el 92% → fuerza un drain de mbufs via sysctl
# ==============================================================================

LOG_FILE="/var/log/mbuf_guardian.log"
WIFI_IFACE="en1"
CHECK_INTERVAL=30
WARN_THRESHOLD=80
RECYCLE_THRESHOLD=85
EMERGENCY_THRESHOLD=92

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [mbuf_guardian] $1" >> "$LOG_FILE"
}

get_4k_cluster_usage() {
    # Parse "XXXX/YYYY mbuf 4KB clusters in use"
    local stats
    stats=$(netstat -m 2>/dev/null | grep "4KB clusters")
    if [ -z "$stats" ]; then
        echo "0"
        return
    fi
    local in_use total
    in_use=$(echo "$stats" | awk -F'/' '{print $1}' | tr -d ' ')
    total=$(echo "$stats" | awk -F'/' '{print $2}' | awk '{print $1}')
    if [ "$total" -lt 2048 ] 2>/dev/null; then
        # Pool dinámico aún pequeño recién arrancado el sistema; no es saturación real
        echo "0"
        return
    fi
    echo $(( (in_use * 100) / total ))
}

get_4k_cluster_raw() {
    netstat -m 2>/dev/null | grep "4KB clusters" | head -1
}

get_total_net_pct() {
    netstat -m 2>/dev/null | grep "allocated to network" | grep -oE '[0-9]+\.[0-9]+%' | tr -d '%'
}

recycle_wifi() {
    log_msg "ACCIÓN: Reciclando interfaz $WIFI_IFACE (ifconfig down/up)..."
    ifconfig "$WIFI_IFACE" down 2>/dev/null
    sleep 2
    ifconfig "$WIFI_IFACE" up 2>/dev/null
    sleep 3
    log_msg "Interfaz $WIFI_IFACE reciclada. Nuevo estado de clusters: $(get_4k_cluster_raw)"
}

emergency_drain() {
    log_msg "¡¡EMERGENCIA!! Forzando drain de mbufs..."
    sysctl -w kern.ipc.mb_drain_force=1 2>/dev/null
    sleep 1
    sysctl -w kern.ipc.mb_drain_force=0 2>/dev/null
    recycle_wifi
    log_msg "Drain de emergencia completado. Nuevo estado: $(get_4k_cluster_raw)"
}

# ===== MAIN LOOP =====
log_msg "=========================================="
log_msg "mbuf_watchdog_guardian INICIADO"
log_msg "Interfaz vigilada: $WIFI_IFACE"
log_msg "Intervalo de chequeo: ${CHECK_INTERVAL}s"
log_msg "Umbrales: WARN=${WARN_THRESHOLD}% RECYCLE=${RECYCLE_THRESHOLD}% EMERGENCY=${EMERGENCY_THRESHOLD}%"
log_msg "=========================================="

RECYCLE_COUNT=0
LAST_RECYCLE_TIME=0

while true; do
    usage_pct=$(get_4k_cluster_usage)
    net_pct=$(get_total_net_pct)
    
    current_time=$(date +%s)
    
    if [ "$usage_pct" -ge "$EMERGENCY_THRESHOLD" ] 2>/dev/null; then
        log_msg "🔴 CRÍTICO: Uso de clusters 4KB al ${usage_pct}% (red total: ${net_pct}%)"
        log_msg "Detalle: $(get_4k_cluster_raw)"
        emergency_drain
        RECYCLE_COUNT=$((RECYCLE_COUNT + 1))
        LAST_RECYCLE_TIME=$current_time
        
    elif [ "$usage_pct" -ge "$RECYCLE_THRESHOLD" ] 2>/dev/null; then
        # Prevent recycling more than once every 60 seconds
        elapsed=$((current_time - LAST_RECYCLE_TIME))
        if [ "$elapsed" -ge 60 ]; then
            log_msg "🟠 ALTO: Uso de clusters 4KB al ${usage_pct}% (red total: ${net_pct}%)"
            log_msg "Detalle: $(get_4k_cluster_raw)"
            recycle_wifi
            RECYCLE_COUNT=$((RECYCLE_COUNT + 1))
            LAST_RECYCLE_TIME=$current_time
        fi
        
    elif [ "$usage_pct" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
        log_msg "🟡 ADVERTENCIA: Uso de clusters 4KB al ${usage_pct}% (red total: ${net_pct}%)"
    fi
    
    # Every 10 minutes, log a status line regardless
    if [ $((current_time % 600)) -lt "$CHECK_INTERVAL" ]; then
        log_msg "📊 Estado: clusters 4KB al ${usage_pct}% | red total: ${net_pct}% | reciclajes: ${RECYCLE_COUNT}"
    fi
    
    sleep "$CHECK_INTERVAL"
done
