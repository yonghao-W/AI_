#!/usr/bin/env python3
"""Compute WCAG contrast for rendered UI elements from contrast_elements.json.

Text was hidden before background capture, so each element rect samples the
actual background (including panels, overlay tint, and world) behind the text.
"""

import argparse
import json
import os
import sys

from PIL import Image


def luminance(rgb):
    values = []
    for channel in rgb:
        value = channel / 255.0
        values.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
    return 0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2]


def contrast(l1, l2):
    light, dark = max(l1, l2), min(l1, l2)
    return (light + 0.05) / (dark + 0.05)


def crop_rect(rect, width, height, shrink=0.0):
    x, y, w, h = rect
    if shrink > 0.0:
        dx, dy = w * shrink, h * shrink
        x, y, w, h = x + dx, y + dy, w - dx * 2, h - dy * 2
    x0 = max(0, int(round(x)))
    y0 = max(0, int(round(y)))
    x1 = min(width, int(round(x + w)))
    y1 = min(height, int(round(y + h)))
    if x1 - x0 < 2 or y1 - y0 < 2:
        return None
    return x0, y0, x1, y1



def include_element(state, path):
    if state.startswith("menu_"):
        return "MenuView_" in path or "/Armory/" in path
    if state in ("pause", "draw", "backpack", "intel"):
        return "/HUDContent/" not in path and "GameHUD/" in path
    return True


def evaluate(element, image):
    rect = crop_rect(element["rect"], image.width, image.height,
                     0.10 if element["kind"] == "button" else 0.0)
    if rect is None:
        return None
    x0, y0, x1, y1 = rect
    pixels = image.crop(rect).load()
    raw = element["color"]
    text = [raw[0] * 255.0, raw[1] * 255.0, raw[2] * 255.0, raw[3]]
    ratios = []
    for y in range(y1 - y0):
        for x in range(x1 - x0):
            bg = pixels[x, y][:3]
            alpha = text[3]
            effective = tuple(text[i] * alpha + bg[i] * (1.0 - alpha) for i in range(3))
            ratios.append(contrast(luminance(effective), luminance(bg)))
    if not ratios:
        return None
    ratios.sort()
    count = len(ratios)
    return {
        "min": round(ratios[0], 2),
        "p05": round(ratios[int(count * 0.05)], 2),
        "median": round(ratios[count // 2], 2),
        "samples": count,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="ui_refactor/phase3/evidence/contrast_elements.json")
    parser.add_argument("--out", default="ui_refactor/phase3/evidence/contrast_report.json")
    args = parser.parse_args()

    with open(args.input, encoding="utf-8") as handle:
        data = json.load(handle)

    report = {
        "generated_at": data.get("generated_at"),
        "git_commit": data.get("git_commit"),
        "godot_version": data.get("godot_version"),
        "method": "text hidden before capture; per-element background pixels sampled from real rendered frame",
        "thresholds": {"body": 4.5, "large": 3.0, "large_font_px": 24},
        "states": [],
        "failures": 0,
        "total_elements": 0,
    }
    worst = []

    for state in data.get("states", []):
        background_path = state["background"]
        if not os.path.exists(background_path):
            print("missing background: %s" % background_path)
            continue
        image = Image.open(background_path).convert("RGB")
        state_report = {"state": state["state"], "elements": 0, "failures": 0, "worst": []}
        for element in state.get("elements", []):
            if element.get("color", [0, 0, 0, 0])[3] < 0.05:
                continue
            if not include_element(state["state"], element["path"]):
                continue
            metrics = evaluate(element, image)
            if metrics is None:
                continue
            threshold = 3.0 if element["font_size"] >= 24 else 4.5
            passed = metrics["p05"] >= threshold
            record = {
                "state": state["state"],
                "path": element["path"],
                "text": element["text"],
                "kind": element["kind"],
                "font_size": element["font_size"],
                "threshold": threshold,
                "p05": metrics["p05"],
                "min": metrics["min"],
                "median": metrics["median"],
                "shadow": element.get("shadow", False),
                "outline": element.get("outline", False),
                "passed": passed,
            }
            state_report["elements"] += 1
            report["total_elements"] += 1
            if not passed:
                state_report["failures"] += 1
                report["failures"] += 1
                state_report["worst"].append(record)
                worst.append(record)
        state_report["worst"].sort(key=lambda item: item["p05"])
        state_report["worst"] = state_report["worst"][:8]
        report["states"].append(state_report)

    worst.sort(key=lambda item: item["p05"])
    report["worst"] = worst[:30]
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2)

    print("contrast: %d elements, %d below threshold across %d states" % (
        report["total_elements"], report["failures"], len(report["states"])
    ))
    for item in worst[:15]:
        print("  %-16s %-6s %2dpx p05=%.2f min=%.2f %s%s | %s" % (
            item["state"], item["kind"], item["font_size"], item["p05"], item["min"],
            "S" if item["shadow"] else "", "O" if item["outline"] else "", item["text"][:32]
        ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
