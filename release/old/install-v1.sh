#!/usr/bin/env bash
# =============================================================================
#  Ubuntu Touch for Xiaomi Pad 5 (nabu) — fastboot installer
#
#  Usage:
#    ./install.sh --arrow-zip Arrow-v13.1-nabu-OFFICIAL-20240204-VANILLA.zip   # full install (WIPES DATA)
#    ./install.sh --skip-vendor        # reinstall: ArrowOS vendor/odm/vbmeta already on the device
#    ./install.sh --boot-only          # only boot/vendor_boot/dtbo (keeps everything)
#  Options:
#    --dry-run      print the fastboot commands instead of running them
#    --yes          do not ask for confirmation
#    --work DIR     working directory (default: ./work, needs ~15 GB free on a Linux filesystem)
#
#  This script NEVER locks the bootloader and never runs Xiaomi's flash_all scripts.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="$HERE/images"
WORK="$HERE/work"
ARROW_ZIP=""
MODE="full"          # full | skip-vendor | boot-only
DRY=0
YES=0

# ---------------------------------------------------------------- output
if [ -t 1 ]; then
    B=$'\e[1m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=""; R=""; G=""; Y=""; C=""; N=""
fi
STEP=0; STEPS=0
banner() {
    echo "${C}${B}"
    echo "  ╭──────────────────────────────────────────────╮"
    echo "  │   Ubuntu Touch  ·  Xiaomi Pad 5 (nabu)        │"
    echo "  │   fastboot installer                          │"
    echo "  ╰──────────────────────────────────────────────╯${N}"
}
step()  { STEP=$((STEP + 1)); echo; echo "${B}${C}[$STEP/$STEPS]${N} ${B}$*${N}"; }
info()  { echo "      $*"; }
ok()    { echo "      ${G}✔${N} $*"; }
warn()  { echo "      ${Y}!${N} $*"; }
die()   { echo; echo "  ${R}${B}✘ $*${N}"; echo; exit 1; }
run()   { if [ "$DRY" = 1 ]; then echo "      ${Y}+${N} $*"; else "$@"; fi; }
fb()    { run fastboot "$@"; }
getvar() { fastboot getvar "$1" 2>&1 | awk -v k="$1:" '$1 == k { print $2; exit }'; }
confirm() {
    [ "$YES" = 1 ] && return 0
    read -r -p "      $1 [y/N] " a
    case "$a" in y|Y|yes|YES) return 0;; *) die "Aborted by user.";; esac
}

# ---------------------------------------------------------------- arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --arrow-zip)   ARROW_ZIP="$(realpath "$2")"; shift 2;;
        --skip-vendor) MODE="skip-vendor"; shift;;
        --boot-only)   MODE="boot-only"; shift;;
        --dry-run)     DRY=1; shift;;
        --yes|-y)      YES=1; shift;;
        --work)        WORK="$(realpath -m "$2")"; shift 2;;
        -h|--help)     sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
        *) die "Unknown option: $1 (see --help)";;
    esac
done
[ "$MODE" = full ] && [ -z "$ARROW_ZIP" ] && die "Full install needs --arrow-zip <ArrowOS 13.1 nabu zip> (or use --skip-vendor / --boot-only)."
[ -n "$ARROW_ZIP" ] && [ ! -f "$ARROW_ZIP" ] && die "ArrowOS zip not found: $ARROW_ZIP"

case "$MODE" in
    full)        STEPS=7;;
    skip-vendor) STEPS=5;;
    boot-only)   STEPS=4;;
esac

banner
[ "$DRY" = 1 ] && warn "DRY RUN: nothing will be written to the device."

# ---------------------------------------------------------------- 1. checks
step "Checking tools and device"
need="fastboot sha256sum"
[ "$MODE" != boot-only ] && need="$need xz mke2fs img2simg truncate"
[ "$MODE" = full ] && need="$need python3"
for t in $need; do
    command -v "$t" >/dev/null 2>&1 || die "Missing tool: $t  (Debian/Ubuntu: apt install fastboot e2fsprogs android-sdk-libsparse-utils xz-utils python3)"
done
ok "tools: $need"

info "Waiting for the tablet in fastboot mode (Volume Down + Power, cable connected)..."
for i in $(seq 120); do
    fastboot devices 2>/dev/null | grep -q fastboot && break
    sleep 1
done
fastboot devices 2>/dev/null | grep -q fastboot || die "No device in fastboot mode found."
PRODUCT=$(getvar product)
[ "$PRODUCT" = nabu ] || die "This is not a Xiaomi Pad 5 (product: '${PRODUCT:-?}'). Nothing was done."
ok "device: Xiaomi Pad 5 (nabu)"
[ "$(getvar is-userspace)" = yes ] && die "The tablet is in fastbootd (userspace). Reboot it to the bootloader: fastboot reboot bootloader"
[ "$(getvar unlocked)" = yes ] || die "The bootloader is locked. Unlock it with Xiaomi's official tool first."
ok "bootloader: unlocked"
SLOT=$(getvar current-slot); SLOT=${SLOT#_}
case "$SLOT" in a|b) ok "active slot: $SLOT";; *) die "Cannot read the active slot (got '$SLOT').";; esac

