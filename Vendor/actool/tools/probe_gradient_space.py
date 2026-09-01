#!/usr/bin/env python3
"""Determine the colour space Apple interpolates the background gradient in.

A two-stop linear-gradient icon (no opaque layer) is compiled by
/usr/bin/actool; we read the baked gradient and compare its midpoint to the two
candidate interpolations:
  - component-linear in the stop space (what we do now via device-RGB CGGradient)
  - linear-light (gamma-decode → lerp → gamma-encode)
A black→white gradient is the cleanest discriminator: midpoint ≈128 means
component/sRGB interpolation, ≈188 means linear-light.
"""
import json, os, shutil, struct, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORK = os.path.join(ROOT, "grad_work")


def srgb_to_lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    s = np.where(c <= 0.0031308, c * 12.92, 1.055 * (c ** (1 / 2.4)) - 0.055)
    return s * 255.0


def build(stops):
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
    bundle = os.path.join(WORK, "Probe.icon")
    os.makedirs(os.path.join(bundle, "Assets"))
    # No opaque layer — an empty group leaves the gradient squircle as the
    # rendition. (A group with no layers still compiles.)
    icon = {
        "fill": {"linear-gradient": stops},
        "groups": [],
        "supported-platforms": {"squares": ["macOS"]},
    }
    with open(os.path.join(bundle, "icon.json"), "w") as f:
        json.dump(icon, f, indent=2)
    return bundle


def read(bundle):
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
    import glob
    fs = sorted(glob.glob(ex + "/*_1x.rgba"))
    if not fs:
        return None
    d = open(fs[0], "rb").read()
    w, h = struct.unpack_from("<II", d, 0)
    return np.frombuffer(d[8:8 + w * h * 4], np.uint8).reshape(h, w, 4).astype(float)


def run(stops, label):
    im = read(build(stops))
    if im is None:
        print(f"{label}: FAILED")
        return
    # Vertical profile down the centre column, inside the squircle (margin 100).
    col = im[:, 512, :]
    valid = col[:, 3] > 200
    ys = np.where(valid)[0]
    top_y, bot_y = ys.min(), ys.max()
    print(f"\n== {label} ==  squircle y[{top_y},{bot_y}]")
    for frac in [0.0, 0.25, 0.5, 0.75, 1.0]:
        y = int(top_y + frac * (bot_y - top_y))
        print(f"  {int(frac*100):3}%  y={y}  rgb={col[y,:3].astype(int)}")
    # Midpoint analysis (green channel, neutral grads have R=G=B).
    y0, y1, ym = top_y + 30, bot_y - 30, (top_y + bot_y) // 2
    c0, c1, cm = col[y0, 1], col[y1, 1], col[ym, 1]
    comp_mid = (c0 + c1) / 2
    lin_mid = lin_to_srgb((srgb_to_lin(c0) + srgb_to_lin(c1)) / 2)
    print(f"  endpoints g: top={c0:.0f} bot={c1:.0f}  MID measured={cm:.0f}")
    print(f"    component-linear predicts {comp_mid:.0f}; linear-light predicts {lin_mid:.0f}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    if mode in ("all", "bw"):
        run(["srgb:0,0,0,1.0", "srgb:1,1,1,1.0"], "black->white srgb")
    if mode in ("all", "p3bw"):
        run(["display-p3:0,0,0,1.0", "display-p3:1,1,1,1.0"], "black->white p3")
    if mode in ("all", "grey"):
        run(["srgb:0.2,0.2,0.2,1.0", "srgb:0.8,0.8,0.8,1.0"], "grey 0.2->0.8 srgb")
    if mode in ("all", "color"):
        run(["srgb:0.9,0.1,0.1,1.0", "srgb:0.1,0.1,0.9,1.0"], "red->blue srgb")
    if os.path.exists(WORK):
        shutil.rmtree(WORK)
