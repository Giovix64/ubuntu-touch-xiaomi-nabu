#!/usr/bin/python3
"""Scarica dall'OpenStore i click preinstallati della build nabu in rootfs-overlay/usr/share/nabu/clicks/.
Per ogni app sceglie l'ultima revisione arm64 con framework supportato da UT 24.04-2.x.
uso: tools/fetch-clicks.py
"""
import json, os, sys, urllib.request, hashlib

APPS = ["openstore.openstore-team", "calculator.ubports", "clock.ubports", "filemanager.ubports",
        "terminal.ubports", "gallery.ubports", "music.ubports", "calendar.ubports",
        "weather.ubports"]  # docviewer: 206 MB, lasciato all OpenStore
# framework presenti in /usr/share/click/frameworks su UT 24.04-2.x
FRAMEWORKS = {"ubuntu-sdk-16.04", "ubuntu-sdk-20.04", "ubuntu-sdk-20.04.1",
              "ubuntu-touch-24.04-1.x", "ubuntu-touch-24.04-2.x"}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rootfs-overlay/usr/share/nabu/clicks")

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "nabu-port-build"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()

def ok_fw(fw):
    return all(f.strip() in FRAMEWORKS or f.strip().split("-qml")[0] in FRAMEWORKS
               for f in (fw or "").split(",") if f.strip())

os.makedirs(OUT, exist_ok=True)
for old in os.listdir(OUT):
    os.remove(os.path.join(OUT, old))
for app in APPS:
    d = json.loads(get("https://open-store.io/api/v4/apps/" + app))["data"]
    revs = [r for r in d["revisions"] if r.get("architecture") in ("arm64", "all")
            and r.get("channel") == "focal" and ok_fw(r.get("framework"))]
    if not revs:
        print("NESSUNA revisione compatibile:", app); continue
    r = max(revs, key=lambda r: r["revision"])
    data = get(r["download_url"])
    sha = next((x.get("download_sha512") for x in d.get("downloads", [])
                if x.get("version") == r["version"] and x.get("architecture") == r["architecture"]), None)
    if sha and hashlib.sha512(data).hexdigest() != sha:
        sys.exit("sha512 errato per " + app)
    name = "%s_%s_%s.click" % (app, r["version"], r["architecture"])
    open(os.path.join(OUT, name), "wb").write(data)
    print("%-26s %-28s %-24s %6d KB %s" % (app, r["version"], r["framework"], len(data) // 1024,
                                           "sha512 ok" if sha else "(sha non pubblicato per questa revisione)"))