# ---------------------------------------------------------------- 2. files
step "Verifying release files"
( cd "$HERE" && sha256sum --quiet -c SHA256SUMS ) || die "Checksum mismatch: the download is corrupted."
ok "boot.img, vendor_boot.img, dtbo.img$([ "$MODE" != boot-only ] && echo ", ubuntu.img.xz") verified"

case "$MODE" in
    full)
        echo
        echo "  ${R}${B}This will ERASE ALL DATA on the tablet${N} (photos, apps, accounts)."
        echo "  It will flash: vendor + odm + vbmeta (from ArrowOS), boot, vendor_boot, dtbo, userdata."
        confirm "Continue?";;
    skip-vendor)
        echo
        echo "  ${R}${B}This will ERASE ALL DATA on the tablet${N} (userdata is reformatted)."
        confirm "Continue?";;
    boot-only)
        confirm "Flash boot, vendor_boot and dtbo to slot $SLOT?";;
esac

# ---------------------------------------------------------------- 3-4. vendor
if [ "$MODE" = full ]; then
    step "Extracting vendor, odm and vbmeta from the ArrowOS zip"
    mkdir -p "$WORK/arrow"
    run python3 "$HERE/tools/payload_extract.py" "$ARROW_ZIP" extract "$WORK/arrow" \
        vendor odm vbmeta vbmeta_system
    if [ "$DRY" = 0 ]; then
        for p in vendor odm vbmeta vbmeta_system; do
            [ -s "$WORK/arrow/$p.img" ] || die "Could not extract $p.img from $ARROW_ZIP"
        done
    fi
    ok "images extracted"

    step "Flashing ArrowOS vendor + odm (fastbootd) and vbmeta (bootloader)"
    info "Rebooting into fastbootd (logical partitions live inside 'super')..."
    fb reboot fastboot
    if [ "$DRY" = 0 ]; then
        for i in $(seq 90); do [ "$(getvar is-userspace)" = yes ] && break; sleep 2; done
        [ "$(getvar is-userspace)" = yes ] || die "fastbootd did not come up. Is the stock HyperOS boot image still on slot $SLOT? (see README)"
    fi
    ok "in fastbootd"
    fb flash vendor "$WORK/arrow/vendor.img"
    fb flash odm "$WORK/arrow/odm.img"
    fb reboot bootloader
    if [ "$DRY" = 0 ]; then
        for i in $(seq 60); do fastboot devices 2>/dev/null | grep -q fastboot && [ "$(getvar is-userspace)" != yes ] && break; sleep 2; done
    fi
    fb flash "vbmeta_$SLOT" "$WORK/arrow/vbmeta.img"
    fb flash "vbmeta_system_$SLOT" "$WORK/arrow/vbmeta_system.img"
    ok "vendor, odm, vbmeta, vbmeta_system flashed"
fi

# ---------------------------------------------------------------- 5. boot
step "Flashing Ubuntu Touch boot images to slot $SLOT"
fb flash "boot_$SLOT" "$IMG/boot.img"
fb flash "vendor_boot_$SLOT" "$IMG/vendor_boot.img"
fb flash "dtbo_$SLOT" "$IMG/dtbo.img"
ok "boot, vendor_boot, dtbo flashed"

# ---------------------------------------------------------------- 6. userdata
if [ "$MODE" != boot-only ]; then
    step "Building and flashing userdata with the Ubuntu Touch system"
    SIZE=$(getvar partition-size:userdata)
    [ -n "$SIZE" ] || die "Cannot read the userdata partition size."
    SIZE=$((SIZE))
    info "userdata partition: $((SIZE / 1024 / 1024 / 1024)) GiB"
    mkdir -p "$WORK/stage"
    rm -f "$WORK/stage/ubuntu.img" "$WORK/userdata.raw" "$WORK/userdata.simg"
    info "Unpacking ubuntu.img..."
    run sh -c "xz -dc '$IMG/ubuntu.img.xz' | dd of='$WORK/stage/ubuntu.img' bs=4M conv=sparse status=none"
    info "Creating the ext4 filesystem (sparse file, uses little real space)..."
    run truncate -s "$SIZE" "$WORK/userdata.raw"
    # orphan_file (e2fsprogs >= 1.47 default) is not supported by the 4.14 kernel
    MKFS="mke2fs -q -F -t ext4 -b 4096 -L userdata -d $WORK/stage"
    if [ "$DRY" = 1 ]; then
        run $MKFS -O ^orphan_file "$WORK/userdata.raw"
    else
        # older e2fsprogs do not know orphan_file at all: retry without the option
        $MKFS -O ^orphan_file "$WORK/userdata.raw" 2>/dev/null || $MKFS "$WORK/userdata.raw"
    fi
    run img2simg "$WORK/userdata.raw" "$WORK/userdata.simg"
    rm -f "$WORK/userdata.raw"
    ok "userdata image ready"
    info "Flashing userdata (a few minutes)..."
    fb flash userdata "$WORK/userdata.simg"
    ok "userdata flashed"
fi

# ---------------------------------------------------------------- 7. done
step "Finishing"
if [ "$DRY" = 0 ]; then
    [ "$(getvar unlocked)" = yes ] && ok "bootloader still unlocked" || warn "could not confirm the bootloader state"
fi
fb reboot
ok "rebooting"
echo
echo "  ${G}${B}Done!${N} The first boot takes about a minute (Mi logo, then the Ubuntu Touch wizard)."
[ "$MODE" != boot-only ] && echo "  You can delete '$WORK' to free space."
echo
