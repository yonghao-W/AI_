#!/usr/bin/env python3
"""Compare two UI capture directories and write a JSON report.

Usage:
    python visual_diff.py --baseline DIR --current DIR --out REPORT.json [--threshold 0.001]
"""

import argparse
import hashlib
import json
import os
import sys

from PIL import Image, ImageChops


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def diff_ratio(baseline_path, current_path, channel_threshold=8):
    baseline = Image.open(baseline_path).convert("RGB")
    current = Image.open(current_path).convert("RGB")
    if baseline.size != current.size:
        return 1.0, 255.0, baseline.size, current.size
    diff = ImageChops.difference(baseline, current)
    gray = diff.convert("L")
    changed = gray.point(lambda value: 255 if value > channel_threshold else 0)
    histogram = changed.histogram()
    changed_pixels = histogram[255] if len(histogram) > 255 else 0
    total = baseline.size[0] * baseline.size[1]
    mean = sum(i * count for i, count in enumerate(gray.histogram())) / max(total, 1)
    return changed_pixels / max(total, 1), mean, baseline.size, current.size


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--current", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--threshold", type=float, default=0.001)
    args = parser.parse_args()

    names = sorted(
        name for name in os.listdir(args.baseline)
        if name.lower().endswith(".png")
    )
    results = []
    failures = 0
    for name in names:
        baseline_path = os.path.join(args.baseline, name)
        current_path = os.path.join(args.current, name)
        if not os.path.exists(current_path):
            results.append({"file": name, "status": "missing", "ratio": 1.0})
            failures += 1
            continue
        ratio, mean, baseline_size, current_size = diff_ratio(baseline_path, current_path)
        identical = sha256(baseline_path) == sha256(current_path)
        passed = ratio <= args.threshold
        if not passed:
            failures += 1
        results.append({
            "file": name,
            "status": "pass" if passed else "fail",
            "identical": identical,
            "ratio": round(ratio, 8),
            "mean_abs_diff": round(mean, 4),
            "baseline_size": list(baseline_size),
            "current_size": list(current_size),
        })

    report = {
        "baseline_dir": os.path.abspath(args.baseline),
        "current_dir": os.path.abspath(args.current),
        "threshold": args.threshold,
        "total": len(names),
        "failures": failures,
        "results": results,
    }
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2)
    print("visual diff: %d files, %d failures (threshold %.4f%%)" % (
        len(names), failures, args.threshold * 100
    ))
    for item in results:
        if item["status"] != "pass":
            print("  FAIL %s ratio=%.4f%% mean=%.2f" % (
                item["file"], item["ratio"] * 100, item.get("mean_abs_diff", 0.0)
            ))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
