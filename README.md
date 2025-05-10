![Screenshot from 2025-05-10 18-09-18](https://github.com/user-attachments/assets/815a731d-5891-4cbb-a056-ccac53c3d85b)
# AW1K-NIALWRT

**Source:** ImmortalWrt  
**Target OS:** Ubuntu 22.04 LTS or newer

## Overview

AW1K-NIALWRT is a beginner-friendly OpenWrt build script designed for quick deployment and daily use. It comes with a full set of pre-configured packages and system tweaks, making it ideal for users who want a plug-and-play solution without needing to configure everything from scratch.

## Features

- **Ready-to-use Preset**  
  Comes with essential packages and system configurations tailored for optimal performance and modem support.

- **Beginner Friendly**  
  Automates the entire build process — from dependencies to final firmware output.

- **Customizable via Menuconfig**  
  Offers flexibility to add, remove, or update packages and kernel versions via `make menuconfig`.

- **Automatic Logging**  
  - `build.log`: Full build output  
  - `error.log`: Captures errors during build process

## Preset Tweaks

- BBR congestion control
- ZRAM swap enabled
- CPU frequency scaling (all cores active)
- TTL 64 (for modem/router compatibility)
- Quectel-CM protocol support

## Preset Packages

- **System tools:** `htop`, traffic monitor, RAM releaser, terminal access  
- **Modem tools:** 3GInfo Lite, modem band selector, SMS tools  
- **Extras:** Argon theme, SFTP (OpenSSH) support

## Default WiFi Settings

- **SSID:** `AW1K` / `AW1K 5G`  
- **Password:** `nialwrt123`

## Requirements

- Ubuntu 22.04 LTS or newer
- Internet connection
- Adequate disk space and RAM
- Basic terminal usage knowledge

## Quick Installation

Open your terminal and run:

```bash
wget https://raw.githubusercontent.com/nialwrt/AW1K-NIALWRT/main/aw1k-nialwrt.sh && chmod +x aw1k-nialwrt.sh && ./aw1k-nialwrt.sh
