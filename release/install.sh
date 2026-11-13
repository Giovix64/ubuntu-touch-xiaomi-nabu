#!/usr/bin/env bash
# =============================================================================
#  Ubuntu Touch for Xiaomi Pad 5 (nabu) — installer for Linux and macOS
#
#  Just run it:            ./install.sh
#  Options:
#    --reinstall    the tablet already runs this port: skip the hardware drivers
#                   (vendor/odm), erase the data and reinstall the system
#    --boot-only    update only boot/vendor_boot/dtbo (keeps all your data)
#    --dry-run      show what would be done, write nothing
#    --yes          do not ask for confirmation
#
#  Everything needed is in this folder. If "fastboot" is not installed, the
#  official Android platform-tools are downloaded from Google automatically.
#  This script NEVER locks the bootloader.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="$HERE/images"
MODE="full"; DRY=0; YES=0; VENDOR=1

if [ -t 1 ]; then B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else B=""; R=""; G=""; Y=""; C=""; N=""; fi
STEP=0; STEPS=7
step()  { STEP=$((STEP + 1)); echo; echo "${B}${C}[$STEP/$STEPS]${N} ${B}$*${N}"; }
info()  { echo "      $*"; }
ok()    { echo "      ${G}✔${N} $*"; }
warn()  { echo "      ${Y}!${N} $*"; }
die()   { echo; echo "  ${R}${B}✘ $*${N}"; echo; exit 1; }
run()   { if [ "$DRY" = 1 ]; then echo "      ${Y}+${N} fastboot ${*:2}"; else "$@"; fi; }
fb()    { run "$FASTBOOT" "$@"; }
getvar() { "$FASTBOOT" getvar "$1" 2>&1 | awk -v k="$1:" '$1 == k { print $2; exit }'; }
confirm() {
    [ "$YES" = 1 ] && return 0
    read -r -p "      Type ${B}YES${N} to continue: " a
    [ "$a" = "YES" ] || die "Cancelled. Nothing was changed."
}
flash_all() {   # flash_all <partition> <file prefix>: flashes prefix.NN.img in order
    local part="$1" n=0 total f
    total=$(ls "$IMG/$2".[0-9][0-9].img 2>/dev/null | wc -l | tr -d ' ')
    [ "$total" -gt 0 ] || die "Missing files: images/$2.NN.img"
    for f in "$IMG/$2".[0-9][0-9].img; do
        n=$((n + 1)); info "$part: part $n of $total"
        if [ "$DRY" = 1 ]; then fb flash "$part" "$f"
        else "$FASTBOOT" flash "$part" "$f" >"$HERE/.fastboot.log" 2>&1 || { cat "$HERE/.fastboot.log"; die "Flashing $part failed."; }; fi
    done
}
wait_mode() {   # wait_mode yes|no : wait for fastbootd (yes) or the bootloader (no)
    [ "$DRY" = 1 ] && return 0
    local i u
    for i in $(seq 90); do
        if "$FASTBOOT" devices 2>/dev/null | grep -q fastboot; then
            u="$(getvar is-userspace)"
            [ "$1" = yes ] && [ "$u" = yes ] && return 0
            [ "$1" = no ] && [ "$u" != yes ] && return 0
        fi
        sleep 2
    done
    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --boot-only) MODE="boot-only"; STEPS=4; shift;;
        --reinstall|--skip-vendor) VENDOR=0; STEPS=6; shift;;
        --dry-run)   DRY=1; shift;;
        --yes|-y)    YES=1; shift;;
        -h|--help)   sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
        *) die "Unknown option: $1 (see --help)";;
    esac
done

echo "${C}${B}"
echo "  ╭──────────────────────────────────────────────╮"
echo "  │   Ubuntu Touch  ·  Xiaomi Pad 5 (nabu)        │"
echo "  │   installer                                   │"
echo "  ╰──────────────────────────────────────────────╯${N}"
echo "  Note: this project was created in cooperation with an AI assistant."
echo "  It is experimental: use it at your own risk."
[ "$DRY" = 1 ] && warn "DRY RUN: nothing will be written to the tablet."

# ---------------------------------------------------------------- fastboot
step "Getting ready"
FASTBOOT=""
if [ -x "$HERE/platform-tools/fastboot" ]; then FASTBOOT="$HERE/platform-tools/fastboot"
elif command -v fastboot >/dev/null 2>&1; then FASTBOOT="$(command -v fastboot)"
else
    case "$(uname -s)" in Darwin) os=darwin;; Linux) os=linux;; *) die "Unsupported system: $(uname -s)";; esac
    if [ "$os" = linux ] && [ "$(uname -m)" != x86_64 ]; then
        die "Please install 'fastboot' with your package manager (for example: sudo apt install fastboot)."
    fi
    info "fastboot not found: downloading the Android platform-tools from Google..."
    command -v curl >/dev/null 2>&1 || die "Please install 'fastboot' (curl is not available to download it)."
    curl -fL --progress-bar -o "$HERE/platform-tools.zip" "https://dl.google.com/android/repository/platform-tools-latest-$os.zip" \
        || die "Download failed. Check your internet connection, or install 'fastboot' yourself."
    ( cd "$HERE" && unzip -q -o platform-tools.zip && rm -f platform-tools.zip ) || die "Could not unpack platform-tools.zip"
    FASTBOOT="$HERE/platform-tools/fastboot"
    if [ "$os" = darwin ]; then xattr -dr com.apple.quarantine "$HERE/platform-tools" 2>/dev/null || true; fi
