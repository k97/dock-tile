#!/usr/bin/env python3
"""Reverse-engineer Apple's frosted-glass *tint strength*: how strongly a glass
layer's colour multiplies the background, as a function of the group's
translucency value (and whether it depends on the colour / background).

A full-canvas solid-colour glass slab is composited over a flat solid
background by /usr/bin/actool; we read the baked sized rendition and, away from
the relief edges, compare the output to the known background and layer colour.

For a multiply model  out = bg * lerp(1, colour, k)  the per-channel tint factor
is  k = (1 - out/bg) / (1 - colour)  — k=1 is a full multiply, k=0 no tint.
"""
import json, os, shutil, struct, subprocess, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "glass_work")


def make_png(path, rgb):
    Image.new("RGBA", (1024, 1024), tuple(rgb) + (255,)).save(path)


def build(cfg):
    """cfg: bg (r,g,b 0-1), color (r,g,b 0-255), transl (float), shadow (str)."""
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    assets = os.path.join(WORK, "Probe.icon", "Assets")
    os.makedirs(assets)
    make_png(os.path.join(assets, "slab.png"), cfg["color"])
    br, bg, bb = cfg["bg"]
    icon = {
        "fill": {"solid": f"srgb:{br:.4f},{bg:.4f},{bb:.4f},1.0"},
        "groups": [{
            "layers": [{"image-name": "slab.png", "name": "Slab", "glass": True}],
            "shadow": {"kind": cfg.get("shadow", "layer-color"), "opacity": 0.5},
            "translucency": {"enabled": True, "value": cfg["transl"]},
        }],
        "supported-platforms": {"squares": ["macOS"]},
    }
    with open(os.path.join(WORK, "Probe.icon", "icon.json"), "w") as f:
        json.dump(icon, f, indent=2)
    return os.path.join(WORK, "Probe.icon")


def compile_and_read(bundle):
    out = os.path.join(WORK, "out")
    os.makedirs(out, exist_ok=True)
    subprocess.run(
        ["/usr/bin/actool", "--compile", out, "--platform", "macosx",
         "--minimum-deployment-target", "11.0", "--app-icon", "Probe",
         "--output-partial-info-plist", os.path.join(out, "p"), bundle],
        capture_output=True)
    car = os.path.join(out, "Assets.car")
    if not os.path.exists(car):
        return None
    ex = os.path.join(WORK, "px")
    os.makedirs(ex, exist_ok=True)
    subprocess.run([os.path.join(ROOT, "tools", "extract_pixels"), car, "Probe", ex],
                   capture_output=True)
    for fn in os.listdir(ex):
        if fn.endswith("_1x.rgba"):
            d = open(os.path.join(ex, fn), "rb").read()
            w, h = struct.unpack_from("<II", d, 0)
            return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4).astype(float)
    return None


def sample(im, y):
    # average a horizontal strip across the icon interior at row y
    return im[y, 412:612, :3].mean(0)


def tint_k(out, bg, color):
    """Per-channel multiply factor k: out = bg * (1 - k + k*color)."""
    ks = []
    for c in range(3):
        b = bg[c] * 255.0
        col = color[c] / 255.0
        if abs(1 - col) < 0.02 or b < 1:
            continue
        ks.append((1 - out[c] / b) / (1 - col))
    return float(np.mean(ks)) if ks else float("nan")


def run(cfg, label):
    im = compile_and_read(build(cfg))
    if im is None:
        print(f"{label:38} COMPILE/READ FAILED")
        return
    mid = sample(im, 512)
    bg255 = np.array(cfg["bg"]) * 255.0
    k = tint_k(mid, cfg["bg"], np.array(cfg["color"]))
    print(f"{label:38} out_mid={mid.round(0).astype(int)} bg={bg255.round(0).astype(int)} "
          f"color={cfg['color']} k={k:.2f}")


if __name__ == "__main__":
    GREY = (0.6, 0.6, 0.6)        # bg ~153
    BLUE = [0, 51, 229]
    RED = [229, 38, 0]
    GREEN = [0, 200, 60]
    mode = sys.argv[1] if len(sys.argv) > 1 else "transl"

    if mode == "transl":
        print("# sweep translucency value (blue slab over grey, shadow=layer-color)")
        for v in [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 1.0]:
            run({"bg": GREY, "color": BLUE, "transl": v}, f"transl={v}")
    elif mode == "color":
        print("# different colours at translucency 0.5")
        for nm, col in [("blue", BLUE), ("red", RED), ("green", GREEN), ("dkgrey", [60, 60, 60])]:
            run({"bg": GREY, "color": col, "transl": 0.5}, f"color={nm}")
    elif mode == "bg":
        print("# blue slab, transl 0.5, varying background")
        for nm, b in [("white .9", (0.9,)*3), ("grey .6", GREY), ("dark .3", (0.3,)*3)]:
            run({"bg": b, "color": BLUE, "transl": 0.5}, f"bg={nm}")
    elif mode == "shadow":
        print("# does shadow kind gate the tint? blue slab transl 0.5")
        for sk in ["layer-color", "neutral", "none"]:
            run({"bg": GREY, "color": BLUE, "transl": 0.5, "shadow": sk}, f"shadow={sk}")
    elif mode == "fitD":
        # Fit out_c = bg_c - D*(1 - col_c): D = (bg_c - out_c)/(1 - col_c).
        # Sweep many (bg, colour) and report D per channel to test constancy.
        print("# subtractive-model D per channel across bg+colour (transl 0.5)")
        combos = [(GREY, BLUE), ((0.9,)*3, BLUE), ((0.3,)*3, BLUE),
                  (GREY, RED), (GREY, GREEN), ((0.7,)*3, [255, 128, 0]),
                  ((0.5, 0.6, 0.7), BLUE)]
        for b, col in combos:
            im = compile_and_read(build({"bg": b, "color": col, "transl": 0.5}))
            mid = sample(im, 512)
            Ds = []
            for c in range(3):
                if abs(1 - col[c] / 255) > 0.05:
                    Ds.append((b[c] * 255 - mid[c]) / (1 - col[c] / 255))
            print(f"  bg={tuple(round(x,2) for x in b)} col={col} "
                  f"out={mid.round(0).astype(int)} D/ch={[round(d,1) for d in Ds]}")
    elif mode == "profile":
        # Vertical D profile to capture the relief (top->bottom).
        print("# D at top/upper/mid/lower/bottom (blue over grey, transl 0.5)")
        im = compile_and_read(build({"bg": GREY, "color": BLUE, "transl": 0.5}))
        for y in [180, 350, 512, 680, 850]:
            o = sample(im, y)
            # R channel: col=0 so D = bg - out
            Dr = 153 - o[0]
            print(f"  y={y} out={o.round(0).astype(int)} D(R)={Dr:.1f}")

    if os.path.exists(WORK):
        shutil.rmtree(WORK)
