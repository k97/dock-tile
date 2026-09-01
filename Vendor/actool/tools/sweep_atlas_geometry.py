#!/usr/bin/env python3
"""Sweep harness for reverse-engineering Apple's iOS app-icon atlas packer.

Compiles an .appiconset with /usr/bin/actool and dumps each packed atlas's
image positions (parsed from the INLK/KLNI link blocks). Used to probe the
packing geometry; see CLAUDE.md "iOS platform" for why the algorithm did not
yield a derivable rule. A snapshot of the collected data is in
tools/atlas_sweep_dataset.json.

Usage: python3 tools/sweep_atlas_geometry.py '[["60x60","3x","iphone"],...]'
"""
import struct, zlib, json, sys, subprocess, os, shutil

def png(path, w):
    def ch(t, da):
        c = t + da
        return struct.pack(">I", len(da)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    raw = b''.join(b'\x00' + b'\x40\x80\xc0\xff' * w for _ in range(w))
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack(">IIBBBBB", w, w, 8, 6, 0, 0, 0)) + ch(b'IDAT', zlib.compress(raw)) + ch(b'IEND', b''))

def compile_ref(entries, workdir):
    """entries: list of (size_str, scale, idiom). Returns atlas layouts."""
    shutil.rmtree(workdir, ignore_errors=True)
    aset = os.path.join(workdir, "A.xcassets", "AppIcon.appiconset")
    os.makedirs(aset)
    imgs = []
    seen = set()
    for size, scale, idiom in entries:
        px = int(round(float(size.split('x')[0]) * int(scale[0])))
        fn = f"i{px}_{idiom}.png"
        if fn not in seen:
            png(os.path.join(aset, fn), px); seen.add(fn)
        imgs.append({"size": size, "idiom": idiom, "filename": fn, "scale": scale})
    json.dump({"images": imgs, "info": {"author": "xcode", "version": 1}}, open(os.path.join(aset, "Contents.json"), "w"))
    open(os.path.join(workdir, "A.xcassets", "Contents.json"), "w").write('{"info":{"author":"xcode","version":1}}')
    out = os.path.join(workdir, "ref")
    os.makedirs(out)
    subprocess.run(["/usr/bin/actool", "--compile", out, "--platform", "iphoneos",
                    "--minimum-deployment-target", "14.0", "--app-icon", "AppIcon",
                    "--output-partial-info-plist", os.path.join(out, "p.plist"),
                    os.path.join(workdir, "A.xcassets")],
                   capture_output=True)
    car = os.path.join(out, "Assets.car")
    if not os.path.exists(car):
        return None
    return parse_atlases(open(car, "rb").read())

def parse_atlases(data):
    # KLNI blocks: x,y,w,h + attrs (scale=12, idiom=15, dim1=8)
    from collections import defaultdict
    atl = defaultdict(list)
    idx = 0
    while True:
        j = data.find(b"KLNI", idx)
        if j < 0: break
        idx = j + 4
        x, y, w, h = struct.unpack_from("<4I", data, j + 8)
        off = j + 4 + 4 + 16
        alen = struct.unpack_from("<H", data, off + 2)[0]
        attrs = struct.unpack_from("<%dH" % (alen // 2), data, off + 4)
        d = {}
        k = 1
        while k + 1 < len(attrs):
            d[attrs[k]] = attrs[k + 1]; k += 2
        atl[(d.get(12), d.get(15), d.get(8, 0))].append((w, h, x, y))
    # atlas dims from PackedImage CSI? approximate by max extent
    result = []
    for key in sorted(atl):
        imgs = sorted(atl[key])
        W = max(x + w for (w, h, x, y) in imgs) + 2
        H = max(y + h for (w, h, x, y) in imgs) + 2
        result.append({"scale": key[0], "idiom": key[1], "dim1": key[2],
                       "W": W, "H": H, "imgs": [(w, h, x, y) for (w, h, x, y) in imgs]})
    return result

if __name__ == "__main__":
    entries = json.loads(sys.argv[1])
    r = compile_ref(entries, "tmp/sweep/work")
    print(json.dumps(r))
