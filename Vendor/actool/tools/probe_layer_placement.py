#!/usr/bin/env python3
"""Reverse-engineer Apple's .icon layer placement by compiling synthetic
single-layer bundles with marker squares at known native coordinates and
measuring where /usr/bin/actool lands them in the 1024 rendition.

For each config we recover the affine transform native->canvas by locating the
centroids of distinctly-coloured marker squares and solving for a per-axis
scale + offset (Apple's placement is a uniform scale + translation, centred).
"""
import json, os, shutil, struct, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "probe_work")

# marker colour -> (fx, fy) centre as a FRACTION of the layer's viewBox, so
# the same layout works at any viewBox size/aspect and the measured canvas
# separation directly reveals the viewBox->canvas scale.
MARKERS = {
    "A": ((255, 0, 0), (0.25, 0.25)),
    "B": ((0, 200, 0), (0.75, 0.25)),
    "C": ((0, 0, 255), (0.25, 0.75)),
    "D": ((240, 220, 0), (0.75, 0.75)),
    "E": ((230, 0, 230), (0.50, 0.50)),
}
MARK_FRAC = 0.045  # marker square side as a fraction of the viewBox's min dim.


def make_svg(path, vb_w, vb_h):
    m = MARK_FRAC * min(vb_w, vb_h)
    rects = []
    for (rgb, (fx, fy)) in MARKERS.values():
        x, y = fx * vb_w - m / 2, fy * vb_h - m / 2
        hexc = "#{:02X}{:02X}{:02X}".format(*rgb)
        rects.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{m:.1f}" height="{m:.1f}" fill="{hexc}"/>'
        )
    svg = (
        f'<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{vb_w}" height="{vb_h}" '
        f'viewBox="0 0 {vb_w} {vb_h}">\n' + "\n".join(rects) + "\n</svg>\n"
    )
    with open(path, "w") as f:
        f.write(svg)


