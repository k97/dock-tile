#!/usr/bin/env python3
"""Characterize the per-layer drop shadow: a glass layer with `shadow:
layer-color` casts a soft offset-down shadow on the background inside the icon.

A glass circle over a flat light fill is compiled by /usr/bin/actool; we profile
the background *outside* the circle (top vs bottom) to recover the shadow's
peak, blur falloff, downward offset, and whether it is tinted by the layer
colour.  The icon-frame lighting brightens *inside* edges; this measures the
*outside* darkening.
"""
import json, os, shutil, struct, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "lsh_work")
R = 300


def build(cfg):
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    b = os.path.join(WORK, "Probe.icon")
    os.makedirs(os.path.join(b, "Assets"))
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([512 - R, 512 - R, 512 + R, 512 + R],
                                fill=tuple(cfg["color"]) + (255,))
    img.save(os.path.join(b, "Assets", "circ.png"))
    g = cfg.get("fill_grey", 0.85)
    icon = {
        "fill": {"solid": f"srgb:{g},{g},{g},1.0"},
        "groups": [{"layers": [{"image-name": "circ.png", "name": "C", "glass": True}],
                    "shadow": {"kind": cfg.get("shadow", "layer-color"),
                               "opacity": cfg.get("opacity", 0.5)},
                    "translucency": {"enabled": cfg.get("transl", False), "value": 0.5}}],
        "supported-platforms": {"squares": ["macOS"]},
    }
    json.dump(icon, open(os.path.join(b, "icon.json"), "w"), indent=2)
    return b


def read(b):
    out = os.path.join(WORK, "out"); os.makedirs(out, exist_ok=True)
    subprocess.run(["/usr/bin/actool", "--compile", out, "--platform", "macosx",
                    "--minimum-deployment-target", "11.0", "--app-icon", "Probe",
                    "--output-partial-info-plist", os.path.join(out, "p"), b],
                   capture_output=True)
    car = os.path.join(out, "Assets.car")
    if not os.path.exists(car):
        return None
    ex = os.path.join(WORK, "px"); os.makedirs(ex, exist_ok=True)
    subprocess.run([os.path.join(ROOT, "tools", "extract_pixels"), car, "Probe", ex],
                   capture_output=True)
    import glob
    fs = sorted(glob.glob(ex + "/*_1x.rgba"))
    if not fs:
        return None
    d = open(fs[0], "rb").read(); w, h = struct.unpack_from("<II", d, 0)
    return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4).astype(float)


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def run(cfg, label):
    im = read(build(cfg))
    if im is None:
        print(f"{label}: FAILED")
        return
    rr = int(R * 824 / 1024)
    top, bot = 512 - rr, 512 + rr
    bg = lum(im[150, 512, :3])  # flat fill, away from circle/edge
    # outside the circle, above (top) and below (bottom), along x=512
    print(f"\n== {label} == bg={bg:.0f}")
    print("  ABOVE circle (px-out : Δlum):  " +
          "  ".join(f"{k}:{lum(im[top-k,512,:3])-bg:+.0f}" for k in [2,6,12,20,30,45]))
    print("  BELOW circle (px-out : Δlum):  " +
          "  ".join(f"{k}:{lum(im[bot+k,512,:3])-bg:+.0f}" for k in [2,6,12,20,30,45]))
    # colour of the shadow just below (is it tinted by the layer colour?)
    px = im[bot + 6, 512, :3]
    print(f"  shadow px below (rgb): {px.astype(int)}  (layer colour {cfg['color']})")


if __name__ == "__main__":
    BLACK = [10, 10, 10]
    BLUE = [0, 40, 230]
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("all",):
        run({"color": BLACK, "shadow": "layer-color", "transl": False}, "opaque black, layer-color")
        run({"color": BLACK, "shadow": "neutral", "transl": False}, "opaque black, neutral")
        run({"color": BLACK, "shadow": "none", "transl": False}, "opaque black, none")
        run({"color": BLUE, "shadow": "layer-color", "transl": False}, "opaque blue, layer-color (tint?)")
        run({"color": BLACK, "shadow": "layer-color", "transl": False, "opacity": 1.0}, "opaque black, opacity 1.0")
        run({"color": BLACK, "shadow": "layer-color", "transl": True}, "frosted black, layer-color")
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
