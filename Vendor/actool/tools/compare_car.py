#!/usr/bin/env python3
"""Compare two .car (compiled asset catalog) files in depth.

Reports structural differences, metadata mismatches, compression format
differences, and pixel-level image discrepancies.

Usage:
    python tools/compare_car.py <a.car> <b.car> [options]

Options:
    --pixel-threshold N   Max per-channel diff to consider a match (default: 0)
    --summary             Only print the summary, skip per-entry details
    --json                Output machine-readable JSON instead of text
    --quiet               Only print failures and the summary line
"""

import argparse
import json
import math
import os
import struct
import subprocess
import sys

# ---------------------------------------------------------------------------
# BOM / CAR low-level parser
# ---------------------------------------------------------------------------

def _read_bom(data: bytes):
    """Parse BOM container. Returns (blocks dict, named dict, read_block fn)."""
    if data[:8] != b"BOMStore":
        raise ValueError("not a BOMStore file")

    idx_off = struct.unpack('>I', data[16:20])[0]
    idx_len = struct.unpack('>I', data[20:24])[0]
    idx_data = data[idx_off:idx_off + idx_len]
    n = struct.unpack('>I', idx_data[:4])[0]
    blocks = {}
    for i in range(n):
        addr = struct.unpack('>I', idx_data[4 + i * 8:8 + i * 8])[0]
        length = struct.unpack('>I', idx_data[8 + i * 8:12 + i * 8])[0]
        if addr or length:
            blocks[i] = (addr, length)

    def read_block(idx):
        if idx not in blocks:
            return b''
        off, ln = blocks[idx]
        return data[off:off + ln]

    vars_off, vars_ln = struct.unpack('>II', data[24:32])
    vd = data[vars_off:vars_off + vars_ln]
    nv = struct.unpack('>I', vd[:4])[0]
    named = {}
    p = 4
    for _ in range(nv):
        bi = struct.unpack('>I', vd[p:p + 4])[0]
        nl = vd[p + 4]
        nm = vd[p + 5:p + 5 + nl].decode('ascii')
        p += 5 + nl
        named[nm] = bi

    return blocks, named, read_block


def _walk_tree(read_block, root_idx):
    """Walk a BOM tree and yield (key_bytes, value_bytes) for every leaf."""
    def recurse(block_idx):
        nd = read_block(block_idx)
        if len(nd) < 12:
            return
        is_leaf = struct.unpack('>H', nd[:2])[0]
        cnt = struct.unpack('>H', nd[2:4])[0]
        if is_leaf:
            pos = 12
            for _ in range(cnt):
                vi = struct.unpack('>I', nd[pos:pos + 4])[0]
                ki = struct.unpack('>I', nd[pos + 4:pos + 8])[0]
                pos += 8
                yield (read_block(ki), read_block(vi))
        else:
            pos = 12
            c0 = struct.unpack('>I', nd[pos:pos + 4])[0]
            pos += 4
            yield from recurse(c0)
            for _ in range(cnt):
                pos += 4
                c = struct.unpack('>I', nd[pos:pos + 4])[0]
                pos += 4
                yield from recurse(c)

    yield from recurse(root_idx)


# ---------------------------------------------------------------------------
# CSI parsing
# ---------------------------------------------------------------------------

LAYOUT_NAMES = {
    12: "inline",
    1000: "rawdata",
    1003: "packed_ref",
    1004: "packed_atlas",
    1005: "sprite_meta",
    1009: "color",
    1010: "multisize",
    1019: "iconstack",
    1020: "icon_group",
    1021: "gradient",
}

TLV_NAMES = {
    0x03E9: "Slices",
    0x03EB: "Metrics",
    0x03EC: "Blend",
    0x03EE: "EXIF",
    0x03EF: "BytesPerRow",
    0x03F2: "INLK",
    0x03F5: "SpriteAtlas",
}


