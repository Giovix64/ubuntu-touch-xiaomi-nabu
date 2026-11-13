#!/bin/bash
# Prepara i file di rilascio del port Ubuntu Touch per Xiaomi Pad 5 (nabu).
# Dalla cartella del repo, sull'host:   release/make-release.sh [versione]     (default: AAAAMMGG)
#   ROOTFS=release/build/rootfs.img  riusa un rootfs pubblico gia' creato (evita sudo)
#   ARROW=cartella con vendor-fs.img odm-fs.img vbmeta.img vbmeta_system.img di ArrowOS 13.1
#         (vendor/odm = solo il filesystem, senza coda dm-verity; default ../downloads/arrowos/img)
# Uscita in release/dist/:
#   <nome>-installer.zip   installer completo: Windows (.bat), macOS (.command), Linux (.sh), Chrome (installer.html)
#   <nome>-recovery.zip    zip completo per TWRP/OrangeFox
#   kernel-patches/, GUIDE.txt, GUIDA.txt, <nome>-SHA256SUMS
set -e
cd "$(dirname "$0")/.."
REPO=$(pwd)
VER="${1:-$(date +%Y%m%d)}"
NAME="ubuntu-touch-nabu-$VER"
OUT="$REPO/release/dist"; STAGE="$OUT/$NAME"; BUILD="$REPO/release/build"
ARROW="${ARROW:-$REPO/../downloads/arrowos/img}"
KERNEL_SRC="$REPO/../src/kernel-nabu-droidian"
KERNEL_BASE="5c0466e98"          # primo commit nostro sul branch halium-13.0
USERDATA_SIZE=8G                  # filesystem flashato; nabu-grow-userdata lo estende al primo avvio
CHUNK_MB=256                      # ogni file sparse <= 256 MB (sotto il max-download-size del bootloader)
say() { echo; echo "== $*"; }

for f in images/boot.img images/vendor_boot.img images/dtbo.img ota/ubuntu_command \
         "$ARROW/vendor-fs.img" "$ARROW/odm-fs.img" "$ARROW/vbmeta.img" "$ARROW/vbmeta_system.img"; do
    [ -f "$f" ] || { echo "manca $f"; exit 1; }
done
rm -rf "$STAGE" "$OUT/$NAME"-*; mkdir -p "$STAGE/images" "$BUILD"

# ------------------------------------------------------------------ rootfs pubblico
if [ -n "${ROOTFS:-}" ]; then
    say "rootfs pubblico gia' pronto: $ROOTFS"
