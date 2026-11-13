# [WIP] Ubuntu Touch 24.04 for Xiaomi Pad 5 (nabu)

Hi everyone!

I'm working on a Halium 13 port of Ubuntu Touch 24.04-2.x for the **Xiaomi Pad 5 (nabu, Snapdragon 860)**.
It is already my daily tablet, so I'd like to share it and get feedback.

**Base:** Droidian nabu kernel 4.14 (ArrowOS 13.1 based) + a few patches, HyperOS OS1.0.6.0 (EEA) system
partitions, ArrowOS 13.1 vendor/odm.

## Working
- Lomiri with GPU acceleration (Adreno 640), touch, auto-rotation
- On-screen keyboard (fixed the keyboard-cover hall sensor polarity in the DT, it reported a hardware keyboard)
- Wi-Fi, battery/charging
- **Xiaomi Pen 2**: writing with pressure, palm rejection, stroke prediction, magnetic charging with battery notifications
- Waydroid, OpenStore and core apps preinstalled

## Not tested yet
Audio, Bluetooth, suspend/battery life, cameras, keyboard cover keys, 120 Hz.

## Kernel patches needed for 24.04 userspace on 4.14 (maybe useful for other 4.14 ports)
- binder: don't fail transactions when the LSM can't provide a secctx (AppArmor returns -EOPNOTSUPP;
  every servicemanager transaction failed, so the composer never started)
- backport `waitid(P_PIDFD)` (GLib/lightdm thought the session had died)
- `clone(CLONE_PIDFD)`: drop the early "reserved == 0" check on `parent_tidptr` (Qt's forkfd passes -1;
  QProcess failures ended up killing the whole user session)

## Pen on Mir 1.8
Mir 1.8 ignores libinput tablet-tool events, so the pen is bridged to a virtual single-touch device
(with pressure) by a small stdlib-only Python service; it also does palm rejection and stroke prediction.
The NVT touch driver keeps the pen disabled until userspace enables it (Xiaomi framework ioctl), and the
boot-time firmware reload resets it — details in the repo.

## Install
fastboot installer script (checks device/unlock state, never locks) and a TWRP/OrangeFox zip for updates.
Download: https://github.com/Giovix64/ubuntu-touch-xiaomi-nabu/releases

## Source
Kernel: https://github.com/Giovix64/linux-android-xiaomi-nabu (branch halium-13.0) — device repo: https://github.com/Giovix64/ubuntu-touch-xiaomi-nabu

Feedback and testers welcome!
