# 🍏 HP EliteDesk 800 G5 Mini - Eekhoutosh (OpenCore)

![macOS](https://img.shields.io/badge/macOS-Sonoma%20%7C%20Sequoia-black?style=for-the-badge&logo=apple)
![OpenCore](https://img.shields.io/badge/OpenCore-Bootloader-blue?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Perfect%20(Macmini8,1)-success?style=for-the-badge)

Welcome to the ultimate Hackintosh configuration for the **HP EliteDesk 800 G5 Mini**. This repository contains the documented journey and the necessary explanations to achieve a 100% functional macOS installation, bypassing the most common pitfalls associated with this specific hardware.

---

## 💻 Hardware Specifications

| Component | Specification |
| :--- | :--- |
| **Model** | HP EliteDesk 800 G5 Mini (35W) |
| **Processor** | Intel Core i5-9500T (Coffee Lake) |
| **Graphics** | Intel UHD Graphics 630 |
| **RAM** | DDR4 SODIMM 2666 MHz |
| **Audio** | Conexant CX20632 & Internal Speaker |
| **Ethernet** | Intel I219-LM Gigabit |
| **Wi-Fi/BT** | Intel Wireless-AC 9560 |
| **SMBIOS** | `Macmini8,1` |

---

## ✅ What's Working?
- [x] Full Graphics Acceleration (QE/CI) via DP/HDMI with support for High-Refresh Displays (up to 165Hz @ 30-Bit Color) + Apple GuC firmware enabled.
- [x] Audio (Internal Speaker & Audio Jacks) via `AppleALC` (layout-id: 20).
- [x] All USB Ports (USB 2.0 & USB 3.0 SuperSpeed mapped within the 15-port limit, `port-count` = 26).
- [x] Wi-Fi & Internet via `AirportItlwm.kext` (native macOS menu bar) / `itlwm.kext`.
- [x] **AirDrop & Bluetooth Continuity**: Full native discovery and file transfer via Intel Wireless-AC 9560 (CNVi) mapped to internal `HS14`.
- [x] Ethernet (IntelMausi Gigabit).
- [x] Sleep / Wake State.
- [x] OpenCanopy Graphical Boot Picker.
- [x] iServices (iMessage, FaceTime, iCloud).

---

## ⚙️ BIOS / UEFI Configuration (CRITICAL)

Before booting the EFI, it is strictly necessary to configure the BIOS properly. Graphics stability and kernel integrity depend directly on the video memory allocation:

* **Video Memory Size (DVMT Pre-Allocated):** Set to **64 MB** or **128 MB**. 
  * *64 MB:* Minimum recommended for standard 1080p/4K 60Hz displays.
  * *128 MB (Highly Recommended):* Ideal when using High-Refresh Rate monitors (144Hz / 165Hz) and 30-Bit / 10-bit color (ARGB2101010) or multi-monitor setups.
  *(Setting this to 32MB without stolen memory patches will cause `IOAcceleratorFamily2` Kernel Panics or boot loops).*
* **Secure Boot:** Disabled.
* **Sure Start:** Disabled.
* **Fast Boot:** Disabled.

---

## 🚀 Two-Phase Installation Strategy (CRITICAL)

To ensure a seamless transition to macOS Sequoia, this repository organizes the configuration into two critical stages. This separation is vital because Sequoia has increased sensitivity regarding USB port mapping and Framebuffer routing on HP hardware.

### 1. Pre-Installation Phase (Recovery Mode)
*Located in the `config pre instalacion` folder.*

*   **What's inside?**: A minimalist, "safe-mode" configuration specifically designed to allow the macOS installer to boot from the USB without interruptions.
*   **Why is it necessary?**: During the recovery environment load, macOS Sequoia is unforgiving with the USB port limit. If the system detects more than 15 ports (common on HP hardware without mapping), it will launch an immediate **Kernel Panic**. This version:
    *   Enforces a strict, basic mapping to prevent crashes.
    *   Ensures the video signal reaches the monitor during the installation process (avoiding the "Black Screen").
    *   Keeps diagnostic flags (verbose mode) active to monitor progress.

### 2. Post-Installation Phase (Optimization & Stability)
*Located in the `config post Instalacion` folder.*

*   **What's inside?**: The definitive performance engine. It includes surgical USB mapping via `USBPorts.kext`, full hardware acceleration (QE/CI) for the UHD 630, and system identity configuration.
*   **Why apply it?**: Once the system is installed on the internal drive, the goal is total hardware integration:
    *   **Full Acceleration**: Enables macOS to use the GPU's full power for fluid animations and video editing.
    *   **iServices**: This is where unique serial numbers (SMBIOS `Macmini8,1`) are injected to make iCloud, iMessage, and FaceTime work securely.
    *   **Apple Aesthetics**: Removes boot logs to show only the clean Apple logo and enables support for over-the-air (OTA) updates via `RestrictEvents`.

---

## 🛠️ The Configuration Journey: Challenges & Solutions

Building a working EFI for the EliteDesk G5 comes with particular challenges. Here is exactly what we modified under the hood and why:

### 1. The "Black Screen" UHD 630 Graphics Fix & `IOAcceleratorFamily2` Stability 🖥️
By default, macOS tries to route the video output blindly, resulting in a black screen when connected via the HP's rear DisplayPort or HDMI ports. Furthermore, driving modern high-refresh monitors (165Hz / 30-Bit Color) or display sleep transitions in macOS Sequoia can trigger memory use-after-free panics (`[kalloc.type.var3.768]: element modified after free` in `com.apple.iokit.IOAcceleratorFamily2`).
* **The Connector Fix:** We injected specific Framebuffer patches into `PciRoot(0x0)/Pci(0x2,0x0)` with `AAPL,ig-platform-id` = `AACSPg==` (`3E920000`) and explicitly mapped connectors (`con0`, `con1`, `con2`) with proper Bus IDs and Types.
* **The Memory Buffer Fix:** We added `framebuffer-stolenmem` (`AAAwAQ==` / 19MB) and `framebuffer-fbmem` (`AACQAA==` / 9MB) to define precise memory boundaries for the framebuffer. Combined with **64MB/128MB DVMT** in BIOS, this permanently resolves `IOAcceleratorFamily2` kernel panics and delivers flawless 165Hz @ 1080p 30-Bit Metal 3 acceleration.

### 2. Overcoming the USB 15-Port Limit 🔌
Initially, only USB 2.0 and the Type-C port were recognized. This happens because macOS reads the ports sequentially and hits the software limit of 15 ports before it can register the physically attached USB 3.0 ports.
* **The Fix:** We discarded generic mappers (`USBToolBox.kext` / `UTBMap.kext`) and deployed a custom, mathematically crafted `USBPorts.kext`. 
* This kext perfectly maps **7x HS (USB 2.0)** and **8x SS (USB 3.0)** ports, summing up exactly to the 15-port limit. This guarantees max transfer speeds across all physical chassis ports.

### 3. Native AirDrop & Intel CNVi Bluetooth Architecture (`HS14` + NVRAM) 📡
Achieving native AirDrop and continuous Bluetooth stability with the integrated **Intel Wireless-AC 9560 (CNVi)** was one of the most critical breakthroughs:
* **The Motherboard Port Mapping Reality:** On HP EliteDesk 800 G5 Mini boards with Intel Q370/Cannon Lake PCH (`0xa36d`), the internal CNVi M.2 Bluetooth bus is physically routed to port **`HS14`** (`port` = `<0e000000>`, `UsbConnector` = `255` Internal). Previous community guides erroneously assigned it to `HS07`, which left the Bluetooth controller disconnected at the USB level and caused `bluetoothd` to crash in a continuous loop (>100 crashes/day).
* **The 15-Port Limit & `port-count`:** In `UTBMap.kext`, the `port-count` property specifies the highest hexadecimal port index, **not** the quantity of ports. By defining exactly 15 active ports (7x HS + 8x SS) with `port-count` set to **`26`** (`<1a000000>` / `GgAAAA==`), macOS preserves all high-speed USB 3.0 ports (`SS01`-`SS10`) without truncating them.
* **NVRAM Synchronization for Sonoma/Sequoia:** `BlueToolFixup.kext` and macOS 14+ require explicit initial Bluetooth controller state declarations. Under `NVRAM -> Add -> 7C436110-AB2A-4BBB-A880-FE41995C9F82`, we declare:
  * `bluetoothExternalDongleFailed` = `<00>`
  * `bluetoothInternalControllerInfo` = `00000000 00000000 00000000 0000` (14 bytes of zeros)
* **The AirDrop Result:** Combined with `AirportItlwm.kext` (v2.3.0), the Bluetooth stack boots natively with firmware `v4352 c4352`, unlocking **two-way AirDrop file transfers** and Continuity directly from the native macOS sharing menu!

### 4. Apple GuC Graphics Scheduling (`igfxfw=2`) & `RCS Ring` Stability 🚀
Under macOS Sonoma and Sequoia, background Metal and video decoding workloads (such as `mediaanalysisd`) can trigger GPU timeouts (`RCS Ring Appears hung` / `.gpuRestart` logs) on Coffee Lake UHD 630.
* **The Fix:** We inject `igfxfw = <02000000>` under `PciRoot(0x0)/Pci(0x2,0x0)` and pass `igfxfw=2` in `boot-args`. This commands WhateverGreen to load Apple's official **Graphics Unit Control (GuC)** firmware, offloading scheduler tasks to the hardware and eliminating micro-stutters and GPU lockups.

### 5. Network Buffer Protection (`mbuf_watchdog_guardian`) 🛡️
Heavy wireless data traffic through `AirportItlwm` on modern macOS can occasionally cause network cluster buffer exhaustion (`mbuf_watchdog` kernel panics).
* **The Guard:** A lightweight daemon (`mbuf_watchdog_guardian.sh`) runs via LaunchDaemon (`com.hackintosh.mbuf-guardian.plist`), continuously monitoring 4KB cluster usage. It safely recycles the Wi-Fi interface if cluster usage approaches saturation, guaranteeing 24/7 uptime without kernel panics.

### 6. Wi-Fi Engine 🛜
Since the module is an Intel Wireless-AC 9560 (not natively supported by Apple), we deployed `itlwm.kext` in combination with the **HeliPort** app. This allows macOS to comfortably manage the wireless networks.

### 7. Aesthetics and "The Apple Feel" ✨
To make the machine feel like a real Mac rather than a hacking project:
* **Boot verbose removed:** Stripped `-v` from the `boot-args` to ensure a clean boot featuring only the Apple Logo and progress bar.
* **OpenCanopy Enabled:** Switched the `PickerMode` to `External` to display a beautiful graphical OS selector instead of the primitive text menu.
* **Clean Identity:** Set the SMBIOS up as `Macmini8,1` (as it is the closest architectural relative to the i5-9500T). Used `macserial` to generate unique board serials and UUIDs to ensure completely safe access to iCloud servers.

---

## 🚀 How to use this EFI

1. Download the contents of the `EFI` folder.
2. Mount your USB's or SSD's hidden EFI partition.
3. Replace the `EFI` folder entirely.
4. **IMPORTANT:** Open `config.plist` using *ProperTree* or *OCAuxiliaryTools*, and generate your own SMBIOS keys (`SystemSerialNumber`, `MLB`, `SystemUUID`) for `Macmini8,1` to avoid iMessage conflicts.
5. Reboot, clear NVRAM (if necessary), and enjoy.

---

## 🏆 Credits
* [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/) for the foundational knowledge.
* [Acidanthera](https://github.com/acidanthera) for OpenCore, Lilu, WhateverGreen, AppleALC, and their titanic contributions.
* [OpenIntelWireless](https://github.com/OpenIntelWireless) for the Intel Wi-Fi and Bluetooth drivers.
* EliteDesk G4/G5 Hackintosh communities and [de-luca](https://github.com/de-luca) for the USB internal mapping insights.

> **Disclaimer:** This project is provided for educational purposes. I am not responsible for any damage caused to your equipment. Please make sure to understand the OpenCore architecture before flashing custom bootloaders.