else
    say "rootfs pubblico (pipeline ufficiale + NABU_PROFILE=public)"
    sudo ./build/system-image-from-ota.sh ota/ubuntu_command "$BUILD" > "$BUILD/image.log" 2>&1
    sudo NABU_PROFILE=public tools/finalize-rootfs.sh "$BUILD/rootfs.img" | tail -4
    sudo chown "$(id -u):$(id -g)" "$BUILD"/*
    ROOTFS="$BUILD/rootfs.img"
fi
debugfs -R "cat /usr/share/nabu/build-info" "$ROOTFS" 2>/dev/null | grep -q "profile=public" \
    || { echo "$ROOTFS non e' una build con NABU_PROFILE=public"; exit 1; }
debugfs -R "stat /usr/share/nabu/com.android.vndk.v30.apex" "$ROOTFS" 2>/dev/null | grep -q "Type: regular" \
    || { echo "$ROOTFS non contiene il VNDK v30 incluso (rootfs-overlay/usr/share/nabu/*.apex)"; exit 1; }
debugfs -R "stat /usr/local/bin/nabu-grow-userdata" "$ROOTFS" 2>/dev/null | grep -q "Type: regular" \
    || { echo "$ROOTFS non contiene nabu-grow-userdata (serve per userdata da $USERDATA_SIZE)"; exit 1; }

# ------------------------------------------------------------------ immagini dell'installer
say "immagini (boot, vbmeta, vendor, odm, userdata) in pezzi sparse da $CHUNK_MB MB"
I="$STAGE/images"
cp images/boot.img images/vendor_boot.img images/dtbo.img "$ARROW/vbmeta.img" "$ARROW/vbmeta_system.img" "$I/"
python3 tools/sparse_chunks.py "$ARROW/vendor-fs.img" "$I/vendor" $CHUNK_MB
python3 tools/sparse_chunks.py "$ARROW/odm-fs.img" "$I/odm" $CHUNK_MB
U="$BUILD/userdata"; rm -rf "$U" "$BUILD/userdata.raw"; mkdir -p "$U"
cp --sparse=always --reflink=auto "$ROOTFS" "$U/ubuntu.img"; chmod 644 "$U/ubuntu.img"
truncate -s $USERDATA_SIZE "$BUILD/userdata.raw"
# orphan_file (default da e2fsprogs 1.47) non e' supportato dal kernel 4.14
mke2fs -q -F -t ext4 -b 4096 -L userdata -O ^orphan_file -d "$U" "$BUILD/userdata.raw"
python3 tools/sparse_chunks.py "$BUILD/userdata.raw" "$I/userdata" $CHUNK_MB
rm -rf "$U" "$BUILD/userdata.raw"

say "manifest e checksum"
python3 - "$I" "$NAME" <<'PY'
import glob, hashlib, json, os, sys
d, name = sys.argv[1], sys.argv[2]
def parts(p): return sorted(os.path.basename(f) for f in glob.glob(os.path.join(d, p + ".[0-9][0-9].img")))
steps = [
  {"title": "Hardware drivers (vendor)", "mode": "fastbootd", "partition": "vendor_{slot}", "files": parts("vendor")},
  {"title": "Hardware drivers (odm)", "mode": "fastbootd", "partition": "odm_{slot}", "files": parts("odm")},
  {"title": "Verification data (vbmeta)", "mode": "bootloader", "partition": "vbmeta_{slot}", "files": ["vbmeta.img"]},
  {"title": "Verification data (vbmeta_system)", "mode": "bootloader", "partition": "vbmeta_system_{slot}", "files": ["vbmeta_system.img"]},
  {"title": "Ubuntu Touch kernel (boot)", "mode": "bootloader", "partition": "boot_{slot}", "files": ["boot.img"]},
  {"title": "Ubuntu Touch kernel (vendor_boot)", "mode": "bootloader", "partition": "vendor_boot_{slot}", "files": ["vendor_boot.img"]},
  {"title": "Device tree (dtbo)", "mode": "bootloader", "partition": "dtbo_{slot}", "files": ["dtbo.img"]},
  {"title": "Ubuntu Touch system (the longest step)", "mode": "bootloader", "partition": "userdata", "erase": "userdata", "files": parts("userdata")},
  {"title": "Restart the tablet", "mode": "bootloader", "reboot": True},
]
files = {}
for s in steps:
    for f in s.get("files", []):
        h = hashlib.sha256()
        with open(os.path.join(d, f), "rb") as fh:
            for b in iter(lambda: fh.read(1 << 22), b""): h.update(b)
        files[f] = {"size": os.path.getsize(os.path.join(d, f)), "sha256": h.hexdigest()}
json.dump({"name": name, "device": "nabu", "files": files, "steps": steps}, open(os.path.join(d, "manifest.json"), "w"), indent=1)
with open(os.path.join(d, "..", "SHA256SUMS"), "w") as o:
    for f in sorted(files): o.write("%s  images/%s\n" % (files[f]["sha256"], f))
print(len(files), "file,", sum(v["size"] for v in files.values()) >> 20, "MB")
PY

say "pacchetto installer (Windows, macOS, Linux, Chrome)"
cp release/install.sh release/install-linux.sh release/install-macos.command release/install-windows.bat \
   release/installer.html release/README.md release/GUIDE.txt release/GUIDA.txt "$STAGE/"
python3 release/make-anyrom-html.py release/installer.html "$STAGE/installer-any-rom.html"
chmod +x "$STAGE"/install*.sh "$STAGE/install-macos.command"
( cd "$OUT" && rm -f "$NAME-installer.zip" && zip -q -r -6 "$NAME-installer.zip" "$NAME" )

# ------------------------------------------------------------------ zip per recovery
say "zip completo per TWRP/OrangeFox"
Z="$BUILD/zip"; rm -rf "$Z"; mkdir -p "$Z/images"
cp -r release/recovery-zip/META-INF "$Z/"
cp images/boot.img images/vendor_boot.img images/dtbo.img "$ARROW/vbmeta.img" "$ARROW/vbmeta_system.img" "$Z/images/"
gzip -6 -c "$ROOTFS" > "$Z/images/ubuntu.img.gz"
gzip -6 -c "$ARROW/vendor-fs.img" > "$Z/images/vendor.img.gz"
gzip -6 -c "$ARROW/odm-fs.img" > "$Z/images/odm.img.gz"
( cd "$Z"
  sha256sum images/boot.img images/vendor_boot.img images/dtbo.img images/vbmeta.img images/vbmeta_system.img > SHA256SUMS
  echo "$(sha256sum "$ROOTFS" | cut -d' ' -f1)  images/ubuntu.img" >> SHA256SUMS
  for p in vendor odm; do
      echo "$(sha256sum "$ARROW/$p-fs.img" | cut -d' ' -f1)  images/$p.img" >> SHA256SUMS
      echo "$(stat -c%s "$ARROW/$p-fs.img")  images/$p.img.size" >> SHA256SUMS
  done )
python3 - "$Z" "$OUT/$NAME-recovery.zip" <<'PY'
import os, sys, zipfile
src, dst = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_STORED) as z:      # immagini gia' compresse: STORED
    for root, _, files in os.walk(src):
        for f in sorted(files):
            p = os.path.join(root, f); arc = os.path.relpath(p, src)
            if f == "update-binary":                            # deve restare eseguibile
                info = zipfile.ZipInfo.from_file(p, arc); info.external_attr = 0o100755 << 16
                with open(p, "rb") as fh: z.writestr(info, fh.read(), zipfile.ZIP_STORED)
            else:
                z.write(p, arc, zipfile.ZIP_STORED)
PY
rm -rf "$Z"

# ------------------------------------------------------------------ patch del kernel (GPL)
say "patch del kernel"
rm -rf "$OUT/kernel-patches"
git -C "$KERNEL_SRC" format-patch -q -o "$OUT/kernel-patches" "$KERNEL_BASE..HEAD"
if ! git -C "$KERNEL_SRC" diff --quiet -- arch/arm64/configs/halium.config; then
    git -C "$KERNEL_SRC" diff -- arch/arm64/configs/halium.config > "$OUT/kernel-patches/9999-uncommitted-halium-config.patch"
    echo "ATTENZIONE: halium.config ha modifiche non committate (9999-uncommitted-halium-config.patch)"
fi
cp release/GUIDE.txt release/GUIDA.txt "$OUT/"

( cd "$OUT" && sha256sum "$NAME-installer.zip" "$NAME-recovery.zip" > "$NAME-SHA256SUMS" )
say "fatto"
ls -lh "$OUT" | grep -v "^totale"
