#!/bin/bash
# Aggiunge a images/rootfs.img (uscita di system-image-from-ota.sh) i file NUOVI di
# rootfs-overlay/ e abilita i servizi. overlay/ (overlaystore Halium) puo' solo
# sostituire file gia' esistenti; qui invece si scrive direttamente nel rootfs.
# Uso (dalla cartella del repo, sull'host): sudo tools/finalize-rootfs.sh [images/rootfs.img]
#   NABU_PROFILE=public  -> build da rilasciare: senza le personalizzazioni di sviluppo
#                           (USB developer_mode di default, app Waydroid visibili nel drawer)
#   NABU_PROFILE=personal (predefinito) -> tutto
set -e
PROFILE="${NABU_PROFILE:-personal}"
case "$PROFILE" in public|personal) ;; *) echo "NABU_PROFILE deve essere public o personal"; exit 1;; esac
# file di rootfs-overlay usati solo nel profilo personal
PERSONAL_ONLY="etc/usb-moded/90-device-specific-config.ini usr/local/bin/nabu-waydroid-apps
etc/systemd/system/nabu-waydroid-apps.path etc/systemd/system/nabu-waydroid-apps.service"
IMG="$(realpath "${1:-images/rootfs.img}")"
SRC="$(realpath "$(dirname "$0")/../rootfs-overlay")"
[ "$(id -u)" = 0 ] || { echo "serve root (mount loop)"; exit 1; }
MNT=$(mktemp -d)
trap 'mountpoint -q "$MNT" && umount "$MNT"; rmdir "$MNT"' EXIT
mount -o loop "$IMG" "$MNT"

# file: proprietario root, permessi come nel repo
STASH=$(mktemp -d)
if [ "$PROFILE" = public ]; then
    # conserva gli originali del rootfs che il profilo personal sostituirebbe
    for f in $PERSONAL_ONLY; do
        [ -e "$MNT/$f" ] && install -D -m 644 "$MNT/$f" "$STASH/$f"
    done
fi
cp -r --preserve=mode --no-preserve=ownership "$SRC/." "$MNT/"
if [ "$PROFILE" = public ]; then
    for f in $PERSONAL_ONLY; do
        rm -f "$MNT/$f"
        [ -e "$STASH/$f" ] && cp -a "$STASH/$f" "$MNT/$f"
    done
fi
rm -rf "$STASH"
chown -R root:root "$MNT/etc/nabu-pen.conf" "$MNT/usr/local/bin" "$MNT/usr/share/nabu" \
    "$MNT/etc/systemd/system" "$MNT/etc/systemd/user" "$MNT/etc/udev/rules.d" "$MNT/etc/usb-moded"

# servizi di sistema
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
for s in nabu-wlan-on nabu-pen-enable nabu-pen-bridge nabu-clicks-install nabu-grow-userdata; do
    ln -sf "/etc/systemd/system/$s.service" "$MNT/etc/systemd/system/multi-user.target.wants/$s.service"
done
# servizi utente (sessione Lomiri)
mkdir -p "$MNT/etc/systemd/user/graphical-session.target.wants"
ln -sf /etc/systemd/user/nabu-pen-battery.service \
    "$MNT/etc/systemd/user/graphical-session.target.wants/nabu-pen-battery.service"

# app inutili su questo tablet (niente modem, niente slot SD): nascoste dal drawer con una
# copia del .desktop in /usr/local/share/applications (precede /usr/share in XDG_DATA_DIRS)
mkdir -p "$MNT/usr/local/share/applications"
for a in lomiri-dialer-app lomiri-messaging-app ciborium; do
    [ -f "$MNT/usr/share/applications/$a.desktop" ] || continue
    sed '/^\[Desktop Entry\]/a NoDisplay=true' "$MNT/usr/share/applications/$a.desktop" \
        > "$MNT/usr/local/share/applications/$a.desktop"
done

if [ "$PROFILE" = personal ]; then
    ln -sf /etc/systemd/system/nabu-waydroid-apps.path \
        "$MNT/etc/systemd/system/multi-user.target.wants/nabu-waydroid-apps.path"
fi
# versione della build (letta da make-release.sh e utile per le segnalazioni)
mkdir -p "$MNT/usr/share/nabu"
echo "profile=$PROFILE built=$(date -u +%Y-%m-%dT%H:%MZ)" > "$MNT/usr/share/nabu/build-info"

# impostazioni predefinite (tema tastiera, barra laterale)
glib-compile-schemas "$MNT/usr/share/glib-2.0/schemas"

sync
echo "profilo: $PROFILE"
echo "file aggiunti:"; (cd "$SRC" && find . -type f | sort)
df -h "$MNT" | tail -1
umount "$MNT"
e2fsck -fn "$IMG" >/dev/null && echo "e2fsck ok: $IMG"
exit 0
