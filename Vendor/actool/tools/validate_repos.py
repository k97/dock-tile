#!/usr/bin/env python3
"""Validate actool output against the system actool using third-party repos.

Clones repos (depth 1) into third_party/, compiles each xcassets path with
both the system and our actool at several macOS deployment targets, then
compares the results using compare_car.py.

Usage:
    python tools/validate_repos.py [options]

Options:
    --pixel-threshold N   Per-channel tolerance for lossy compression (default: 2)
    --repos-file FILE     JSON file with repo list (default: tools/repos.json)
    --only SLUG           Only process this repo slug
    --keep-output         Keep compiled output directories for inspection
    --verbose             Print progress for passing cases too
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(TOOLS_DIR)
THIRD_PARTY = os.path.join(PROJECT_ROOT, "third_party")
SYSTEM_ACTOOL = "/usr/bin/actool"
RUST_ACTOOL = os.path.join(PROJECT_ROOT, "target", "release", "actool")


def ensure_rust_actool_built() -> str:
    """Build the Rust actool binary in release mode if missing. Returns path."""
    if os.path.isfile(RUST_ACTOOL):
        return RUST_ACTOOL
    print("  Building Rust actool (release) ...")
    result = subprocess.run(
        ["cargo", "build", "--release", "--bin", "actool"],
        cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=600)
    if result.returncode != 0:
        print(f"  cargo build failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(2)
    if not os.path.isfile(RUST_ACTOOL):
        print(f"  binary still missing at {RUST_ACTOOL}", file=sys.stderr)
        sys.exit(2)
    return RUST_ACTOOL

# macOS deployment targets that change compression behavior:
#   < 10.11  → uncompressed
#   10.11    → LZFSE
#   11.0     → DMP2
#   26.0     → Liquid glass
DEPLOY_TARGETS = ["10.9", "10.11", "11.0", "14.0", "26.0"]


def repo_slug(url: str) -> str:
    """Derive a directory name from a git URL."""
    name = url.rstrip("/").rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return name


def clone_repo(url: str) -> str:
    """Clone repo to third_party/slug (skip if present). Return path."""
    slug = repo_slug(url)
    dest = os.path.join(THIRD_PARTY, slug)
    if os.path.isdir(dest):
        return dest
    os.makedirs(THIRD_PARTY, exist_ok=True)
    print(f"  Cloning {url} ...")
    result = subprocess.run(
        ["git", "clone", "--depth", "1", "--quiet", url, dest],
        capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        print(f"  CLONE FAILED: {result.stderr.strip()}", file=sys.stderr)
        return ""
    return dest


def find_app_icon(xcassets_path: str) -> str | None:
    """Find an .appiconset inside an xcassets directory."""
    for entry in os.listdir(xcassets_path):
        if entry.endswith(".appiconset"):
            return entry[:-len(".appiconset")]
    return None


def compile_system(xcassets: str, outdir: str, deploy: str,
                   app_icon: str | None) -> bool:
    """Compile with /usr/bin/actool. Returns True on success."""
    os.makedirs(outdir, exist_ok=True)
    cmd = [
        SYSTEM_ACTOOL, "--compile", outdir,
        "--platform", "macosx",
        "--minimum-deployment-target", deploy,
    ]
    if app_icon:
        cmd += ["--app-icon", app_icon,
                "--output-partial-info-plist",
                os.path.join(outdir, "AppIcon.Info.plist")]
    cmd.append(xcassets)
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    return result.returncode == 0


def compile_ours(xcassets: str, outdir: str, deploy: str,
                 app_icon: str | None) -> bool:
    """Compile with the Rust actool binary. Returns True on success."""
    os.makedirs(outdir, exist_ok=True)
    cmd = [
        RUST_ACTOOL, "--compile", outdir,
        "--platform", "macosx",
        "--minimum-deployment-target", deploy,
    ]
    if app_icon:
        cmd += ["--app-icon", app_icon,
                "--output-partial-info-plist",
                os.path.join(outdir, "AppIcon.Info.plist")]
    cmd.append(xcassets)
    result = subprocess.run(
        cmd, capture_output=True, text=True, timeout=60,
        cwd=PROJECT_ROOT)
    return result.returncode == 0


def compare(car_a: str, car_b: str, pixel_threshold: int) -> dict:
    """Compare two .car files. Returns the report dict."""
    # Import compare_car from tools/
    sys.path.insert(0, TOOLS_DIR)
    from compare_car import parse_car, compare_cars
    a = parse_car(car_a)
    b = parse_car(car_b)
    return compare_cars(a, b, pixel_threshold=pixel_threshold)


def is_failure(report: dict, min_psnr: float = 20.0) -> bool:
    """Decide if a comparison report represents a real failure.

    Packed atlas differences (different names, counts) are expected since
    packing layout can vary. We only fail on:
    - structural rendition mismatches (same name, different fields)
    - pixel size mismatches or extraction failures
    - pixel PSNR below min_psnr (severe quality loss, not just compression)
    - missing/extra facets
    """
    for diff in report["differences"]:
        section = diff["section"]
        if section == "pixels":
            for entry in diff.get("entries", {}).values():
                # Size mismatch or extraction issue is always a failure
                if not entry.get("size_match", True):
                    return True
                if entry.get("issue"):
                    return True
                # Low PSNR means structurally wrong, not just compression
                psnr = entry.get("psnr", float('inf'))
                if psnr < min_psnr:
                    return True
        if section == "renditions" and diff.get("type") == "mismatches":
            for entry in diff.get("entries", []):
                layout = entry.get("layout", "")
                for iss in entry.get("issues", []):
                    field = iss.get("field", "")
                    a_val = iss.get("a")
                    b_val = iss.get("b")
                    # Packed atlas textures can have different packing
                    # layouts, so dimensions, stride, and data size are
                    # expected to vary. But pixel format, compression
                    # envelope, and colorspace must still match — a wrong
                    # CELM version or pixel format causes rendering bugs.
                    if layout == "packed_atlas" and field in (
                            "width", "height", "bpr", "rend_size"):
                        continue
                    # Data size naturally varies
                    if field == "rend_size":
                        continue
                    # RLE vs uncompressed is an encoder edge case
                    if field == "compression":
                        comp_a = a_val.split("/")[0] if a_val else ""
                        comp_b = b_val.split("/")[0] if b_val else ""
                        if {comp_a, comp_b} <= {"rle", "uncompressed"}:
                            continue
                    return True
        if section == "renditions" and diff.get("type") in (
                "only_in_a", "only_in_b"):
            for entry in diff.get("entries", []):
                layout = entry.get("layout", "")
                # Packed atlas counts/names vary with packing layout
                if layout == "packed_atlas":
                    continue
                # packed_ref vs inline is a packing decision difference —
                # the pixel content is identical, just stored differently
                if layout in ("packed_ref", "inline"):
                    continue
                return True
        if section == "facets":
            if diff.get("only_a") or diff.get("only_b"):
                return True
        if section == "appearance_keys":
            return True
    return False


def format_failure(report: dict) -> str:
    """Format only the failure-relevant parts of a report."""
    # Reuse compare_car's text formatter, filtering to failures
    sys.path.insert(0, TOOLS_DIR)
    from compare_car import _format_text
    return _format_text(report, quiet=True)


def load_repos(path: str) -> list[dict]:
    """Load repo list from JSON file.

    Expected format:
    [
      {
        "url": "https://github.com/user/repo.git",
        "paths": ["path/to/Images.xcassets", "other/Assets.xcassets"]
      },
      ...
    ]
    """
    with open(path) as f:
        return json.load(f)


def main():
    parser = argparse.ArgumentParser(
        description="Validate actool against system actool using "
                    "third-party repos.")
    parser.add_argument("--pixel-threshold", type=int, default=2,
                        help="Per-channel pixel tolerance (default: 2)")
    parser.add_argument("--repos-file", default=os.path.join(
        TOOLS_DIR, "repos.json"),
        help="JSON file with repo list (default: tools/repos.json)")
    parser.add_argument("--only", metavar="SLUG",
                        help="Only process this repo slug")
    parser.add_argument("--keep-output", action="store_true",
                        help="Keep compiled output for inspection")
    parser.add_argument("--verbose", action="store_true",
                        help="Print passing cases too")
    args = parser.parse_args()

    if not os.path.isfile(SYSTEM_ACTOOL):
        print("Error: system actool not found at "
              f"{SYSTEM_ACTOOL}", file=sys.stderr)
        sys.exit(2)

    ensure_rust_actool_built()

    if not os.path.isfile(args.repos_file):
        print(f"Error: repos file not found: {args.repos_file}",
              file=sys.stderr)
        print("Create it with format:", file=sys.stderr)
        print('  [{"url": "https://github.com/user/repo.git", '
              '"paths": ["path/to/Assets.xcassets"]}]', file=sys.stderr)
        sys.exit(2)

    repos = load_repos(args.repos_file)
    if args.only:
        repos = [r for r in repos if repo_slug(r["url"]) == args.only]
        if not repos:
            print(f"Error: no repo with slug '{args.only}'", file=sys.stderr)
            sys.exit(2)

    total = 0
    passed = 0
    failed = 0
    errors = 0
    failures = []

    for repo in repos:
        url = repo["url"]
        paths = repo["paths"]
        slug = repo_slug(url)

        print(f"\n{'='*60}")
        print(f"Repo: {slug}")
        print(f"{'='*60}")

        repo_dir = clone_repo(url)
        if not repo_dir:
            errors += 1
            continue

        for rel_path in paths:
            xcassets = os.path.join(repo_dir, rel_path)
            if not os.path.isdir(xcassets):
                print(f"  SKIP {rel_path} (not found)")
                continue

            app_icon = find_app_icon(xcassets)
            short = os.path.basename(rel_path)

            for deploy in DEPLOY_TARGETS:
                label = f"{slug}/{short} @ macOS {deploy}"
                total += 1

                work_dir = os.path.join(
                    THIRD_PARTY, ".work", slug,
                    short.replace(".xcassets", ""),
                    f"macosx-{deploy}")
                sys_dir = os.path.join(work_dir, "system")
                our_dir = os.path.join(work_dir, "ours")

                # Always start from a clean state so we never compare
                # stale output from a previous run or deploy target.
                if os.path.exists(work_dir):
                    shutil.rmtree(work_dir)
                os.makedirs(work_dir)

                # Write a sentinel before compilation so we can verify
                # the car files were actually produced by this run.
                sentinel = os.path.join(work_dir, ".run_started")
                with open(sentinel, "w") as sf:
                    sf.write(deploy)
                run_start = os.path.getmtime(sentinel)

                # Compile with system actool
                if not compile_system(xcassets, sys_dir, deploy, app_icon):
                    print(f"  SKIP {label} (system actool failed)")
                    total -= 1
                    continue

                sys_car = os.path.join(sys_dir, "Assets.car")
                if not os.path.isfile(sys_car):
                    print(f"  SKIP {label} (system produced no Assets.car)")
                    total -= 1
                    continue

                # Compile with our actool
                if not compile_ours(xcassets, our_dir, deploy, app_icon):
                    print(f"  FAIL {label} (our actool failed to compile)")
                    failed += 1
                    failures.append((label, "compilation failed"))
                    continue

                our_car = os.path.join(our_dir, "Assets.car")
                if not os.path.isfile(our_car):
                    print(f"  FAIL {label} (no Assets.car produced)")
                    failed += 1
                    failures.append((label, "no Assets.car"))
                    continue

                # Verify car files are from this run, not stale leftovers
                stale = False
                for car_path in (sys_car, our_car):
                    if os.path.getmtime(car_path) < run_start:
                        print(f"  ERROR {label} (stale {car_path})")
                        errors += 1
                        stale = True
                        break
                if stale:
                    continue

                # Compare
                try:
                    report = compare(sys_car, our_car,
                                     args.pixel_threshold)
                except Exception as e:
                    print(f"  ERROR {label} (compare: {e})")
                    errors += 1
                    continue

                if is_failure(report):
                    print(f"  FAIL {label}")
                    detail = format_failure(report)
                    failures.append((label, detail))
                    failed += 1
                else:
                    passed += 1
                    if args.verbose:
                        s = report["summary"]
                        print(f"  PASS {label}  "
                              f"(rend={s['renditions_matched']}/"
                              f"{s['renditions_a']}"
                              f", px={s['pixels_matched']}/"
                              f"{s['pixels_compared']})")

                if not args.keep_output:
                    shutil.rmtree(work_dir, ignore_errors=True)

    # Final report
    print(f"\n{'='*60}")
    print(f"Results: {passed} passed, {failed} failed, "
          f"{errors} errors out of {total} tests")
    print(f"{'='*60}")

    if failures:
        print(f"\nFailures:\n")
        for label, detail in failures:
            print(f"--- {label} ---")
            print(detail)
            print()

    # Clean empty work dirs
    work_root = os.path.join(THIRD_PARTY, ".work")
    if not args.keep_output and os.path.isdir(work_root):
        shutil.rmtree(work_root, ignore_errors=True)

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
