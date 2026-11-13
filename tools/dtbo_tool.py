#!/usr/bin/env python3
"""Lettura/creazione di immagini dtbo (Android DT table, magic 0xd7b7ab1e).
  dtbo_tool.py dump <dtbo.img>
  dtbo_tool.py create <out.img> <page_size> <overlay.dtbo> [altri .dtbo...]
"""
import struct, sys
MAGIC = 0xd7b7ab1e
HDR = ">8I"     # magic,total_size,header_size,dt_entry_size,dt_entry_count,dt_entries_offset,page_size,version
ENT = ">8I"     # dt_size,dt_offset,id,rev,custom0..3

def fdt_props(blob, names):
    """Cerca alcune proprietà (es. qcom,msm-id) nel nodo radice di un FDT, restituisce i valori u32."""
    off_struct, off_strings = struct.unpack(">II", blob[8:16])
    out = {}; p = off_struct; depth = 0
    while p < len(blob):
        tok = struct.unpack(">I", blob[p:p+4])[0]; p += 4
        if tok == 1:   # BEGIN_NODE
            e = blob.index(b"\0", p); p = (e + 4) & ~3; depth += 1
        elif tok == 2: # END_NODE
            depth -= 1
            if depth == 0: break
        elif tok == 3: # PROP
            ln, no = struct.unpack(">II", blob[p:p+8]); p += 8
            n = blob[off_strings+no: blob.index(b"\0", off_strings+no)].decode()
            if depth == 1 and n in names:
                out[n] = [hex(x) for x in struct.unpack(">%dI" % (ln//4), blob[p:p+ln - ln % 4])] if ln % 4 == 0 else blob[p:p+ln]
            p = (p + ln + 3) & ~3
        elif tok in (4, 9): # NOP / END
            if tok == 9: break
    return out

def dump(path):
    b = open(path, "rb").read()
    h = struct.unpack(HDR, b[:32])
    assert h[0] == MAGIC, "magic errato"
    print("total_size=%d entries=%d page_size=%d version=%d" % (h[1], h[4], h[6], h[7]))
    for i in range(h[4]):
        e = struct.unpack(ENT, b[h[5]+i*h[3]: h[5]+i*h[3]+32])
        blob = b[e[1]:e[1]+e[0]]
        props = fdt_props(blob, {"model", "qcom,msm-id", "qcom,board-id", "compatible"})
        model = props.get("model", b"").rstrip(b"\0").decode(errors="replace") if isinstance(props.get("model"), bytes) else props.get("model")
        print(" [%d] size=%d id=%#x rev=%#x custom=%s model=%s msm-id=%s board-id=%s" % (
            i, e[0], e[2], e[3], [hex(x) for x in e[4:]], model, props.get("qcom,msm-id"), props.get("qcom,board-id")))

def create(out, page_size, files):
    blobs = [open(f, "rb").read() for f in files]
    for f, bl in zip(files, blobs):
        assert struct.unpack(">I", bl[:4])[0] == 0xd00dfeed, f + " non è un FDT"
    n = len(blobs); off = 32 + 32 * n
    ents = b""; data = b""
    for bl in blobs:
        ents += struct.pack(ENT, len(bl), off + len(data), 0, 0, 0, 0, 0, 0)
        data += bl
    total = off + len(data)
    img = struct.pack(HDR, MAGIC, total, 32, 32, n, 32, page_size, 0) + ents + data
    open(out, "wb").write(img)
    print("scritto %s: %d byte, %d entry" % (out, len(img), n))

if __name__ == "__main__":
    if sys.argv[1] == "dump": dump(sys.argv[2])
    elif sys.argv[1] == "create": create(sys.argv[2], int(sys.argv[3]), sys.argv[4:])
