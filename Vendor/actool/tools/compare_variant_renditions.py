#!/usr/bin/env python3
"""Decode and compare the *stored* sized renditions of two .car files directly,
bypassing CUICatalog's recompose.

For variant-axis `.icon` bundles (feishin, scrumdinger) the sized renditions are
KCBC (chunked-LZFSE) grayscale GA8/GA16; `extract_pixels` (CUICatalog) returns a
*recomposed* image, which makes a direct ours-vs-Apple comparison impossible.
This tool walks the BOM, finds each bitmap rendition, LZFSE-decodes its KCBC
payload, and reports per-rendition luma diffs — matching renditions by
(point-size, scale, pixel-format/variant), not by name (Apple's names carry
random UUIDs).

Usage: compare_variant_renditions.py <apple.car> <ours.car>
"""
import ctypes, os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from compare_car import _read_bom, _walk_tree, _parse_csi  # noqa: E402

# ---- LZFSE via macOS libcompression ----
_lib = ctypes.CDLL("/usr/lib/libcompression.dylib")
_lib.compression_decode_buffer.restype = ctypes.c_size_t
_lib.compression_decode_buffer.argtypes = [
    ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_size_t,
    ctypes.c_void_p, ctypes.c_int,
]
COMPRESSION_LZFSE = 0x801


def lzfse_decode(src: bytes, max_out: int) -> bytes:
    dst = ctypes.create_string_buffer(max_out)
    n = _lib.compression_decode_buffer(dst, max_out, src, len(src), None,
                                       COMPRESSION_LZFSE)
    return dst.raw[:n]


def decode_kcbc(rend_raw: bytes, width: int, height: int):
    """Decode an MLEC/KCBC rendition payload to raw interleaved pixel bytes."""
    if rend_raw[:4] != b"MLEC" or rend_raw[16:20] != b"KCBC":
        return None
    data = rend_raw[20:]
    out = bytearray()
    pos = 0
    rows_total = 0
    while pos + 16 <= len(data):
        _z1, _z2, rows, clen = struct.unpack_from("<IIII", data, pos)
        pos += 16
        comp = data[pos:pos + clen]
        pos += clen
        # generous upper bound; libcompression returns the real length
        raw = lzfse_decode(comp, rows * width * 4 + 64)
        out += raw
        rows_total += rows
        if data[pos:pos + 4] == b"KCBC":
            pos += 4
    if rows_total == 0:
        return None
    bpr = len(out) // rows_total
    return bytes(out), bpr


def gray_image(rend, data, bpr):
    """Return (gray 0..255, alpha 0..255) from decoded GA8/GA16/BGRA."""
    import numpy as np
    w, h = rend["width"], rend["height"]
    pf = rend["pixel_format"]
    arr = np.frombuffer(data, np.uint8)
    rows = arr[: h * bpr].reshape(h, bpr)
    if pf == b" 8AG":          # GA8: 2 bytes/px (gray, alpha)
        px = rows[:, : w * 2].reshape(h, w, 2)
        return px[:, :, 0].astype(int), px[:, :, 1].astype(int)
    if pf == b"61AG":          # GA16: 4 bytes/px (gray16, alpha16) little-endian
        px = rows[:, : w * 4].reshape(h, w, 4)
        return px[:, :, 1].astype(int), px[:, :, 3].astype(int)  # high bytes
    if pf == b"BGRA":          # 4 bytes/px premultiplied BGRA
        px = rows[:, : w * 4].reshape(h, w, 4).astype(int)
        b, g, r, al = px[:, :, 0], px[:, :, 1], px[:, :, 2], px[:, :, 3]
        return (0.114 * b + 0.587 * g + 0.299 * r).astype(int), al
    return None, None


def renditions(car_path):
    data = open(car_path, "rb").read()
    _blocks, named, read_block = _read_bom(data)
    out = []
    if "RENDITIONS" not in named:
        return out
    tree = read_block(named["RENDITIONS"])
    root = struct.unpack(">I", tree[8:12])[0]
    for _key, val in _walk_tree(read_block, root):
        csi = _parse_csi(val)
        if not csi:
            continue
        celm = csi.get("celm")
        if not celm or csi["pixel_format"] not in (b" 8AG", b"61AG", b"BGRA"):
            continue
        if csi["rend_raw"][:4] != b"MLEC" or csi["rend_raw"][16:20] != b"KCBC":
            continue  # only KCBC renditions are decodable here
        if "ZZZZ" in csi["name"] or csi["layout"] == 1004:
            continue  # skip packed atlases (different arrangement, not 1:1)
        out.append(csi)
    return out


def key(r):
    pt = r["width"] // max(1, r["scale"])
    return (pt, r["scale"], r["pixel_format"], r["colorspace_id"])


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    import numpy as np
    a = {key(r): r for r in renditions(sys.argv[1])}
    o = {key(r): r for r in renditions(sys.argv[2])}
    variant = {2: "light", 6: "dark"}
    print(f"{'pt':>5} {'scale':>5} {'fmt':>5} {'variant':>7}  {'mean':>6} {'max':>5}  note")
    keys = sorted(set(a) | set(o), key=lambda k: (k[0], k[1], k[3]))
    diffs = []
    for k in keys:
        pfn = {b" 8AG": "GA8", b"61AG": "GA16", b"BGRA": "BGRA"}.get(k[2], str(k[2]))
        var = variant.get(k[3], f"cs{k[3]}")
        head = f"{k[0]:>5} {k[1]:>5} {pfn:>5} {var:>7}"
        ra, ro = a.get(k), o.get(k)
        if not ra or not ro:
            print(f"{head}  {'':>6} {'':>5}  {'apple-only' if ra else 'ours-only'}")
            continue
        da, do = decode_kcbc(ra["rend_raw"], *([ra['width'], ra['height']])), \
            decode_kcbc(ro["rend_raw"], ro["width"], ro["height"])
        if not da or not do:
            print(f"{head}  decode-failed"); continue
        ga, aa = gray_image(ra, da[0], da[1])
        go, ao = gray_image(ro, do[0], do[1])
        if ga is None or go is None or ga.shape != go.shape:
            print(f"{head}  shape mismatch"); continue
        # compare gray only where both renditions are opaque (ignore margin)
        m = (aa > 16) & (ao > 16)
        d = np.abs(ga - go)[m]
        if d.size == 0:
            print(f"{head}  (empty)"); continue
        diffs.append(d.mean())
        print(f"{head}  {d.mean():>6.1f} {int(d.max()):>5}")
    if diffs:
        print(f"\n{len(diffs)} matched renditions, overall mean luma diff: "
              f"{sum(diffs)/len(diffs):.1f}")


if __name__ == "__main__":
    main()
