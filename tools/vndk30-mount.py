#!/usr/bin/python3
# Monta l'APEX com.android.vndk.v30 preso dalla system_ext di HyperOS (super stock, slot attuale).
# Serve perché il vendor HyperOS di nabu dichiara ro.vndk.version=30 e la GSI Halium 13 fornisce
# solo v31/v33: senza v30 vndservicemanager/keymaster/qseecomd non si linkano e Android si ferma.
# Eseguito come ExecStartPost di lxc-android-config-mount-apexes.service (prima del container).
import os, subprocess, zipfile, sys

slot = ""
for tok in open("/proc/cmdline").read().split():
    if tok.startswith("androidboot.slot_suffix="):
        slot = tok.split("=", 1)[1]
dev = f"/dev/mapper/system_ext{slot}"
src_mnt = "/run/hyperos_system_ext"
apex = f"{src_mnt}/apex/com.android.vndk.v30.apex"
target = "/android/apex/com.android.vndk.v30"

if os.path.ismount(target):
    print("vndk v30 già montato"); sys.exit(0)
os.makedirs(src_mnt, exist_ok=True)
if not os.path.ismount(src_mnt):
    subprocess.run(["mount", "-o", "ro", dev, src_mnt], check=True)
with zipfile.ZipFile(apex) as zf:
    info = zf.getinfo("apex_payload.img")
    assert info.compress_type == zipfile.ZIP_STORED, "apex_payload.img compresso"
with open(apex, "rb") as f:
    f.seek(info.header_offset + 26)
    n, e = int.from_bytes(f.read(2), "little"), int.from_bytes(f.read(2), "little")
offset = info.header_offset + 30 + n + e
os.makedirs(target, exist_ok=True)
subprocess.run(["mount", "-o", f"loop,offset={offset},ro", apex, target], check=True)
print(f"Montato {apex} (offset {offset}) su {target}")
