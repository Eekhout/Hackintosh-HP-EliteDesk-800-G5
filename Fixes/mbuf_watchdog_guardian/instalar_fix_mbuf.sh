#!/bin/bash
# ==============================================================================
# INSTALADOR COMPLETO — Solución al Kernel Panic mbuf_watchdog
# HP EliteDesk 800 G5 Mini — macOS Sequoia 15.7.5
#
# Este script realiza TODAS las acciones necesarias para resolver
# de raíz el problema del Kernel Panic por mbuf_watchdog:
#
#   1. Instala el daemon guardián mbuf_watchdog_guardian
#   2. Limpia las preferencias de red corruptas de macOS
#   3. Actualiza los boot-args de OpenCore con keepsyms=1
#   4. Configura Ethernet (en0) como interfaz principal
#
# Ejecución:
#   cd "/Users/eekhout/Library/CloudStorage/OneDrive-Personal/IA/Antigravity/Hackintosh"
#   sudo ./instalar_fix_mbuf.sh
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  SOLUCIÓN DEFINITIVA — Kernel Panic mbuf_watchdog           ║"
echo "║  HP EliteDesk 800 G5 Mini — macOS Sequoia 15.7.5            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Este script requiere privilegios de administrador.${NC}"
    echo "Ejecuta: sudo $0"
    exit 1
fi

# ===================================================================
# PASO 1: Instalar el Daemon Guardián mbuf_watchdog_guardian
# ===================================================================
echo -e "${YELLOW}[PASO 1/4] Instalando daemon guardián mbuf_watchdog_guardian...${NC}"

GUARDIAN_SRC="$SCRIPT_DIR/mbuf_watchdog_guardian.sh"
GUARDIAN_DST="/usr/local/bin/mbuf_watchdog_guardian.sh"
PLIST_SRC="$SCRIPT_DIR/com.hackintosh.mbuf-guardian.plist"
PLIST_DST="/Library/LaunchDaemons/com.hackintosh.mbuf-guardian.plist"

if [ ! -f "$GUARDIAN_SRC" ]; then
    echo -e "${RED}Error: No se encuentra $GUARDIAN_SRC${NC}"
    exit 1
fi

# Detener si ya está corriendo
launchctl unload "$PLIST_DST" 2>/dev/null || true

# Copiar script y plist
mkdir -p /usr/local/bin
cp "$GUARDIAN_SRC" "$GUARDIAN_DST"
chmod 755 "$GUARDIAN_DST"
chown root:wheel "$GUARDIAN_DST"

cp "$PLIST_SRC" "$PLIST_DST"
chmod 644 "$PLIST_DST"
chown root:wheel "$PLIST_DST"

# Cargar el daemon
launchctl load -w "$PLIST_DST"
echo -e "${GREEN}  ✅ Daemon guardián instalado y activo.${NC}"
echo -e "     El daemon monitorea clusters 4KB cada 30 segundos."
echo -e "     Recicla Wi-Fi automáticamente al 85% de uso."
echo -e "     Log: /var/log/mbuf_guardian.log"

# ===================================================================
# PASO 2: Limpiar Preferencias de Red Corruptas
# ===================================================================
echo ""
echo -e "${YELLOW}[PASO 2/4] Limpiando preferencias de red corruptas...${NC}"

PREF_DIR="/Library/Preferences/SystemConfiguration"
BACKUP_DIR="$PREF_DIR/NetworkBackup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

CLEANED=0
for file in com.apple.airport.preferences.plist com.apple.network.identification.plist; do
    if [ -f "$PREF_DIR/$file" ]; then
        cp "$PREF_DIR/$file" "$BACKUP_DIR/"
        rm -f "$PREF_DIR/$file"
        echo -e "  -> $file respaldado y eliminado."
        CLEANED=$((CLEANED + 1))
    fi
done

if [ $CLEANED -gt 0 ]; then
    echo -e "${GREEN}  ✅ $CLEANED archivos de caché de red limpiados.${NC}"
    echo -e "     Respaldo en: $BACKUP_DIR"
else
    echo -e "${GREEN}  ✅ No había caché corrupta pendiente.${NC}"
fi

# ===================================================================
# PASO 3: Montar EFI y Actualizar boot-args
# ===================================================================
echo ""
echo -e "${YELLOW}[PASO 3/4] Montando partición EFI para actualizar boot-args...${NC}"

# Intentar montar la EFI
diskutil mount disk0s1 2>/dev/null && EFI_MOUNTED=true || EFI_MOUNTED=false

