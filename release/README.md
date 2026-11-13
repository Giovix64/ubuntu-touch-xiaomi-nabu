# Ubuntu Touch for Xiaomi Pad 5 (nabu)

Community port of [Ubuntu Touch](https://ubuntu-touch.io) 24.04 (Halium 13) to the Xiaomi Pad 5 (`nabu`, Snapdragon 860).

> A plain-text guide with features, bugs and installation steps is in `GUIDE.txt` (Italian: `GUIDA.txt`).

> This port was created by its author in cooperation with an AI assistant.

> **Status: early / experimental.** It boots to a fully usable Lomiri session and is used daily by its
> author, but several parts of the hardware are not tested yet. Install it only if you can reflash
> your tablet from fastboot.

## What works

| Area | Status | Notes |
|---|---|---|
| Boot, Lomiri, GPU (Adreno 640) | ✅ | hardware accelerated UI and native apps |
| Touchscreen, auto-rotation | ✅ | |
| On-screen keyboard | ✅ | keyboard-cover hall sensor fixed in the device tree (tablet mode detection) |
| Wi-Fi | ✅ | |
| Audio (speakers) | ✅ | |
| Battery level, charging | ✅ | |
| **Xiaomi Pen 2** | ✅ | writing with pressure, palm rejection, low-latency stroke prediction (`/etc/nabu-pen.conf`) |
| Pen magnetic charging | ✅ | with attach/detach/battery notifications |
| Waydroid (Android apps) | ✅ | GPU accelerated |
| OpenStore + core apps | ✅ | preinstalled on first boot |
| Snaps (incl. GPU via `hybris-2404`) | ✅ | squashfs enabled; device-access snaps need `--devmode` (see GUIDE.txt) |
| AppArmor app confinement | ✅ | profiles enforced (`apparmor.service` reports a failure, harmless) |

## Not working

Cameras, flashlight/torch.

## Not tested yet

Bluetooth (toggle present), suspend/deep sleep and battery life, microphone, keyboard-cover keys,
120 Hz, video hardware decoding, sensors other than the accelerometer.

## Known issues

- Desktop (X11) apps — Libertine, snaps — are rendered without GPU and, in landscape, do not receive touch
  on the right part of the screen (the X screen follows the portrait panel).
- Waydroid: launching an Android app from the app drawer may not bring the Waydroid window to the
  front if it is already open in the background. Open "Waydroid" first.
- Snaps that need device access (GPU, joystick) must be installed with `--devmode`: the 4.14 kernel lacks the
  BPF device-cgroup support used by snap confinement (Linux 4.15+).
- The system clock may be wrong until the first network connection.
- Phone, Messages and External Storage apps are hidden (no modem, no SD slot).

## Install

**Installing erases all data on the tablet.** Requirements: unlocked bootloader, and the tablet on a
**stock HyperOS or MIUI 13/14** (tested base: HyperOS `OS1.0.6.0.TKXEUXM`; the VNDK v30 runtime is bundled, so no
specific release is required — see `installer-any-rom.html` for every starting point). Nothing else to download: the ArrowOS 13.1
`vendor`/`odm`/`vbmeta` images are included.

1. Unpack `ubuntu-touch-nabu-<version>-installer.zip`.
2. Tablet off, hold **Volume Down + Power** until the FASTBOOT screen, connect USB.
3. Run one installer:
   - **Browser (easiest):** open `installer.html` in Chrome or Edge;
   - **Windows:** `install-windows.bat` — **macOS:** `install-macos.command` — **Linux:** `./install-linux.sh`.

A complete **TWRP/OrangeFox zip** (`…-recovery.zip`) is also provided; it keeps existing Ubuntu Touch data,
so it doubles as an updater. Details, Windows driver notes and troubleshooting: `GUIDE.txt`.

The installers check device, unlock state and file checksums, and never lock the bootloader.
The vendor images come from ArrowOS 13.1 and contain proprietary Xiaomi/Qualcomm files, redistributed
as custom ROMs do.

## First boot

The first boot takes about a minute (Mi logo, then the Ubuntu Touch welcome wizard).

## Going back to Android

Flash the HyperOS fastboot ROM with Xiaomi's `flash_all.sh` (not `flash_all_lock.sh`).

## Source code

- Kernel: Droidian nabu kernel (`MarshJiang/linux-android-xiaomi-nabu`, ArrowOS 13.1 base) plus the
  patches in `kernel-patches/` (Halium config, binder secctx with AppArmor, `waitid(P_PIDFD)` backport,
  `CLONE_PIDFD` fix, keyboard-cover hall polarity).
- Device adaptation, build scripts and this installer: *repository link to be added*.

## Credits

UBports and the Ubuntu Touch community, Halium, the Droidian nabu kernel by MarshJiang, ArrowOS,
the linux-on-nabu community, Mesa, and everyone who documented this tablet.
