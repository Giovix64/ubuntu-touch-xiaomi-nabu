#!/bin/bash
# Prepara i file di rilascio del port Ubuntu Touch per Xiaomi Pad 5 (nabu).
# Da lanciare dalla cartella del repo (ubuntu-touch-nabu), sull'host:
#     release/make-release.sh [versione]          (default versione: AAAAMMGG)
#     ROOTFS=release/build/rootfs.img release/make-release.sh ...   (rootfs pubblico gia' creato)
# Richiede: build gia' fatta (images/boot.img, images/vendor_boot.img, images/dtbo.img, ota/ubuntu_command),
#           sudo (mount loop per il rootfs pubblico), xz, gzip, python3, sha256sum, git.
# Uscita: release/dist/<nome>-fastboot.tar, release/dist/<nome>-recovery.zip, release/dist/kernel-patches/
set -e
cd "$(dirname "$0")/.."
REPO=$(pwd)
VER="${1:-$(date +%Y%m%d)}"
NAME="ubuntu-touch-nabu-$VER"
OUT="$REPO/release/dist"
STAGE="$OUT/$NAME"
BUILD="$REPO/release/build"
KERNEL_SRC="$REPO/../src/kernel-nabu-droidian"
KERNEL_BASE="aabc62cf0^"          # primo commit nostro sul branch halium-13.0

say() { echo; echo "== $*"; }

for f in images/boot.img images/vendor_boot.img images/dtbo.img ota/ubuntu_command; do
    [ -f "$f" ] || { echo "manca $f: fare prima la build"; exit 1; }
done
rm -rf "$STAGE" "$OUT/$NAME"-*; mkdir -p "$STAGE/images" "$STAGE/tools" "$BUILD"

# ------------------------------------------------------------------ rootfs pubblico
if [ -n "${ROOTFS:-}" ]; then
    say "rootfs pubblico gia' pronto: $ROOTFS"
    grep -q "profile=public" <(debugfs -R "cat /usr/share/nabu/build-info" "$ROOTFS" 2>/dev/null) \
        || { echo "$ROOTFS non e' una build con NABU_PROFILE=public"; exit 1; }
else
    say "rootfs pubblico (pipeline ufficiale + NABU_PROFILE=public)"
    sudo ./build/system-image-from-ota.sh ota/ubuntu_command "$BUILD" > "$BUILD/image.log" 2>&1
    sudo NABU_PROFILE=public tools/finalize-rootfs.sh "$BUILD/rootfs.img" | tail -4
    sudo chown "$(id -u):$(id -g)" "$BUILD"/*
    ROOTFS="$BUILD/rootfs.img"
fi

# ------------------------------------------------------------------ pacchetto fastboot
say "pacchetto fastboot"
cp images/boot.img images/vendor_boot.img images/dtbo.img "$STAGE/images/"
xz -T0 -6 -c "$ROOTFS" > "$STAGE/images/ubuntu.img.xz"
cp release/install.sh "$STAGE/"
cp release/README.md release/GUIDE.txt release/GUIDA.txt "$STAGE/"
cp tools/payload_extract.py "$STAGE/tools/"
chmod +x "$STAGE/install.sh" "$STAGE/tools/payload_extract.py"
( cd "$STAGE" && sha256sum images/boot.img images/vendor_boot.img images/dtbo.img images/ubuntu.img.xz > SHA256SUMS )
tar -C "$OUT" -cf "$OUT/$NAME-fastboot.tar" "$NAME"

# ------------------------------------------------------------------ zip per recovery
say "zip per TWRP/OrangeFox"
Z="$BUILD/zip"; rm -rf "$Z"; mkdir -p "$Z/images"
cp -r release/recovery-zip/META-INF "$Z/"
cp images/boot.img images/vendor_boot.img images/dtbo.img "$Z/images/"
gzip -6 -c "$ROOTFS" > "$Z/images/ubuntu.img.gz"
( cd "$Z" && sha256sum images/boot.img images/vendor_boot.img images/dtbo.img images/ubuntu.img.gz > SHA256SUMS
  echo "$(sha256sum "$ROOTFS" | cut -d' ' -f1)  images/ubuntu.img" >> SHA256SUMS )
python3 - "$Z" "$OUT/$NAME-recovery.zip" <<'PY'
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_STORED) as z:      # immagini gia' compresse: STORED
    for root, _, files in os.walk(src):
        for f in sorted(files):
            p = os.path.join(root, f)
            arc = os.path.relpath(p, src)
            if f == "update-binary":                            # deve restare eseguibile
                info = zipfile.ZipInfo.from_file(p, arc)
                info.external_attr = 0o100755 << 16
                with open(p, "rb") as fh:
                    z.writestr(info, fh.read(), zipfile.ZIP_STORED)
            else:
                z.write(p, arc, zipfile.ZIP_STORED)
PY

# ------------------------------------------------------------------ patch del kernel (GPL)
say "patch del kernel"
rm -rf "$OUT/kernel-patches"
git -C "$KERNEL_SRC" format-patch -q -o "$OUT/kernel-patches" "$KERNEL_BASE..HEAD"
# modifiche alla configurazione non ancora in un commit (es. squashfs): esportate a parte
if ! git -C "$KERNEL_SRC" diff --quiet -- arch/arm64/configs/halium.config; then
    git -C "$KERNEL_SRC" diff -- arch/arm64/configs/halium.config > "$OUT/kernel-patches/9999-uncommitted-halium-config.patch"
    echo "ATTENZIONE: halium.config ha modifiche non committate (esportate in 9999-uncommitted-halium-config.patch)"
fi
cp release/GUIDE.txt release/GUIDA.txt "$OUT/"
ls "$OUT/kernel-patches"

# ------------------------------------------------------------------ checksum finali
( cd "$OUT" && sha256sum "$NAME-fastboot.tar" "$NAME-recovery.zip" > "$NAME-SHA256SUMS" )
say "fatto"
ls -lh "$OUT" | grep -v "^totale"