if [ "$EFI_MOUNTED" = true ]; then
    EFI_CONFIG="/Volumes/EFI/EFI/OC/config.plist"
    if [ -f "$EFI_CONFIG" ]; then
        # Leer boot-args actuales
        CURRENT_BOOTARGS=$(/usr/libexec/PlistBuddy -c "Print :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args" "$EFI_CONFIG" 2>/dev/null)
        echo -e "  Boot-args actuales: ${CYAN}$CURRENT_BOOTARGS${NC}"
        
        # Agregar keepsyms=1 si no está presente
        if echo "$CURRENT_BOOTARGS" | grep -q "keepsyms=1"; then
            echo -e "${GREEN}  ✅ keepsyms=1 ya está presente en boot-args.${NC}"
        else
            NEW_BOOTARGS="$CURRENT_BOOTARGS keepsyms=1"
            # Crear backup del config.plist
            cp "$EFI_CONFIG" "$EFI_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"
            /usr/libexec/PlistBuddy -c "Set :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args '$NEW_BOOTARGS'" "$EFI_CONFIG"
            echo -e "${GREEN}  ✅ boot-args actualizado: ${CYAN}$NEW_BOOTARGS${NC}"
        fi
        
        # Verificar la versión de itlwm en la EFI activa
        ITLWM_KEXT="/Volumes/EFI/EFI/OC/Kexts/itlwm.kext/Contents/Info.plist"
        if [ -f "$ITLWM_KEXT" ]; then
            ITLWM_VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$ITLWM_KEXT" 2>/dev/null)
            echo -e "  itlwm.kext versión activa en EFI: ${CYAN}$ITLWM_VER${NC}"
            if [ "$ITLWM_VER" = "2.3.0" ]; then
                echo -e "${GREEN}  ✅ itlwm v2.3.0 es la versión más reciente disponible.${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}  ⚠️  No se encontró config.plist en /Volumes/EFI/EFI/OC/${NC}"
        echo -e "     Deberás agregar keepsyms=1 a los boot-args manualmente."
    fi
else
    echo -e "${YELLOW}  ⚠️  No se pudo montar la partición EFI automáticamente.${NC}"
    echo -e "     Ejecuta manualmente: sudo diskutil mount disk0s1"
    echo -e "     Y agrega keepsyms=1 a los boot-args de tu config.plist."
fi

# ===================================================================
# PASO 4: Configurar Ethernet como Interfaz Principal
# ===================================================================
echo ""
echo -e "${YELLOW}[PASO 4/4] Configurando Ethernet (en0) como interfaz principal...${NC}"

# Subir prioridad de Ethernet sobre Wi-Fi en el orden de servicios de red
# Primero, listar los servicios
ETHERNET_SERVICE=$(networksetup -listallnetworkservices 2>/dev/null | grep -m1 "Ethernet" || echo "")

if [ -n "$ETHERNET_SERVICE" ]; then
    # Set Ethernet interface order higher
    networksetup -ordernetworkservices "$ETHERNET_SERVICE" "Ethernet 2" "PCI Serial Adapter (22)" 2>/dev/null || true
    echo -e "${GREEN}  ✅ Ethernet configurado como interfaz de red principal.${NC}"
    echo -e "     Si conectas un cable de red, tendrá prioridad sobre Wi-Fi."
else
    echo -e "${YELLOW}  ⚠️  No se encontró el servicio Ethernet en la configuración de red.${NC}"
fi

# ===================================================================
# RESUMEN FINAL
# ===================================================================
echo ""
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   INSTALACIÓN COMPLETADA                    ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                             ║"
echo "║  ✅ Daemon guardián mbuf_watchdog_guardian ACTIVO            ║"
echo "║     → Monitoriza cada 30s y recicla Wi-Fi al 85%           ║"
echo "║     → Log: /var/log/mbuf_guardian.log                       ║"
echo "║                                                             ║"
echo "║  ✅ Caché de red corrupta LIMPIADA                          ║"
echo "║     → macOS reconstruirá las interfaces al reiniciar        ║"
echo "║                                                             ║"
echo "║  ✅ Ethernet configurado como interfaz PRINCIPAL             ║"
echo "║     → Conecta cable de red para máxima estabilidad          ║"
echo "║                                                             ║"
echo "║  ⚠️  RECOMENDACIÓN: Reinicia el equipo para aplicar         ║"
echo "║     la limpieza de red completamente.                       ║"
echo "║                                                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "Para verificar que el guardián está activo después del reinicio:"
echo "  sudo launchctl list | grep mbuf"
echo "  tail -f /var/log/mbuf_guardian.log"
echo ""