fi
ok "fastboot: $FASTBOOT"

info "Checking the installer files (this can take a minute)..."
if command -v sha256sum >/dev/null 2>&1; then SUM="sha256sum"; else SUM="shasum -a 256"; fi
( cd "$HERE" && $SUM -c SHA256SUMS >/dev/null 2>&1 ) || die "Some files are damaged or missing. Please download and unpack the installer again."
ok "all files are intact"

# ---------------------------------------------------------------- device
step "Connecting to the tablet"
if ! "$FASTBOOT" devices 2>/dev/null | grep -q fastboot; then
    echo
    echo "      ${B}Put the tablet in FASTBOOT mode:${N}"
    echo "        1. Turn the tablet off."
    echo "        2. Hold ${B}Volume Down + Power${N} until you see the FASTBOOT screen."
    echo "        3. Connect it to this computer with the USB cable."
    echo
    info "Waiting for the tablet... (Linux: if nothing happens, run this script with sudo)"
    until "$FASTBOOT" devices 2>/dev/null | grep -q fastboot; do sleep 1; done
fi
PRODUCT=$(getvar product)
[ "$PRODUCT" = nabu ] || die "This is not a Xiaomi Pad 5 (found: '${PRODUCT:-unknown}'). Nothing was changed."
ok "Xiaomi Pad 5 found"
if [ "$(getvar is-userspace)" = yes ]; then
    info "The tablet is in fastbootd: going back to the bootloader..."
    "$FASTBOOT" reboot bootloader >/dev/null 2>&1 || true
    wait_mode no || die "The tablet did not come back in fastboot mode."
fi
[ "$(getvar unlocked)" = yes ] || die "The bootloader is locked. Unlock it first with Xiaomi's official Mi Unlock tool. Nothing was changed."
ok "bootloader is unlocked"
SLOT=$(getvar current-slot); SLOT=${SLOT#_}
case "$SLOT" in a|b) ok "active slot: $SLOT";; *) die "Could not read the active slot. Nothing was changed.";; esac

echo
if [ "$MODE" = full ]; then
    echo "  ${R}${B}WARNING: this ERASES EVERYTHING on the tablet${N} (photos, apps, accounts)."
    echo "  The tablet must currently run a STOCK HyperOS or MIUI 13/14 (see GUIDE.txt)."
else
    echo "  This updates the Ubuntu Touch boot files and keeps all your data."
fi
confirm

if [ "$MODE" = full ] && [ "$VENDOR" = 1 ]; then
    # ------------------------------------------------------------ vendor (fastbootd)
    step "Installing the hardware drivers (vendor)"
    info "Switching the tablet to fastbootd (the screen changes: this is normal)..."
    fb reboot fastboot >/dev/null 2>&1 || true
    wait_mode yes || die "The tablet did not enter fastbootd. If it started Ubuntu Touch instead, this port is already installed: put it back in FASTBOOT mode and run  ./install.sh --reinstall . Otherwise flash the stock HyperOS first (see GUIDE.txt). Nothing was changed."
    flash_all "vendor_$SLOT" vendor
    flash_all "odm_$SLOT" odm
    ok "vendor and odm installed"
    info "Going back to the bootloader..."
    fb reboot bootloader >/dev/null 2>&1 || true
    wait_mode no || die "The tablet did not come back to the bootloader. Put it in FASTBOOT mode and run the installer again."
fi

if [ "$MODE" = full ]; then
    step "Installing the verification data (vbmeta)"
    fb flash "vbmeta_$SLOT" "$IMG/vbmeta.img"
    fb flash "vbmeta_system_$SLOT" "$IMG/vbmeta_system.img"
    ok "vbmeta installed"
fi

step "Installing the Ubuntu Touch kernel"
fb flash "boot_$SLOT" "$IMG/boot.img"
fb flash "vendor_boot_$SLOT" "$IMG/vendor_boot.img"
fb flash "dtbo_$SLOT" "$IMG/dtbo.img"
ok "boot, vendor_boot and dtbo installed"

if [ "$MODE" = full ]; then
    step "Installing the Ubuntu Touch system (the longest step: 5-10 minutes)"
    fb erase userdata
    flash_all userdata userdata
    ok "system installed"
fi

step "Finishing"
if [ "$DRY" = 0 ]; then
    if [ "$(getvar unlocked)" = yes ]; then ok "bootloader still unlocked"; else warn "could not confirm the bootloader state"; fi
fi
fb reboot >/dev/null 2>&1 || true
rm -f "$HERE/.fastboot.log"
echo
echo "  ${G}${B}All done!${N}"
echo "  The tablet is restarting. The first start takes 1-2 minutes: you will see"
echo "  the Mi logo and then the Ubuntu Touch welcome screen."
echo