def _parse_csi(vd: bytes) -> dict | None:
    """Parse a CSI block (rendition value from the RENDITIONS tree)."""
    if len(vd) < 184 or vd[:4] != b"ISTC":
        return None

    flags = struct.unpack('<I', vd[8:12])[0]
    width = struct.unpack('<I', vd[12:16])[0]
    height = struct.unpack('<I', vd[16:20])[0]
    scale_factor = struct.unpack('<I', vd[20:24])[0]
    pixel_format = bytes(vd[24:28])
    colorspace_id = struct.unpack('<I', vd[28:32])[0] & 0xF
    layout = struct.unpack('<H', vd[36:38])[0]
    name = vd[40:168].rstrip(b'\x00').decode('ascii', errors='replace')
    tlv_len = struct.unpack('<I', vd[168:172])[0]
    bitmaplist_unk = struct.unpack('<I', vd[172:176])[0]
    rend_len = struct.unpack('<I', vd[180:184])[0]

    tlv_raw = bytes(vd[184:184 + tlv_len])
    rend_raw = bytes(vd[184 + tlv_len:184 + tlv_len + rend_len])

    # Parse TLV entries
    tlvs = {}
    p = 0
    while p + 8 <= len(tlv_raw):
        tag = struct.unpack('<I', tlv_raw[p:p + 4])[0]
        tl = struct.unpack('<I', tlv_raw[p + 4:p + 8])[0]
        tlvs[tag] = bytes(tlv_raw[p + 8:p + 8 + tl])
        p += 8 + tl

    # Parse CELM if present
    celm = None
    if rend_len >= 16 and rend_raw[:4] == b"MLEC":
        c_ver, c_comp, c_payload = struct.unpack_from('<III', rend_raw, 4)
        celm = {"ver": c_ver, "comp": c_comp, "payload_len": c_payload}
        # Check for DMP2 sub-header vs inline
        payload = rend_raw[16:]
        if c_comp == 11 and payload[:4] == b'dmp2':
            celm["dmp2_inline"] = True
        elif c_comp == 11 and len(payload) >= 16:
            sub_ver, sub_fmt, sub_len, sub_zero = struct.unpack_from(
                '<IIII', payload, 0)
            if sub_ver == 1 and sub_fmt in (2, 4):
                celm["dmp2_inline"] = False
                celm["dmp2_sub_fmt"] = sub_fmt

    # Decode opaque / bitmap encoding from flags
    is_opaque = bool(flags & 0x02)
    bitmap_enc = (flags >> 2) & 0xF

    # Parse INLK if present
    inlk = None
    if 0x03F2 in tlvs:
        inlk_data = tlvs[0x03F2]
        if len(inlk_data) >= 28 and inlk_data[:4] == b'KLNI':
            ix = struct.unpack_from('<I', inlk_data, 8)[0]
            iy = struct.unpack_from('<I', inlk_data, 12)[0]
            iw = struct.unpack_from('<I', inlk_data, 16)[0]
            ih = struct.unpack_from('<I', inlk_data, 20)[0]
            f1 = struct.unpack_from('<H', inlk_data, 24)[0]
            f2 = struct.unpack_from('<H', inlk_data, 26)[0]
            # Parse attributes
            attrs = {}
            ap = 30  # skip 2 bytes padding at offset 28
            while ap + 4 <= 28 + f2:
                a_id = struct.unpack_from('<H', inlk_data, ap)[0]
                a_val = struct.unpack_from('<H', inlk_data, ap + 2)[0]
                if a_id == 0:
                    break
                attrs[a_id] = a_val
                ap += 4
            inlk = {"x": ix, "y": iy, "w": iw, "h": ih,
                     "f1": f1, "f2": f2, "attrs": attrs}

    # Parse color data
    color = None
    if layout == 1009 and rend_len >= 16 and rend_raw[:4] == b"RLOC":
        c_ver = struct.unpack_from('<I', rend_raw, 4)[0]
        c_cs = struct.unpack_from('<I', rend_raw, 8)[0]
        c_cnt = struct.unpack_from('<I', rend_raw, 12)[0]
        if rend_len >= 16 + c_cnt * 8:
            comps = struct.unpack_from(f'<{c_cnt}d', rend_raw, 16)
            color = {"colorspace": c_cs, "components": comps}

    # Bytes per row
    bpr = None
    if 0x03EF in tlvs and len(tlvs[0x03EF]) >= 4:
        bpr = struct.unpack_from('<I', tlvs[0x03EF], 0)[0]

    # Slices TLV: count, x, y, w, h
    slices = None
    if 0x03E9 in tlvs and len(tlvs[0x03E9]) >= 20:
        sd = tlvs[0x03E9]
        slices = struct.unpack_from('<IIIII', sd, 0)

    # Metrics TLV: count, top, left, bottom, right, w, h
    metrics = None
    if 0x03EB in tlvs and len(tlvs[0x03EB]) >= 28:
        md = tlvs[0x03EB]
        metrics = struct.unpack_from('<IIIIIII', md, 0)

    # Blend TLV: mode, opacity
    blend = None
    if 0x03EC in tlvs and len(tlvs[0x03EC]) >= 8:
        bd = tlvs[0x03EC]
        blend = (struct.unpack_from('<I', bd, 0)[0],
                 struct.unpack_from('<f', bd, 4)[0])

    # Multisize image data (MSIS)
    multisize = None
    if layout == 1010 and rend_len >= 12 and rend_raw[:4] == b"SISM":
        ms_ver = struct.unpack_from('<I', rend_raw, 4)[0]
        ms_count = struct.unpack_from('<I', rend_raw, 8)[0]
        ms_entries = []
        for i in range(ms_count):
            off = 12 + i * 12
            if off + 12 <= rend_len:
                mw, mh, midx = struct.unpack_from('<III', rend_raw, off)
                ms_entries.append((mw, mh, midx))
        multisize = {"version": ms_ver, "entries": ms_entries}

    return {
        "name": name,
        "width": width,
        "height": height,
        "scale": scale_factor // 100,
        "pixel_format": pixel_format,
        "colorspace_id": colorspace_id,
        "layout": layout,
        "layout_name": LAYOUT_NAMES.get(layout, f"unknown({layout})"),
        "flags": flags,
        "is_opaque": is_opaque,
        "bitmap_enc": bitmap_enc,
        "tlv_len": tlv_len,
        "tlv_tags": sorted(tlvs.keys()),
        "bitmaplist_unk": bitmaplist_unk,
        "rend_len": rend_len,
        "rend_raw": rend_raw,
        "celm": celm,
        "inlk": inlk,
        "color": color,
        "bpr": bpr,
        "slices": slices,
        "metrics": metrics,
        "blend": blend,
        "multisize": multisize,
    }


# ---------------------------------------------------------------------------
# Parse a full .car into a structured representation
# ---------------------------------------------------------------------------

def _parse_keyformat(read_block, named):
    """Parse KEYFORMAT and return list of token IDs."""
    if "KEYFORMAT" not in named:
        return []
    kf = read_block(named["KEYFORMAT"])
    if len(kf) < 12 or kf[:4] != b"tmfk":
        return []
    count = struct.unpack_from('<I', kf, 8)[0]
    return [struct.unpack_from('<I', kf, 12 + i * 4)[0]
            for i in range(count)]


def _parse_carheader(read_block, named):
    """Parse CARHEADER block."""
    if "CARHEADER" not in named:
        return {}
    hdr = read_block(named["CARHEADER"])
    if len(hdr) < 436 or hdr[:4] != b"RATC":
        return {}
    return {
        "coreuiVersion": struct.unpack_from('<I', hdr, 4)[0],
        "storageVersion": struct.unpack_from('<I', hdr, 8)[0],
        "renditionCount": struct.unpack_from('<I', hdr, 16)[0],
        "mainVersionString": hdr[20:148].rstrip(b'\x00').decode(
            'ascii', errors='replace'),
        "versionString": hdr[148:404].rstrip(b'\x00').decode(
            'ascii', errors='replace'),
        "schemaVersion": struct.unpack_from('<I', hdr, 424)[0],
        "colorSpaceID": struct.unpack_from('<I', hdr, 428)[0],
        "keySemantics": struct.unpack_from('<I', hdr, 432)[0],
    }


def _parse_extended_metadata(read_block, named):
    """Parse EXTENDED_METADATA block."""
    if "EXTENDED_METADATA" not in named:
        return {}
    md = read_block(named["EXTENDED_METADATA"])
    if len(md) < 1028 or md[:4] != b"META":
        return {}
    return {
        "thinningArguments": md[4:260].rstrip(b'\x00').decode(
            'ascii', errors='replace'),
        "deploymentPlatformVersion": md[260:516].rstrip(b'\x00').decode(
            'ascii', errors='replace'),
        "deploymentPlatform": md[516:772].rstrip(b'\x00').decode(
            'ascii', errors='replace'),
        "authoringTool": md[772:1028].rstrip(b'\x00').decode(
            'ascii', errors='replace'),
    }


