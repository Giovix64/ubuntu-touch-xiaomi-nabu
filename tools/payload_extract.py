#!/usr/bin/env python3
"""Estrattore minimale di payload.bin (OTA A/B Android, solo pacchetti "full").

Uso:
  payload_extract.py <ota.zip|payload.bin> list
  payload_extract.py <ota.zip|payload.bin> extract <cartella_uscita> [partizione ...]

Verifica lo SHA-256 di ogni operazione e dell'immagine finale di ogni partizione.
Scritto per il port UT di nabu: niente dipendenze esterne (solo libreria standard).
"""
import bz2, hashlib, lzma, os, struct, sys, zipfile

# --- protobuf minimale -------------------------------------------------------
def varint(b, i):
    r = s = 0
    while True:
        c = b[i]; i += 1
        r |= (c & 0x7F) << s; s += 7
        if not c & 0x80:
            return r, i

def fields(b):
    """Restituisce [(numero_campo, valore)] di un messaggio protobuf."""
    i, out = 0, []
    while i < len(b):
        key, i = varint(b, i)
        f, wt = key >> 3, key & 7
        if wt == 0:
            v, i = varint(b, i)
        elif wt == 1:
            v = b[i:i + 8]; i += 8
        elif wt == 2:
            n, i = varint(b, i); v = b[i:i + n]; i += n
        elif wt == 5:
            v = b[i:i + 4]; i += 4
        else:
            raise ValueError("wire type %d non gestito" % wt)
        out.append((f, v))
    return out

def first(fl, num, default=None):
    for f, v in fl:
        if f == num:
            return v
    return default

# --- payload ----------------------------------------------------------------
OPS = {0: "REPLACE", 1: "REPLACE_BZ", 6: "ZERO", 7: "DISCARD", 8: "REPLACE_XZ"}

class Payload:
    def __init__(self, path):
        if zipfile.is_zipfile(path):
            zf = zipfile.ZipFile(path)
            info = zf.getinfo("payload.bin")
            assert info.compress_type == zipfile.ZIP_STORED, "payload.bin compresso nello zip"
            with open(path, "rb") as f:
                f.seek(info.header_offset + 26)
                n, e = struct.unpack("<HH", f.read(4))
            self.base = info.header_offset + 30 + n + e
        else:
            self.base = 0
        self.f = open(path, "rb")
        self.f.seek(self.base)
        hdr = self.f.read(24)
        magic, ver, msize = hdr[:4], *struct.unpack(">QQ", hdr[4:20])
        assert magic == b"CrAU", "magic payload errato: %r" % magic
        sigsize = struct.unpack(">I", hdr[20:24])[0] if ver >= 2 else 0
        hlen = 24 if ver >= 2 else 20
        self.f.seek(self.base + hlen)
        self.manifest = fields(self.f.read(msize))
        self.data_off = self.base + hlen + msize + sigsize
        self.block = first(self.manifest, 3, 4096)
        self.parts = []
        for f, v in self.manifest:
            if f == 13:
                pl = fields(v)
                name = first(pl, 1).decode()
                info = fields(first(pl, 7, b""))
                ops = [fields(o) for f2, o in pl if f2 == 8]
                self.parts.append((name, first(info, 1, 0), first(info, 2, b""), ops))

    def extract(self, name, size, digest, ops, outdir):
        out = os.path.join(outdir, name + ".img")
        h = hashlib.sha256()
        with open(out, "wb") as o:
            o.truncate(size)
            for op in ops:
                t = first(op, 1, 0)
                if t not in OPS:
                    raise RuntimeError("%s: operazione %d non supportata (OTA incrementale?)" % (name, t))
                exts = [fields(e) for f, e in op if f == 6]
                if t in (6, 7):
                    data = None
                else:
                    self.f.seek(self.data_off + first(op, 2, 0))
                    raw = self.f.read(first(op, 3, 0))
                    want = first(op, 8)
                    if want and hashlib.sha256(raw).digest() != want:
                        raise RuntimeError("%s: hash di un blocco ERRATO (file corrotto?)" % name)
                    data = raw if t == 0 else bz2.decompress(raw) if t == 1 else lzma.decompress(raw)
                pos = 0
                for e in exts:
                    start, nb = first(e, 1, 0), first(e, 2, 0)
                    o.seek(start * self.block)
                    ln = nb * self.block
                    o.write(data[pos:pos + ln] if data is not None else b"\0" * ln)
                    pos += ln
        with open(out, "rb") as i:
            for chunk in iter(lambda: i.read(1 << 20), b""):
                h.update(chunk)
        ok = (not digest) or h.digest() == digest
        print("%-16s %10d byte  sha256 %s" % (name, size, "OK" if ok else "ERRATO!"))
        if not ok:
            raise RuntimeError("%s: hash immagine finale errato" % name)

def main():
    p = Payload(sys.argv[1])
    if sys.argv[2] == "list":
        for name, size, _, ops in p.parts:
            print("%-16s %10d byte  %4d operazioni" % (name, size, len(ops)))
    elif sys.argv[2] == "extract":
        outdir = sys.argv[3]; want = set(sys.argv[4:])
        os.makedirs(outdir, exist_ok=True)
        for name, size, digest, ops in p.parts:
            if not want or name in want:
                p.extract(name, size, digest, ops, outdir)

if __name__ == "__main__":
    main()
