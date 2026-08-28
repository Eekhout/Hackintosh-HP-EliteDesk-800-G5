# Resumen de Estado - HP EliteDesk 800 G5 Mini (OpenCore)

## 📌 Estado General del Sistema: 100% Estable y Funcional

### 1. Arranque y Almacenamiento
* **Boot:** NVMe interno independiente (SequoiaSSD).
* **OpenCore:** 1.0.x con OpenCanopy (interfaz gráfica activa).
* **SMBIOS:** `Macmini8,1` con números de serie únicos inyectados.

### 2. Aceleración Gráfica y Pantalla
* **iGPU:** Intel UHD Graphics 630 (Device ID: `0x3E92`, Platform ID: `AACSPg==`).
* **VRAM:** 1536 MB asignados dinámicamente.
* **Soporte Metal:** Metal 3 activo (QE/CI al 100%).
* **Pantalla:** 1080p FHD @ **165.00 Hz** con **30-Bit Color** (ARGB2101010) vía DisplayPort.
* **Estabilidad del Framebuffer:** Resuelto el Kernel Panic de `IOAcceleratorFamily2` (`element modified after free`) mediante:
  * BIOS DVMT Pre-Allocated configurado en **128 MB**.
  * Inyección de parches de memoria en `PciRoot(0x0)/Pci(0x2,0x0)`:
    * `framebuffer-stolenmem`: `AAAwAQ==` (19 MB)
    * `framebuffer-fbmem`: `AACQAA==` (9 MB)

### 3. Puertos USB y Conectividad
* **Controlador Host:** Intel Cannon Lake PCH USB 3.1 (`AppleIntelCNLUSBXHCI`, PCI ID: `0xa36d`).
* **Bluetooth Host Controller:** Intel 9560 integrado, asignado correctamente como `Built-In: Yes` en `HS07` (sin riesgo de fallo en reposo/sleep).
* **Periféricos USB:**
  * Raton Gaming Razer Basilisk X HyperSpeed (`0x14400000`) - Operativo.
  * Receptor Unifying/USB Logitech (`0x14300000`) - Operativo.
* **Red / Wi-Fi:** Intel Wireless-AC 9560 funcional vía `itlwm.kext` v2.3.0 + HeliPort.
* **Ethernet:** Intel I219-LM funcional vía `IntelMausiEthernet.kext` v3.0.3.
* **Audio:** Conexant CX20632 & altavoz interno funcional vía `AppleALC.kext` (layout-id: 20).

### 4. Protección contra Kernel Panic mbuf_watchdog (28/08/2026)
* **Problema:** Kernel Panic por agotamiento de clusters 4KB (mbuf leak en itlwm.kext bajo estrés).
* **Solución Implementada:**
  * Daemon guardián `mbuf_watchdog_guardian.sh` instalado como LaunchDaemon (`com.hackintosh.mbuf-guardian`).
  * Monitoriza uso de clusters cada 30s y recicla Wi-Fi automáticamente al 85% de saturación.
  * `boot-args` actualizados a: `igfxonln=1 keepsyms=1`.
  * Ethernet (en0) configurado como interfaz principal para cargas pesadas.
  * Log de monitorización: `/var/log/mbuf_guardian.log`.
* **Instalador:** `instalar_fix_mbuf.sh` (ejecutar con `sudo` para desplegar todo).

### 5. Repositorio GitHub
* **URL:** `https://github.com/Eekhout/Hackintosh-HP-EliteDesk-800-G5.git`
* **Estado:** Sincronizado con la rama `main` (incluye EFI y documentación de 165Hz/30-bit).