def _parse_facetkeys(read_block, named):
    """Parse FACETKEYS tree → {name: {element, part, identifier}}."""
    if "FACETKEYS" not in named:
        return {}
    tree = read_block(named["FACETKEYS"])
    if len(tree) < 12:
        return {}
    root = struct.unpack('>I', tree[8:12])[0]
    facets = {}
    for key_bytes, val_bytes in _walk_tree(read_block, root):
        name = key_bytes.rstrip(b'\x00').decode('ascii', errors='replace')
        if len(val_bytes) < 6:
            continue
        n_attrs = struct.unpack_from('<H', val_bytes, 4)[0]
        attrs = {}
        for i in range(n_attrs):
            off = 6 + i * 4
            if off + 4 > len(val_bytes):
                break
            tok = struct.unpack_from('<H', val_bytes, off)[0]
            val = struct.unpack_from('<H', val_bytes, off + 2)[0]
            attrs[tok] = val
        facets[name] = attrs
    return facets


def _parse_tree_header(read_block, named, name):
    """Return the 29-byte tree-header fields for a named BOM tree.

    These fields gate CUICatalog behavior in subtle ways that aren't
    caught by walking the tree logically — e.g. `key_size` controls
    whether CUICatalog expects an inline-key region after each leaf's
    entry table.
    """
    if name not in named:
        return None
    raw = read_block(named[name])
    if len(raw) < 29 or raw[:4] != b"tree":
        return None
    return {
        "child_block": struct.unpack('>I', raw[8:12])[0],
        "block_size": struct.unpack('>I', raw[12:16])[0],
        "path_count": struct.unpack('>I', raw[16:20])[0],
        "flag":       raw[20],
        "key_size":   struct.unpack('>I', raw[21:25])[0],
    }


def _audit_leaf_layout(read_block, named, name, key_size_bytes=None):
    """Audit the raw bytes of a tree's root leaf block.

    Returns a dict describing how the leaf is organized, including
    whether an inline-key region is present right after the entry
    table (the cache CUICatalog reads to enumerate per-facet
    renditions). When that region is missing or replaced by zeros,
    `imagesWithName:` silently returns empty arrays even though
    every separate key block is correct — exactly the bug that
    survived this tool's previous logical-walk comparison.

    If `key_size_bytes` is given, the inline-key region is checked
    against the per-entry key blocks referenced by the leaf entries.
    """
    if name not in named:
        return None
    tree_raw = read_block(named[name])
    if len(tree_raw) < 12 or tree_raw[:4] != b"tree":
        return None
    root_idx = struct.unpack('>I', tree_raw[8:12])[0]
    leaf = read_block(root_idx)
    if len(leaf) < 12:
        return None
    is_leaf = struct.unpack('>H', leaf[:2])[0]
    cnt = struct.unpack('>H', leaf[2:4])[0]
    if not is_leaf:
        return {"is_leaf": False, "count": cnt, "size": len(leaf)}
    entries_end = 12 + cnt * 8
    info = {
        "is_leaf": True,
        "count": cnt,
        "size": len(leaf),
        "entries_end": entries_end,
    }
    if key_size_bytes and cnt > 0:
        gap = leaf[entries_end:entries_end + 4]
        info["pre_inline_gap_bytes"] = gap.hex()
        # Apple inserts a 4-byte zero gap; the inline-key region starts
        # immediately after.
        inline_off = entries_end + 4
        expected_inline_len = cnt * key_size_bytes
        inline_region = leaf[inline_off:inline_off + expected_inline_len]
        info["inline_region_offset"] = inline_off
        info["inline_region_len"] = len(inline_region)
        info["inline_region_all_zeros"] = (inline_region == b"\x00" * len(inline_region))
        # Cross-check: reconstruct the inline blob from the entries'
        # separately-stored key blocks and compare.
        rebuilt = []
        for i in range(cnt):
            pos = 12 + i * 8
            ki = struct.unpack('>I', leaf[pos + 4:pos + 8])[0]
            key_block = read_block(ki)
            rebuilt.append(key_block)
        rebuilt_blob = b"".join(rebuilt)
        info["inline_matches_rebuilt"] = (inline_region == rebuilt_blob)
        if not info["inline_matches_rebuilt"]:
            # Try shifting by 4 bytes (no gap variant) — surfaces the
            # off-by-one we hit while reverse-engineering this layout.
            shifted = leaf[entries_end:entries_end + expected_inline_len]
            info["inline_matches_if_no_gap"] = (shifted == rebuilt_blob)
    return info


def _parse_bitmapkeys(read_block, named):
    """Walk the BITMAPKEYS raw-key tree.

    Returns {identifier(int): value_hex(str)} or None when the tree is
    absent / empty. CUICatalog uses these per-facet attribute-value
    masks during `imagesWithName:` — missing entries cause every
    lookup to return an empty array.
    """
    if "BITMAPKEYS" not in named:
        return None
    tree_raw = read_block(named["BITMAPKEYS"])
    if len(tree_raw) < 12 or tree_raw[:4] != b"tree":
        return None
    root_idx = struct.unpack('>I', tree_raw[8:12])[0]
    leaf = read_block(root_idx)
    if len(leaf) < 12:
        return None
    is_leaf, cnt = struct.unpack('>HH', leaf[:4])
    out = {}
    if is_leaf:
        for i in range(cnt):
            pos = 12 + i * 8
            vi = struct.unpack('>I', leaf[pos:pos + 4])[0]
            raw_key = struct.unpack('>I', leaf[pos + 4:pos + 8])[0]
            out[raw_key] = read_block(vi).hex()
    return out


