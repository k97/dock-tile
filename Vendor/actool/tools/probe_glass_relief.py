#!/usr/bin/env python3
"""Probe Apple's 'raised glass relief' — the embossed bevel on a glass layer's
edges. A glass shape (circle) smaller than the canvas is composited over a flat
background; we scan a vertical line through it and report the luminance profile
across the top edge, interior, and bottom edge to detect a bright/dark rim that
a flat tint wouldn't produce.
"""
import json, os, shutil, struct, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "relief_work")
R = 320  # circle radius, px (in the 1024 viewBox)


def make_circle_png(path, rgb):
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([512 - R, 512 - R, 512 + R, 512 + R], fill=tuple(rgb) + (255,))
    img.save(path)


def build(cfg):
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    assets = os.path.join(WORK, "Probe.icon", "Assets")
    os.makedirs(assets)
    make_circle_png(os.path.join(assets, "circ.png"), cfg["color"])
    br, bg, bb = cfg["bg"]
    transl = cfg.get("transl", 0.5)
    group = {
        "layers": [{"image-name": "circ.png", "name": "Circ", "glass": True}],
        "shadow": {"kind": cfg.get("shadow", "layer-color"), "opacity": 0.5},
        "translucency": {"enabled": cfg.get("transl_enabled", True), "value": transl},
    }
    if cfg.get("specular"):
        group["specular"] = True
    icon = {
        "fill": {"solid": f"srgb:{br:.4f},{bg:.4f},{bb:.4f},1.0"},
        "groups": [group],
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


def lum(px):
    return 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]


def profile(cfg, label):
    im = compile_and_read(build(cfg))
    if im is None:
        print(f"{label}: FAILED")
        return
    col = im[:, 512, :3]
    Lc = np.array([lum(col[y]) for y in range(1024)])
    bgl = round(lum(np.array(cfg['bg']) * 255), 1)
    # The layer is scaled 824/1024, so the rendered circle radius ≈ 257.
    rr = int(round(R * 824 / 1024))
    top, bot = 512 - rr, 512 + rr
    interior = round(float(Lc[480:545].mean()), 1)
    print(f"\n== {label} ==  bg_lum≈{bgl}  interior≈{interior}  (rendered edges y≈{top}/{bot})")
    print("  TOP edge profile (y, lum):")
    print("   " + "  ".join(f"{y}:{Lc[y]:.0f}" for y in range(top - 12, top + 26, 3)))
    print("  BOTTOM edge profile (y, lum):")
    print("   " + "  ".join(f"{y}:{Lc[y]:.0f}" for y in range(bot - 24, bot + 14, 3)))
    # emboss = max deviation from interior within ±20px of each edge
    topband = Lc[top - 5:top + 25]
    botband = Lc[bot - 25:bot + 5]
    print(f"  TOP band: min={topband.min():.0f} max={topband.max():.0f} "
          f"(interior {interior}, bg {bgl}) | BOTTOM band: min={botband.min():.0f} max={botband.max():.0f}")
    # left/right at y=512 (rendered radius)
    row = np.array([lum(im[512, x, :3]) for x in range(1024)])
    lft, rgt = 512 - rr, 512 + rr
    print(f"  LEFT band min/max: {row[lft-5:lft+20].min():.0f}/{row[lft-5:lft+20].max():.0f}  "
          f"RIGHT band min/max: {row[rgt-20:rgt+5].min():.0f}/{row[rgt-20:rgt+5].max():.0f}")


if __name__ == "__main__":
    GREY = (0.55, 0.55, 0.55)
    CIRC = [128, 128, 128]   # neutral grey circle so edge effects aren't masked by hue
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("all", "tinted"):
        profile({"bg": GREY, "color": CIRC, "shadow": "layer-color"}, "tinted (layer-color)")
    if mode in ("all", "neutral"):
        profile({"bg": GREY, "color": CIRC, "shadow": "neutral"}, "neutral shadow")
    if mode in ("all", "opaque"):
        profile({"bg": GREY, "color": CIRC, "shadow": "layer-color",
                 "transl_enabled": False, "specular": True}, "opaque + specular")
    if mode == "blur":
        # Fine 1px top-edge profile to measure the feather/blur width, and
        # whether it's constant px or scales with shape size.
        for rad in [320, 160]:
            globals()["R"] = rad
            im = compile_and_read(build({"bg": GREY, "color": CIRC, "shadow": "layer-color"}))
            col = np.array([lum(im[y, 512, :3]) for y in range(1024)])
            rr = rad * 824 / 1024
            edge = 512 - rr
            # bg = inside the squircle but above the circle; interior = circle centre
            bgl, int_ = col[int(edge) - 60:int(edge) - 30].mean(), col[490:535].mean()
            # 10% and 90% crossing points of the bg->interior transition
            lo, hi = int_ + 0.1 * (bgl - int_), int_ + 0.9 * (bgl - int_)
            ys = np.arange(int(edge) - 40, int(edge) + 60)
            v = col[ys]
            y90 = ys[np.argmin(np.abs(v - hi))]
            y10 = ys[np.argmin(np.abs(v - lo))]
            print(f"R={rad} rendered_edge≈{edge:.0f} bg={bgl:.0f} interior={int_:.0f} "
                  f"10%@y={y90} 90%@y={y10} width={abs(y10-y90)}px (sigma≈{abs(y10-y90)/2.56:.1f})")
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
