#!/usr/bin/env python3
"""Converte un'immagine raw in N file Android sparse, ciascuno <= LIMITE byte.
Ogni file copre l'intera immagine (le parti non sue sono DONT_CARE), quindi si flashano
in sequenza con `fastboot flash <partizione> <file>` senza altri strumenti sul PC.
uso: sparse_chunks.py IMMAGINE.raw PREFISSO [LIMITE_MB=256]   ->  PREFISSO.01.img, PREFISSO.02.img, ...
"""
import struct, sys
BS = 4096
RAW, DONT_CARE = 0xCAC1, 0xCAC3

def runs(f, total):
    """(is_data, blocco_iniziale, n_blocchi) per tratti consecutivi; legge a pezzi da 1 MiB."""
    zero = bytes(BS); start = 0; cur = None; n = 0; blk = 0
    while blk < total:
        buf = f.read(BS * 256)
        if not buf: buf = bytes(BS * min(256, total - blk))
        for o in range(0, len(buf), BS):
            b = buf[o:o + BS]
            if len(b) < BS: b = b + bytes(BS - len(b))
            d = b != zero
            if d != cur:
                if n: yield cur, start, n
                cur, start, n = d, blk, 0
            n += 1; blk += 1
    if n: yield cur, start, n

def main():
    src, prefix = sys.argv[1], sys.argv[2]
    limit = int(sys.argv[3]) * 1024 * 1024 if len(sys.argv) > 3 else 256 * 1024 * 1024
    import os
    size = os.path.getsize(src); assert size % BS == 0, "dimensione non multipla di 4096"
    total = size // BS
    max_data = (limit - 4096) // BS            # blocchi di dati per file (margine per le intestazioni)
    # elenco dei tratti di dati, spezzati perche' stiano in un file
    parts = [[]]; used = 0
    with open(src, "rb") as f:
        for d, st, n in runs(f, total):
            if not d: continue
            while n:
                if used == max_data: parts.append([]); used = 0
                k = min(n, max_data - used)
                parts[-1].append((st, k)); used += k; st += k; n -= k
    names = []
    with open(src, "rb") as f:
        for i, segs in enumerate(parts, 1):
            name = "%s.%02d.img" % (prefix, i); names.append(name)
            chunks = []; pos = 0
            for st, k in segs:
                if st > pos: chunks.append((DONT_CARE, st - pos, None))
                chunks.append((RAW, k, st)); pos = st + k
            if pos < total: chunks.append((DONT_CARE, total - pos, None))
            with open(name, "wb") as o:
                o.write(struct.pack("<IHHHHIIII", 0xED26FF3A, 1, 0, 28, 12, BS, total, len(chunks), 0))
                for t, k, st in chunks:
                    o.write(struct.pack("<HHII", t, 0, k, 12 + (k * BS if t == RAW else 0)))
                    if t == RAW:
                        f.seek(st * BS); left = k * BS
                        while left:
                            b = f.read(min(left, 1 << 22)); o.write(b); left -= len(b)
            print("%s  %d MB" % (name, os.path.getsize(name) >> 20))
    return names

if __name__ == "__main__":
    main()