def parse_car(path: str) -> dict:
    """Parse a .car file into a dict suitable for comparison."""
    with open(path, 'rb') as f:
        data = f.read()

    blocks, named, read_block = _read_bom(data)

    keyformat = _parse_keyformat(read_block, named)
    carheader = _parse_carheader(read_block, named)
    metadata = _parse_extended_metadata(read_block, named)
    facets = _parse_facetkeys(read_block, named)

    # Parse renditions
    renditions = []
    if "RENDITIONS" in named:
        tree = read_block(named["RENDITIONS"])
        if len(tree) >= 12:
            root = struct.unpack('>I', tree[8:12])[0]
            for key_bytes, val_bytes in _walk_tree(read_block, root):
                csi = _parse_csi(val_bytes)
                if csi is not None:
                    # Parse the rendition key using keyformat
                    key_vals = {}
                    if keyformat and key_bytes:
                        n = min(len(keyformat), len(key_bytes) // 2)
                        raw = struct.unpack_from(f'<{n}H', key_bytes, 0)
                        for i, tok in enumerate(keyformat[:n]):
                            key_vals[tok] = raw[i]
                    csi["key_attrs"] = key_vals
                    csi["key_raw"] = key_bytes.hex()
                    renditions.append(csi)

    # Parse APPEARANCEKEYS
    appearance_keys = {}
    if "APPEARANCEKEYS" in named:
        tree = read_block(named["APPEARANCEKEYS"])
        if len(tree) >= 12:
            root = struct.unpack('>I', tree[8:12])[0]
            for key_bytes, val_bytes in _walk_tree(read_block, root):
                aname = key_bytes.rstrip(b'\x00').decode('ascii',
                                                         errors='replace')
                if len(val_bytes) >= 2:
                    appearance_keys[aname] = struct.unpack_from(
                        '<H', val_bytes, 0)[0]

    # Tree header fields (block_size, child block, path count, flag,
    # key_size) — bypassed by the logical walker but read directly by
    # CUICatalog.
    tree_headers = {
        n: _parse_tree_header(read_block, named, n)
        for n in (
            "FACETKEYS",
            "APPEARANCEKEYS",
            "RENDITIONS",
            "BITMAPKEYS",
        )
        if n in named
    }

    # Audit raw leaf layout for each fixed-key tree. The inline-key
    # region is what `imagesWithName:` actually reads; if it's missing
    # or zero-filled, lookups silently return empty arrays.
    fixed_key_bytes = (len(keyformat) * 2) if keyformat else None
    leaf_audits = {
        "FACETKEYS":      _audit_leaf_layout(read_block, named, "FACETKEYS"),
        "APPEARANCEKEYS": _audit_leaf_layout(read_block, named, "APPEARANCEKEYS"),
        "RENDITIONS":     _audit_leaf_layout(read_block, named, "RENDITIONS",
                                             key_size_bytes=fixed_key_bytes),
        "BITMAPKEYS":     _audit_leaf_layout(read_block, named, "BITMAPKEYS"),
    }

    bitmap_keys = _parse_bitmapkeys(read_block, named)

    return {
        "path": path,
        "file_size": len(data),
        # Original BOM order (CUICatalog can be sensitive to this).
        "named_blocks_order": list(named.keys()),
        "named_blocks": sorted(named.keys()),
        "keyformat": keyformat,
        "carheader": carheader,
        "metadata": metadata,
        "facets": facets,
        "renditions": renditions,
        "appearance_keys": appearance_keys,
        "tree_headers": tree_headers,
        "leaf_audits": leaf_audits,
        "bitmap_keys": bitmap_keys,
    }


# ---------------------------------------------------------------------------
# Pixel extraction via CoreUI (macOS only)
# ---------------------------------------------------------------------------

_EXTRACT_PIXELS = os.path.join(os.path.dirname(__file__), "extract_pixels")


def _can_extract_pixels():
    return os.path.isfile(_EXTRACT_PIXELS) and os.access(
        _EXTRACT_PIXELS, os.X_OK)


def _extract_all_pixels(car_path: str, names: list[str]) -> dict:
    """Use extract_pixels to get RGBA data for each (name, scale).

    Returns {(name, scale): (width, height, rgba_bytes)}.
    """
    if not _can_extract_pixels():
        return {}

    import tempfile
    results = {}
    with tempfile.TemporaryDirectory(prefix="carcmp_") as tmpdir:
        for name in names:
            try:
                subprocess.run(
                    [_EXTRACT_PIXELS, car_path, name, tmpdir],
                    capture_output=True, timeout=10)
            except Exception:
                continue
            for fname in os.listdir(tmpdir):
                if not fname.endswith("x.rgba"):
                    continue
                fpath = os.path.join(tmpdir, fname)
                try:
                    with open(fpath, 'rb') as f:
                        w = struct.unpack('<I', f.read(4))[0]
                        h = struct.unpack('<I', f.read(4))[0]
                        pixels = f.read()
                    # Parse scale from filename: Name_Sx.rgba
                    scale = int(fname.rsplit("_", 1)[-1].replace("x.rgba", ""))
                    results[(name, scale)] = (w, h, pixels)
                except Exception:
                    pass
                os.unlink(fpath)
    return results


# ---------------------------------------------------------------------------
# Comparison engine
# ---------------------------------------------------------------------------

def _pixel_format_str(pf: bytes) -> str:
    """Human-readable pixel format."""
    if pf == b"BGRA":
        return "BGRA"
    if pf == b" 8AG":
        return "GA8"
    if pf == b"ATAD":
        return "DATA"
    if pf == b"\x00\x00\x00\x00":
        return "none"
    return repr(pf)


_COMP_NAMES = {
    0: "uncompressed",
    1: "rle",
    2: "zip",
    3: "lzvn",
    4: "lzfse",
    5: "jpeg-lzfse",
    6: "blurred",
    7: "astc",
    8: "palette-img",
    9: "hevc",
    10: "deepmap-lzfse",
    11: "deepmap2",
    12: "dxtc",
}


def _celm_desc(celm: dict | None) -> str:
    """Short description of compression, including CELM version.

    The CELM version matters for correctness — e.g. DMP2 with ver=0 vs
    ver=2 changes how CoreUI interprets the pixel format.
    """
    if celm is None:
        return "none"
    comp = celm.get("comp", 0)
    ver = celm.get("ver", 0)
    name = _COMP_NAMES.get(comp, f"comp={comp}")
    if ver == 0 and comp == 0:
        return name  # uncompressed ver=0 is the default
    return f"{name}/ver={ver}"


def _rendition_sort_key(r):
    """Sort renditions for stable comparison."""
    return (r["name"], r["scale"], r["layout"],
            r.get("key_raw", ""))


def _compare_pixels(pix_a, pix_b, threshold=0):
    """Compare two RGBA byte buffers.

    Returns dict with match stats, or None if sizes mismatch.
    """
    w_a, h_a, data_a = pix_a
    w_b, h_b, data_b = pix_b

    result = {
        "size_a": (w_a, h_a),
        "size_b": (w_b, h_b),
    }

    if w_a != w_b or h_a != h_b:
        result["size_match"] = False
        return result

    result["size_match"] = True
    total_pixels = w_a * h_a
    diff_pixels = 0
    max_diff = 0
    sum_sq_diff = 0.0

    n = min(len(data_a), len(data_b))
    for i in range(0, n - 3, 4):
        px_diff = 0
        for c in range(4):
            d = abs(data_a[i + c] - data_b[i + c])
            if d > px_diff:
                px_diff = d
            sum_sq_diff += d * d
        if px_diff > max_diff:
            max_diff = px_diff
        if px_diff > threshold:
            diff_pixels += 1

    result["total_pixels"] = total_pixels
    result["diff_pixels"] = diff_pixels
    result["max_channel_diff"] = max_diff
    result["psnr"] = (10 * math.log10(255 * 255 * total_pixels * 4 /
                                       max(sum_sq_diff, 1e-10))
                      if total_pixels > 0 else float('inf'))
    result["match"] = diff_pixels == 0

    return result


def compare_cars(car_a: dict, car_b: dict, *,
                 pixel_threshold: int = 0,
                 do_pixels: bool = True) -> dict:
    """Compare two parsed .car structures.

    Returns a report dict.
    """
    report = {
        "file_a": car_a["path"],
        "file_b": car_b["path"],
        "differences": [],
        "summary": {},
    }
    diffs = report["differences"]

    # --- Header / metadata ---
    for field in ("coreuiVersion", "storageVersion", "schemaVersion",
                  "colorSpaceID", "keySemantics"):
        va = car_a["carheader"].get(field)
        vb = car_b["carheader"].get(field)
        if va != vb:
            diffs.append({
                "section": "carheader",
                "field": field,
                "a": va,
                "b": vb,
            })

    # Rendition count consistency
    hdr_count_a = car_a["carheader"].get("renditionCount", 0)
    hdr_count_b = car_b["carheader"].get("renditionCount", 0)
    actual_a = len(car_a["renditions"])
    actual_b = len(car_b["renditions"])
    if hdr_count_a != actual_a:
        diffs.append({"section": "carheader", "field": "renditionCount",
                       "a": f"header={hdr_count_a} actual={actual_a}",
                       "b": f"header={hdr_count_b} actual={actual_b}"})

    for field in ("deploymentPlatform", "deploymentPlatformVersion"):
        va = car_a["metadata"].get(field)
        vb = car_b["metadata"].get(field)
        if va != vb:
            diffs.append({
                "section": "metadata",
                "field": field,
                "a": va,
                "b": vb,
            })

    # --- Keyformat ---
    if car_a["keyformat"] != car_b["keyformat"]:
        diffs.append({
            "section": "keyformat",
            "a": car_a["keyformat"],
            "b": car_b["keyformat"],
        })

    # --- Named blocks ---
    blocks_a = set(car_a["named_blocks"])
    blocks_b = set(car_b["named_blocks"])
    if blocks_a != blocks_b:
        diffs.append({
            "section": "named_blocks",
            "only_a": sorted(blocks_a - blocks_b),
            "only_b": sorted(blocks_b - blocks_a),
        })
    # CUICatalog scans blocks in BOM order; order divergence is sometimes
    # behaviorally significant. Report when ORDER differs but membership
    # is the same.
    order_a = car_a.get("named_blocks_order", [])
    order_b = car_b.get("named_blocks_order", [])
    if blocks_a == blocks_b and order_a != order_b:
        diffs.append({
            "section": "named_blocks",
            "field": "order",
            "a": order_a,
            "b": order_b,
        })

    # --- Tree headers (block_size, key_size flag) ---
    th_a = car_a.get("tree_headers", {})
    th_b = car_b.get("tree_headers", {})
    for tname in sorted(set(th_a) | set(th_b)):
        ha = th_a.get(tname)
        hb = th_b.get(tname)
        if ha is None or hb is None:
            continue
        for field in ("block_size", "path_count", "flag", "key_size"):
            # `child_block` legitimately differs between any two BOM
            # files because block numbering depends on emission order.
            if ha.get(field) != hb.get(field):
                diffs.append({
                    "section": "tree_header",
                    "tree": tname,
                    "field": field,
                    "a": ha.get(field),
                    "b": hb.get(field),
                })

    # --- Leaf physical layout / inline-key region ---
    la_a = car_a.get("leaf_audits", {}) or {}
    la_b = car_b.get("leaf_audits", {}) or {}
    for tname in sorted(set(la_a) | set(la_b)):
        ia = la_a.get(tname)
        ib = la_b.get(tname)
        if not ia or not ib:
            continue
        # Different leaf SIZE for trees that should have matching
        # leaves is a strong signal something is wrong.
        if ia.get("size") != ib.get("size"):
            diffs.append({
                "section": "leaf_layout",
                "tree": tname,
                "field": "leaf_size",
                "a": ia.get("size"),
                "b": ib.get("size"),
            })
        # Inline-key region health checks — these surface the silent
        # CUICatalog-lookup-failure mode that walking the tree
        # logically (via `_walk_tree`) never sees.
        for field in ("inline_matches_rebuilt",
                       "inline_region_all_zeros",
                       "pre_inline_gap_bytes",
                       "inline_matches_if_no_gap"):
            va = ia.get(field)
            vb = ib.get(field)
            if va != vb:
                diffs.append({
                    "section": "leaf_inline_keys",
                    "tree": tname,
                    "field": field,
                    "a": va,
                    "b": vb,
                })

    # --- BITMAPKEYS contents ---
    bk_a = car_a.get("bitmap_keys")
    bk_b = car_b.get("bitmap_keys")
    if bk_a is None and bk_b is None:
        pass  # both absent
    elif bk_a is None or bk_b is None:
        diffs.append({
            "section": "bitmap_keys",
            "field": "presence",
            "a": "absent" if bk_a is None else f"{len(bk_a)} entries",
            "b": "absent" if bk_b is None else f"{len(bk_b)} entries",
        })
    else:
        keys_a = set(bk_a)
        keys_b = set(bk_b)
        if keys_a != keys_b:
            diffs.append({
                "section": "bitmap_keys",
                "field": "identifiers",
                "only_a": sorted(keys_a - keys_b),
                "only_b": sorted(keys_b - keys_a),
            })
        for k in sorted(keys_a & keys_b):
            if bk_a[k] != bk_b[k]:
                diffs.append({
                    "section": "bitmap_keys",
                    "field": f"value@{k}",
                    "a": bk_a[k],
                    "b": bk_b[k],
                })

    # --- Appearance keys ---
    ak_a = car_a.get("appearance_keys", {})
    ak_b = car_b.get("appearance_keys", {})
    if ak_a != ak_b:
        diffs.append({
            "section": "appearance_keys",
            "a": ak_a,
            "b": ak_b,
        })

    # --- Facets ---
    facets_a = car_a["facets"]
    facets_b = car_b["facets"]
    only_a_facets = sorted(set(facets_a) - set(facets_b))
    only_b_facets = sorted(set(facets_b) - set(facets_a))
    if only_a_facets or only_b_facets:
        diffs.append({
            "section": "facets",
            "only_a": only_a_facets,
            "only_b": only_b_facets,
        })
    for name in sorted(set(facets_a) & set(facets_b)):
        if facets_a[name] != facets_b[name]:
            diffs.append({
                "section": "facets",
                "name": name,
                "a": facets_a[name],
                "b": facets_b[name],
            })

    # --- Renditions ---
    # Group renditions by a comparison key: (name, scale, layout)
    # For packed atlases, also distinguish by key_raw since names can collide
    def rend_group_key(r):
        if r["layout"] in (1004, 1005):
            return (r["name"], r["scale"], r["layout"], r.get("key_raw", ""))
        return (r["name"], r["scale"], r["layout"], "")

    rends_a = {}
    for r in sorted(car_a["renditions"], key=_rendition_sort_key):
        k = rend_group_key(r)
        rends_a.setdefault(k, []).append(r)

    rends_b = {}
    for r in sorted(car_b["renditions"], key=_rendition_sort_key):
        k = rend_group_key(r)
        rends_b.setdefault(k, []).append(r)

    all_keys = sorted(set(rends_a) | set(rends_b))
    only_a_rends = sorted(k for k in all_keys if k not in rends_b)
    only_b_rends = sorted(k for k in all_keys if k not in rends_a)

    if only_a_rends:
        diffs.append({
            "section": "renditions",
            "type": "only_in_a",
            "entries": [{"name": k[0], "scale": k[1],
                         "layout": LAYOUT_NAMES.get(k[2], str(k[2]))}
                        for k in only_a_rends],
        })
    if only_b_rends:
        diffs.append({
            "section": "renditions",
            "type": "only_in_b",
            "entries": [{"name": k[0], "scale": k[1],
                         "layout": LAYOUT_NAMES.get(k[2], str(k[2]))}
                        for k in only_b_rends],
        })

    # Compare matched renditions
    rend_match_count = 0
    rend_diff_count = 0
    rend_diffs = []

    for k in sorted(set(rends_a) & set(rends_b)):
        list_a = rends_a[k]
        list_b = rends_b[k]
        # Compare pairwise (usually 1:1)
        for idx in range(max(len(list_a), len(list_b))):
            ra = list_a[idx] if idx < len(list_a) else None
            rb = list_b[idx] if idx < len(list_b) else None
            if ra is None or rb is None:
                rend_diffs.append({
                    "name": k[0],
                    "scale": k[1],
                    "issue": "count_mismatch",
                    "count_a": len(list_a),
                    "count_b": len(list_b),
                })
                rend_diff_count += 1
                continue

            entry_diffs = _compare_rendition(ra, rb)
            if entry_diffs:
                rend_diffs.append({
                    "name": ra["name"],
                    "scale": ra["scale"],
                    "layout": ra["layout_name"],
                    "issues": entry_diffs,
                })
                rend_diff_count += 1
            else:
                rend_match_count += 1

    if rend_diffs:
        diffs.append({
            "section": "renditions",
            "type": "mismatches",
            "entries": rend_diffs,
        })

    # --- Pixel comparison ---
    pixel_results = {}
    if do_pixels and _can_extract_pixels():
        # Use facet names (the actual user-facing asset names) for pixel
        # comparison, filtering out internal entries like packed atlas
        # textures, CoreStructuredImage, and app icons (multisize images
        # whose pixel extraction returns atlas data, not the rendered icon).
        exclude = {"CoreStructuredImage"}
        # Find names associated with multisize renditions (app icons)
        for r in car_a["renditions"] + car_b["renditions"]:
            if r["layout"] == 1010:  # multisize
                base = r["name"].split(".")[0].split("@")[0]
                exclude.add(base)
        common_names = sorted(
            set(car_a["facets"]) & set(car_b["facets"]) - exclude
        )

        if common_names:
            pix_a = _extract_all_pixels(car_a["path"], common_names)
            pix_b = _extract_all_pixels(car_b["path"], common_names)

            for name in common_names:
                for scale in (1, 2):
                    key = (name, scale)
                    if key in pix_a and key in pix_b:
                        cmp = _compare_pixels(pix_a[key], pix_b[key],
                                              threshold=pixel_threshold)
                        pixel_results[f"{name}@{scale}x"] = cmp
                    elif key in pix_a:
                        pixel_results[f"{name}@{scale}x"] = {
                            "match": False, "issue": "only_in_a"}
                    elif key in pix_b:
                        pixel_results[f"{name}@{scale}x"] = {
                            "match": False, "issue": "only_in_b"}

        pixel_diffs = {k: v for k, v in pixel_results.items()
                       if not v.get("match", False)}
        if pixel_diffs:
            diffs.append({
                "section": "pixels",
                "entries": pixel_diffs,
            })

    # --- Summary ---
    total_rends_a = len(car_a["renditions"])
    total_rends_b = len(car_b["renditions"])
    pixel_total = len(pixel_results)
    pixel_match = sum(1 for v in pixel_results.values() if v.get("match"))

    report["summary"] = {
        "renditions_a": total_rends_a,
        "renditions_b": total_rends_b,
        "renditions_matched": rend_match_count,
        "renditions_differing": rend_diff_count,
        "renditions_only_a": len(only_a_rends),
        "renditions_only_b": len(only_b_rends),
        "pixels_compared": pixel_total,
        "pixels_matched": pixel_match,
        "pixels_differing": pixel_total - pixel_match,
        "identical": len(diffs) == 0,
    }

    return report


def _compare_rendition(ra: dict, rb: dict) -> list[dict]:
    """Compare two individual rendition entries. Return list of diffs."""
    issues = []

    # Structural fields
    for field in ("width", "height", "pixel_format", "colorspace_id",
                  "is_opaque", "bitmap_enc", "bitmaplist_unk"):
        va = ra.get(field)
        vb = rb.get(field)
        if va != vb:
            # Make pixel_format readable
            if field == "pixel_format":
                va = _pixel_format_str(va) if isinstance(va, bytes) else va
                vb = _pixel_format_str(vb) if isinstance(vb, bytes) else vb
            issues.append({"field": field, "a": va, "b": vb})

    # TLV tags present
    if ra["tlv_tags"] != rb["tlv_tags"]:
        issues.append({
            "field": "tlv_tags",
            "a": [TLV_NAMES.get(t, hex(t)) for t in ra["tlv_tags"]],
            "b": [TLV_NAMES.get(t, hex(t)) for t in rb["tlv_tags"]],
        })

    # Bytes per row
    if ra.get("bpr") != rb.get("bpr"):
        issues.append({"field": "bpr", "a": ra.get("bpr"), "b": rb.get("bpr")})

    # Compression format
    comp_a = _celm_desc(ra.get("celm"))
    comp_b = _celm_desc(rb.get("celm"))
    if comp_a != comp_b:
        issues.append({"field": "compression", "a": comp_a, "b": comp_b})

    # INLK comparison (skip x/y coordinates — packing layout can differ)
    inlk_a = ra.get("inlk")
    inlk_b = rb.get("inlk")
    if (inlk_a is None) != (inlk_b is None):
        issues.append({"field": "inlk", "a": "present" if inlk_a else "absent",
                        "b": "present" if inlk_b else "absent"})
    elif inlk_a and inlk_b:
        if (inlk_a["w"] != inlk_b["w"] or inlk_a["h"] != inlk_b["h"]):
            issues.append({"field": "inlk_size",
                           "a": (inlk_a["w"], inlk_a["h"]),
                           "b": (inlk_b["w"], inlk_b["h"])})
        if inlk_a["f1"] != inlk_b["f1"]:
            issues.append({"field": "inlk_f1",
                           "a": inlk_a["f1"], "b": inlk_b["f1"]})
        # Compare INLK attributes (element, part, scale, identifier)
        # excluding dim1 which varies with packing layout
        attrs_a = {k: v for k, v in inlk_a.get("attrs", {}).items()
                   if k != 8}  # exclude Dim1
        attrs_b = {k: v for k, v in inlk_b.get("attrs", {}).items()
                   if k != 8}
        if attrs_a != attrs_b:
            issues.append({"field": "inlk_attrs",
                           "a": attrs_a, "b": attrs_b})

    # Slices TLV
    if ra.get("slices") != rb.get("slices"):
        issues.append({"field": "slices",
                        "a": ra.get("slices"), "b": rb.get("slices")})

    # Metrics TLV
    if ra.get("metrics") != rb.get("metrics"):
        issues.append({"field": "metrics",
                        "a": ra.get("metrics"), "b": rb.get("metrics")})

    # Blend TLV
    if ra.get("blend") != rb.get("blend"):
        issues.append({"field": "blend",
                        "a": ra.get("blend"), "b": rb.get("blend")})

    # Color comparison
    if ra.get("color") and rb.get("color"):
        ca = ra["color"]
        cb = rb["color"]
        if ca["colorspace"] != cb["colorspace"]:
            issues.append({"field": "color_space",
                           "a": ca["colorspace"], "b": cb["colorspace"]})
        if ca["components"] != cb["components"]:
            issues.append({"field": "color_components",
                           "a": list(ca["components"]),
                           "b": list(cb["components"])})

    # Multisize image entries
    ms_a = ra.get("multisize")
    ms_b = rb.get("multisize")
    if (ms_a is None) != (ms_b is None):
        issues.append({"field": "multisize",
                        "a": "present" if ms_a else "absent",
                        "b": "present" if ms_b else "absent"})
    elif ms_a and ms_b:
        if ms_a["entries"] != ms_b["entries"]:
            issues.append({"field": "multisize_entries",
                           "a": ms_a["entries"], "b": ms_b["entries"]})

    # Data size (informational for lossy — not a hard diff)
    if ra["rend_len"] != rb["rend_len"]:
        # Only flag large proportional differences for same compression
        if comp_a == comp_b and ra["rend_len"] > 0 and rb["rend_len"] > 0:
            ratio = max(ra["rend_len"], rb["rend_len"]) / min(
                ra["rend_len"], rb["rend_len"])
            if ratio > 2.0:
                issues.append({
                    "field": "rend_size",
                    "a": ra["rend_len"],
                    "b": rb["rend_len"],
                    "note": f"ratio {ratio:.1f}x",
                })

    return issues


# ---------------------------------------------------------------------------
# Text output
# ---------------------------------------------------------------------------

def _format_text(report: dict, *, quiet: bool = False,
                 summary_only: bool = False) -> str:
    lines = []

    def pr(s=""):
        lines.append(s)

    pr(f"Comparing:")
    pr(f"  A: {report['file_a']}")
    pr(f"  B: {report['file_b']}")
    pr()

    if not summary_only:
        for diff in report["differences"]:
            section = diff["section"]

            if section == "carheader":
                if quiet:
                    continue
                pr(f"[carheader] {diff['field']}: "
                   f"A={diff['a']}  B={diff['b']}")

            elif section == "metadata":
                if quiet:
                    continue
                pr(f"[metadata] {diff['field']}: "
                   f"A={diff['a']}  B={diff['b']}")

            elif section == "keyformat":
                pr(f"[keyformat] A={diff['a']}  B={diff['b']}")

            elif section == "named_blocks":
                if diff.get("field") == "order":
                    pr(f"[blocks] order differs:")
                    pr(f"  A: {diff['a']}")
                    pr(f"  B: {diff['b']}")
                else:
                    if diff.get("only_a"):
                        pr(f"[blocks] only in A: {diff['only_a']}")
                    if diff.get("only_b"):
                        pr(f"[blocks] only in B: {diff['only_b']}")

            elif section == "tree_header":
                pr(f"[tree_header {diff['tree']}] {diff['field']}: "
                   f"A={diff['a']}  B={diff['b']}")

            elif section == "leaf_layout":
                pr(f"[leaf_layout {diff['tree']}] {diff['field']}: "
                   f"A={diff['a']}  B={diff['b']}")

            elif section == "leaf_inline_keys":
                pr(f"[leaf_inline_keys {diff['tree']}] {diff['field']}: "
                   f"A={diff['a']}  B={diff['b']}")
                if diff['field'] == "inline_matches_rebuilt" and diff['b'] is False:
                    pr(f"  ^ CUICatalog reads its rendition key cache from "
                       f"this region; mismatch causes silent empty lookups")

            elif section == "bitmap_keys":
                if diff.get("field") == "presence":
                    pr(f"[bitmap_keys] presence: "
                       f"A={diff['a']}  B={diff['b']}")
                elif diff.get("field") == "identifiers":
                    if diff.get("only_a"):
                        pr(f"[bitmap_keys] identifiers only in A: {diff['only_a']}")
                    if diff.get("only_b"):
                        pr(f"[bitmap_keys] identifiers only in B: {diff['only_b']}")
                else:
                    pr(f"[bitmap_keys] {diff['field']}: "
                       f"A={diff['a']}  B={diff['b']}")

            elif section == "facets":
                if "name" in diff:
                    if not quiet:
                        pr(f"[facet] {diff['name']}: "
                           f"A={diff['a']}  B={diff['b']}")
                else:
                    if diff.get("only_a"):
                        pr(f"[facets] only in A: {diff['only_a']}")
                    if diff.get("only_b"):
                        pr(f"[facets] only in B: {diff['only_b']}")

            elif section == "appearance_keys":
                pr(f"[appearance_keys] A={diff['a']}  B={diff['b']}")

            elif section == "renditions":
                rtype = diff.get("type")
                if rtype == "only_in_a":
                    for e in diff["entries"]:
                        pr(f"[rendition] only in A: {e['name']} "
                           f"@{e['scale']}x ({e['layout']})")
                elif rtype == "only_in_b":
                    for e in diff["entries"]:
                        pr(f"[rendition] only in B: {e['name']} "
                           f"@{e['scale']}x ({e['layout']})")
                elif rtype == "mismatches":
                    for e in diff["entries"]:
                        if quiet and not e.get("issues"):
                            continue
                        name = e.get("name", "?")
                        scale = e.get("scale", "?")
                        layout = e.get("layout", "?")
                        pr(f"[rendition] {name} @{scale}x ({layout}):")
                        for iss in e.get("issues", []):
                            if "field" in iss:
                                note = f"  {iss.get('note', '')}" if iss.get(
                                    'note') else ""
                                pr(f"    {iss['field']}: "
                                   f"A={iss['a']}  B={iss['b']}{note}")
                            elif "issue" in iss:
                                pr(f"    {iss['issue']}")

            elif section == "pixels":
                for img_key in sorted(diff["entries"]):
                    cmp = diff["entries"][img_key]
                    if cmp.get("issue"):
                        pr(f"[pixels] {img_key}: {cmp['issue']}")
                    elif not cmp.get("size_match"):
                        pr(f"[pixels] {img_key}: size mismatch "
                           f"A={cmp['size_a']} B={cmp['size_b']}")
                    else:
                        pr(f"[pixels] {img_key}: "
                           f"{cmp['diff_pixels']}/{cmp['total_pixels']} "
                           f"pixels differ "
                           f"(max_diff={cmp['max_channel_diff']}, "
                           f"PSNR={cmp['psnr']:.1f}dB)")

    # Summary
    s = report["summary"]
    pr()
    pr("Summary:")
    pr(f"  Renditions: A={s['renditions_a']}  B={s['renditions_b']}")
    pr(f"  Matched: {s['renditions_matched']}  "
       f"Differing: {s['renditions_differing']}  "
       f"Only-A: {s['renditions_only_a']}  "
       f"Only-B: {s['renditions_only_b']}")
    if s["pixels_compared"] > 0:
        pr(f"  Pixels compared: {s['pixels_compared']}  "
           f"Matched: {s['pixels_matched']}  "
           f"Differing: {s['pixels_differing']}")
    if s["identical"]:
        pr("  Result: IDENTICAL")
    else:
        pr(f"  Result: {len(report['differences'])} difference(s) found")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------

def _format_json(report: dict) -> str:
    """Serialize report to JSON, handling bytes and tuples."""
    def default(obj):
        if isinstance(obj, bytes):
            return obj.hex()
        if isinstance(obj, tuple):
            return list(obj)
        if isinstance(obj, float) and (math.isinf(obj) or math.isnan(obj)):
            return str(obj)
        raise TypeError(f"not serializable: {type(obj)}")
    return json.dumps(report, indent=2, default=default)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Compare two .car (compiled asset catalog) files.")
    parser.add_argument("car_a", help="First .car file")
    parser.add_argument("car_b", help="Second .car file")
    parser.add_argument("--pixel-threshold", type=int, default=0,
                        help="Max per-channel diff to treat as matching "
                             "(default: 0)")
    parser.add_argument("--summary", action="store_true",
                        help="Only print the summary")
    parser.add_argument("--json", action="store_true",
                        help="Output machine-readable JSON")
    parser.add_argument("--quiet", action="store_true",
                        help="Only print failures and summary")
    parser.add_argument("--no-pixels", action="store_true",
                        help="Skip pixel-level comparison")
    args = parser.parse_args()

    for p in (args.car_a, args.car_b):
        if not os.path.isfile(p):
            print(f"Error: {p} not found", file=sys.stderr)
            sys.exit(2)

    car_a = parse_car(args.car_a)
    car_b = parse_car(args.car_b)

    report = compare_cars(car_a, car_b,
                          pixel_threshold=args.pixel_threshold,
                          do_pixels=not args.no_pixels)

    if args.json:
        # Strip raw rendition data from JSON output
        for diff in report["differences"]:
            if diff["section"] == "renditions" and diff.get("type") == "mismatches":
                for e in diff.get("entries", []):
                    e.pop("rend_raw", None)
        print(_format_json(report))
    else:
        print(_format_text(report, quiet=args.quiet,
                           summary_only=args.summary))

    sys.exit(0 if report["summary"]["identical"] else 1)


if __name__ == "__main__":
    main()
