# Ubuntu Touch for Xiaomi Pad 5 (nabu)

[Ubuntu Touch](https://ubuntu-touch.io) 24.04 (Halium 13) for the **Xiaomi Pad 5** (`nabu`, Snapdragon 860, Adreno 640).

> **Experimental.** It is the author's daily tablet and a full installation has been tested on real
> hardware, but cameras and some other parts do not work yet. Install it only if you can put a tablet
> back to stock with fastboot.
>
> This project was created by its author in cooperation with an AI assistant.

**[⬇ Download the latest release](https://github.com/Giovix64/ubuntu-touch-xiaomi-nabu/releases)** ·
[Installation guide (EN)](release/GUIDE.txt) · [Guida (IT)](release/GUIDA.txt) ·
[Kernel source](https://github.com/Giovix64/linux-android-xiaomi-nabu/tree/halium-13.0)

## Features

| | Status |
|---|---|
| Lomiri desktop with GPU acceleration | ✅ |
| Touchscreen, auto-rotation | ✅ |
| On-screen keyboard (keyboard-cover sensor fixed) | ✅ |
| Wi-Fi | ✅ |
| Speakers | ✅ |
| Battery, charging | ✅ |
| **Xiaomi Pen 2** — pressure, palm rejection, stroke prediction | ✅ |
| Pen magnetic charging with battery notifications | ✅ |
| Waydroid (Android apps, GPU accelerated) | ✅ |
| OpenStore + core apps preinstalled | ✅ |
| Snaps, with GPU for snaps that support `hybris-2404` | ✅ |
| Cameras, flashlight | ❌ |
| Bluetooth, suspend/battery life, microphone, keyboard-cover keys, 120 Hz | not tested |

Known issues are listed in the [guide](release/GUIDE.txt#L57).

## Install

Requirements: **unlocked bootloader** and a **stock** HyperOS or MIUI 13/14
(tested base: HyperOS OS1.0.6.0.TKXEUXM). **Installing erases all data on the tablet.**

1. Download `ubuntu-touch-nabu-<version>-installer.zip` from the
   [releases](https://github.com/Giovix64/ubuntu-touch-xiaomi-nabu/releases) and unpack it.
2. Tablet off → hold **Volume Down + Power** until the FASTBOOT screen → connect the USB cable.
3. Run **one** installer:

   | | |
   |---|---|
   | 🌐 **Any computer, easiest** | open `installer.html` in **Chrome** or **Edge** |
   | 🌐 Not sure about your current ROM | open `installer-any-rom.html` (explains every starting point) |
   | 🪟 Windows | double-click `install-windows.bat` |
   | 🍎 macOS | right-click `install-macos.command` → Open |
   | 🐧 Linux | `./install-linux.sh` |

Everything is included (the ArrowOS 13.1 `vendor`/`odm`/`vbmeta` images too); the scripts download
Google's `fastboot` if it is missing. The installers check the device model, the unlock state and every
file checksum, and **never lock the bootloader**. The first start takes 1–2 minutes.

There is also a complete **recovery zip** for TWRP / OrangeFox, which keeps your Ubuntu Touch data and
works as an updater. Details: [GUIDE.txt](release/GUIDE.txt).

## How it works

- **Kernel**: Droidian nabu kernel 4.14 (ArrowOS 13.1 base) plus a few patches needed by the Ubuntu 24.04
  userspace on 4.14 — binder with AppArmor, `waitid(P_PIDFD)`, `clone(CLONE_PIDFD)` — the keyboard-cover
  hall sensor polarity, and squashfs for snaps.
- **Android side**: HyperOS `system`, ArrowOS 13.1 `vendor`/`odm`; the VNDK v30 runtime the vendor needs
  is bundled in the Ubuntu Touch image.
- **Pen**: Mir 1.8 ignores tablet-tool events, so `nabu-pen-bridge` turns the pen into a touch device
  with pressure, and adds palm rejection and stroke prediction (`/etc/nabu-pen.conf`).

## Repository layout

| Path | Content |
|---|---|
| `deviceinfo` | build configuration for [halium-generic-adaptation-build-tools](https://gitlab.com/ubports/porting/community-ports/halium-generic-adaptation-build-tools) |
| `overlay/` | files that **replace** existing ones (Halium overlay store) |
| `rootfs-overlay/` | **new** files added to the image: services for pen, Wi-Fi, VNDK, userdata growth |
| `tools/` | build helpers (`finalize-rootfs.sh`, `sparse_chunks.py`, `payload_extract.py`, …) |
| `release/` | installers, recovery zip, guides and `make-release.sh` |

## Build

```
./build.sh -b workdir                                   # kernel, boot images, device tarball
./build/prepare-fake-ota.sh out/device_nabu.tar.xz ota
tools/fetch-clicks.py                                   # preinstalled OpenStore apps
sudo ./build/system-image-from-ota.sh ota/ubuntu_command images
sudo NABU_PROFILE=public tools/finalize-rootfs.sh images/rootfs.img
release/make-release.sh                                 # installers and zips in release/dist/
```

The VNDK v30 APEX (`rootfs-overlay/usr/share/nabu/com.android.vndk.v30.apex`) and the ArrowOS vendor
images are not stored in git: extract them from the HyperOS fastboot ROM and the ArrowOS 13.1 zip
(see `release/make-release.sh`).

## Credits

UBports and the Ubuntu Touch community, Halium, Droidian, the nabu kernel by MarshJiang, ArrowOS,
the linux-on-nabu community, and everyone who documented this tablet.