def make_png(path, vb_w, vb_h):
    img = Image.new("RGBA", (vb_w, vb_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = MARK_FRAC * min(vb_w, vb_h)
    for (rgb, (fx, fy)) in MARKERS.values():
        x, y = fx * vb_w - m / 2, fy * vb_h - m / 2
        d.rectangle([x, y, x + m, y + m], fill=rgb + (255,))
    img.save(path)


def build_bundle(cfg):
    """cfg keys: fmt(svg|png), vb(w,h), glass(bool), scale(float|None),
    trans([x,y]|None), fill(value)."""
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    bundle = os.path.join(WORK, "Probe.icon")
    assets = os.path.join(bundle, "Assets")
    os.makedirs(assets)
    vb = cfg.get("vb", (1024, 1024))
    if cfg["fmt"] == "svg":
        img_name = "marker.svg"
        make_svg(os.path.join(assets, img_name), *vb)
    else:
        img_name = "marker.png"
        make_png(os.path.join(assets, img_name), *vb)
    # Apple defaults a layer with no `glass` key to glass (liquid-glass), which
    # strips the markers; set it explicitly so non-glass tests bake in colour.
    layer = {"image-name": img_name, "name": "Marker", "glass": bool(cfg.get("glass"))}
    # Apple's actool crashes on a partial `position` — both keys are required.
    if cfg.get("scale") is not None or cfg.get("trans") is not None:
        layer["position"] = {
            "scale": cfg.get("scale", 1.0),
            "translation-in-points": cfg.get("trans", [0, 0]),
        }
    if cfg.get("gscale") is not None or cfg.get("gtrans") is not None:
        group_pos = {
            "scale": cfg.get("gscale", 1.0),
            "translation-in-points": cfg.get("gtrans", [0, 0]),
        }
    group = {"layers": [layer], "shadow": {"kind": "none", "opacity": 0.5}}
    if cfg.get("gscale") is not None or cfg.get("gtrans") is not None:
        group["position"] = group_pos
    if cfg.get("glass"):
        group["translucency"] = {"enabled": True, "value": 0.5}
        group["shadow"] = {"kind": "layer-color", "opacity": 0.5}
    # `automatic` fill bakes a non-glass layer into the sized rendition at
    # full colour (an explicit linear-gradient fill stores gradient-only for
    # non-glass layers), so the markers are directly measurable.
    icon = {
        "fill": cfg.get("fill", "automatic"),
        "groups": [group],
        "supported-platforms": {"squares": ["macOS"]},
    }
    with open(os.path.join(bundle, "icon.json"), "w") as f:
        json.dump(icon, f, indent=2)
    return bundle


def compile_apple(bundle):
    out = os.path.join(WORK, "out")
    os.makedirs(out, exist_ok=True)
    subprocess.run(
        ["/usr/bin/actool", "--compile", out, "--platform", "macosx",
         "--minimum-deployment-target", "11.0", "--app-icon", "Probe",
         "--output-partial-info-plist", os.path.join(out, "p"), bundle],
        capture_output=True)
    car = os.path.join(out, "Assets.car")
    return car if os.path.exists(car) else None


def extract(car):
    ex = os.path.join(WORK, "px")
    os.makedirs(ex, exist_ok=True)
    subprocess.run([os.path.join(ROOT, "tools", "extract_pixels"), car,
                    "Probe", ex], capture_output=True)
    for fn in os.listdir(ex):
        if fn.endswith("_1x.rgba"):
            with open(os.path.join(ex, fn), "rb") as f:
                d = f.read()
            w, h = struct.unpack_from("<II", d, 0)
            return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4).astype(int)
    return None


def centroid(im, rgb, tol=60):
    diff = np.abs(im[:, :, :3] - np.array(rgb))
    m = (diff.sum(2) < tol) & (im[:, :, 3] > 100)
    if m.sum() < 20:
        return None
    ys, xs = np.where(m)
    return (xs.mean(), ys.mean(), int(m.sum()))


def measure(im):
    """Recover the rendered layer's on-canvas width/height (px) and centre from
    the marker centroids. Markers A/B span 0.5 of the viewBox horizontally and
    A/C span 0.5 vertically, so rendered_dim = 2 * centroid_separation."""
    cents = {k: centroid(im, rgb) for k, (rgb, _) in MARKERS.items()}
    found = {k: v for k, v in cents.items() if v}
    res = {"found": len(found)}

    def sep(p, q, comp):
        if p in found and q in found:
            return abs(found[q][comp] - found[p][comp])
        return None

    sx = [s for s in [sep("A", "B", 0), sep("C", "D", 0)] if s]
    sy = [s for s in [sep("A", "C", 1), sep("B", "D", 1)] if s]
    if sx:
        res["W"] = round(2 * sum(sx) / len(sx), 1)        # rendered layer width, px
    if sy:
        res["H"] = round(2 * sum(sy) / len(sy), 1)        # rendered layer height, px
    if "E" in found:
        res["cx"], res["cy"] = round(found["E"][0], 1), round(found["E"][1], 1)
    return res


def run(cfg, label):
    bundle = build_bundle(cfg)
    car = compile_apple(bundle)
    if not car:
        print(f"{label:42} COMPILE FAILED")
        return None
    im = extract(car)
    if im is None:
        print(f"{label:42} NO RENDITION")
        return None
    r = measure(im)
    W = r.get("W", "?"); H = r.get("H", "?")
    cx = r.get("cx", "?"); cy = r.get("cy", "?")
    print(f"{label:42} found={r['found']} renderedWxH={W}x{H}px centre=({cx},{cy})")
    return r


CONFIGS = [
    # Baseline scale: format + glass.
    ("svg 1024 nonglass", {"fmt": "svg"}),
    ("png 1024 nonglass", {"fmt": "png"}),
    ("svg 1024 GLASS", {"fmt": "svg", "glass": True}),
    ("png 1024 GLASS", {"fmt": "png", "glass": True}),
    # Layer position.scale — expect base * scale.
    ("svg L-scale=0.5", {"fmt": "svg", "scale": 0.5}),
    ("svg L-scale=1.5", {"fmt": "svg", "scale": 1.5}),
    ("svg L-scale=2.0", {"fmt": "svg", "scale": 2.0}),
    # Layer translation — expect centre to shift by trans*base.
    ("svg L-trans=[100,0]", {"fmt": "svg", "trans": [100, 0]}),
    ("svg L-trans=[0,-100]", {"fmt": "svg", "trans": [0, -100]}),
    # Group position.scale / translation.
    ("svg G-scale=1.5", {"fmt": "svg", "gscale": 1.5}),
    ("svg G-scale=2.2", {"fmt": "svg", "gscale": 2.2}),
    ("svg G+L scale 1.5*0.8", {"fmt": "svg", "gscale": 1.5, "scale": 0.8}),
    ("svg G-trans=[100,0]", {"fmt": "svg", "gtrans": [100, 0]}),
    # viewBox SIZE (square): fixed 824/1024 → W scales with vb; fit-to-box
    # 824/max(vb) → W constant ≈824 regardless of vb size.
    ("svg vb 512sq", {"fmt": "svg", "vb": (512, 512)}),
    ("svg vb 1024sq", {"fmt": "svg", "vb": (1024, 1024)}),
    ("svg vb 2048sq", {"fmt": "svg", "vb": (2048, 2048)}),
    ("png vb 512sq", {"fmt": "png", "vb": (512, 512)}),
    ("png vb 2048sq", {"fmt": "png", "vb": (2048, 2048)}),
    # Aspect: non-square viewBox.
    ("svg wide vb 1024x512", {"fmt": "svg", "vb": (1024, 512)}),
    ("svg tall vb 512x1024", {"fmt": "svg", "vb": (512, 1024)}),
    ("svg wide vb 2048x512", {"fmt": "svg", "vb": (2048, 512)}),
    # Fill kind effect on placement.
    ("svg solid fill", {"fmt": "svg", "fill": {"solid": "srgb:0.7,0.7,0.7,1.0"}}),
]


if __name__ == "__main__":
    only = sys.argv[1] if len(sys.argv) > 1 else None
    for label, cfg in CONFIGS:
        if only and only not in label:
            continue
        run(cfg, label)
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
