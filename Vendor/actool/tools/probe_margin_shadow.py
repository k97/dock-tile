#!/usr/bin/env python3
"""Measure the squircle's margin drop shadow — the soft halo Apple bakes into
the transparent margin outside the icon. A flat-fill icon with shadow:
layer-color is compiled by both actools; we profile the alpha falloff outside
the top and bottom squircle edges so shadow_params can be tuned to match.
"""
import json, os, shutil, struct, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "msh_work")
MARGIN = 100


def build(shadow="layer-color", opacity=0.5, fill=0.5):
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    b = os.path.join(WORK, "Probe.icon")
    os.makedirs(os.path.join(b, "Assets"))
    from PIL import Image
    Image.new("RGBA", (1024, 1024), (0, 0, 0, 0)).save(os.path.join(b, "Assets", "clear.png"))
    icon = {
        "fill": {"solid": f"srgb:{fill},{fill},{fill},1.0"},
        "groups": [{"layers": [{"image-name": "clear.png", "name": "C", "glass": False}],
                    "shadow": {"kind": shadow, "opacity": opacity}}],
        "supported-platforms": {"squares": ["macOS"]},
    }
    json.dump(icon, open(os.path.join(b, "icon.json"), "w"), indent=2)
    return b


def read(b, actool):
    out = os.path.join(WORK, "out"); os.makedirs(out, exist_ok=True)
    subprocess.run([actool, "--compile", out, "--platform", "macosx",
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
    return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4).astype(int)


def alpha_profile(im, x=512):
    # outside the squircle top edge (y<100) and bottom edge (y>924)
    top = [im[MARGIN - k, x, 3] for k in [4, 8, 14, 22, 32, 45]]
    bot = [im[924 + k, x, 3] for k in [4, 8, 14, 22, 32, 45]]
    return top, bot


def run(actool, label, **kw):
    im = read(build(**kw), actool)
    if im is None:
        print(f"{label}: FAILED")
        return
    top, bot = alpha_profile(im)
    print(f"{label:34} TOP α {top}  BOT α {bot}")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    print("# margin-shadow alpha at px-outside [4,8,14,22,32,45], shadow=layer-color opacity 0.5")
    if which in ("both", "apple"):
        run("/usr/bin/actool", "apple layer-color")
        run("/usr/bin/actool", "apple neutral", shadow="neutral")
    if which in ("both", "ours"):
        run(os.path.join(ROOT, "target/debug/actool"), "ours layer-color")
        run(os.path.join(ROOT, "target/debug/actool"), "ours neutral", shadow="neutral")
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
