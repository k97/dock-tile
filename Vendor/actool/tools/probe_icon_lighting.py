#!/usr/bin/env python3
"""Characterize the icon-frame 'glass-tile' lighting: the bright top inner-edge
highlight and broad bottom inner shading Apple bakes around the squircle.

A flat solid-fill icon (uniform background, transparent layer) is compiled by
/usr/bin/actool; against the uniform fill, any deviation near the squircle edge
is the lighting. We profile all four inner edges + report the highlight/shadow
magnitude and depth so it can be reproduced as a post-composite pass.
"""
import json, os, shutil, struct, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "lit_work")
MARGIN = 100  # squircle inset at 1024


def build(fill_grey):
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    b = os.path.join(WORK, "Probe.icon")
    os.makedirs(os.path.join(b, "Assets"))
    from PIL import Image
    Image.new("RGBA", (1024, 1024), (0, 0, 0, 0)).save(os.path.join(b, "Assets", "clear.png"))
    icon = {
        "fill": {"solid": f"srgb:{fill_grey},{fill_grey},{fill_grey},1.0"},
        "groups": [{"layers": [{"image-name": "clear.png", "name": "C", "glass": False}],
                    "shadow": {"kind": "none", "opacity": 0.5}}],
        "supported-platforms": {"squares": ["macOS"]},
    }
    json.dump(icon, open(os.path.join(b, "icon.json"), "w"), indent=2)
    return b


def read(b, actool="/usr/bin/actool"):
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
    return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4).astype(float)


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def profile(fill_grey, actool="/usr/bin/actool", label=""):
    im = read(build(fill_grey), actool)
    if im is None:
        print(f"{label}: FAILED")
        return
    base = lum(im[512, 512, :3])  # icon-centre fill value
    print(f"\n== {label} fill={fill_grey} center_lum={base:.0f} ==")
    # TOP inner edge: column x=512, going down from the squircle top (y=100).
    print("  TOP    (px-inside : Δlum):  " +
          "  ".join(f"{k}:{lum(im[100+k,512,:3])-base:+.0f}" for k in [2,6,10,16,24,40,60]))
    print("  BOTTOM (px-inside : Δlum):  " +
          "  ".join(f"{k}:{lum(im[924-k,512,:3])-base:+.0f}" for k in [2,6,10,16,24,40,60]))
    print("  LEFT   (px-inside : Δlum):  " +
          "  ".join(f"{k}:{lum(im[512,100+k,:3])-base:+.0f}" for k in [2,6,10,16,24,40,60]))
    print("  RIGHT  (px-inside : Δlum):  " +
          "  ".join(f"{k}:{lum(im[512,924-k,:3])-base:+.0f}" for k in [2,6,10,16,24,40,60]))


if __name__ == "__main__":
    a = sys.argv[1] if len(sys.argv) > 1 else "/usr/bin/actool"
    for g in [0.55, 0.30, 0.80]:
        profile(g, a, label="apple" if "usr" in a else "ours")
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
