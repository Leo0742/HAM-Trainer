#!/usr/bin/env python3
"""Render answer-free, question-specific study figures from the reference PDF."""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# question: (PDF page, top, left, height, width), at 130 dpi.
# Crops deliberately exclude the printed red answer key.
CROPS = {
    32: (127, 540, 125, 610, 835),
    136: (151, 740, 125, 410, 750),
    137: (152, 295, 130, 370, 390),
    138: (152, 875, 130, 370, 390),
    139: (153, 295, 130, 370, 390),
    140: (153, 875, 130, 370, 390),
    141: (154, 295, 130, 370, 390),
    142: (154, 875, 130, 370, 390),
    180: (163, 465, 120, 150, 260),
    263: (181, 820, 125, 395, 750),
    322: (196, 575, 135, 340, 400),
    323: (196, 1020, 135, 330, 400),
    326: (197, 1000, 130, 330, 750),
    327: (198, 370, 130, 285, 750),
    328: (198, 880, 130, 315, 750),
    331: (199, 1030, 130, 390, 355),
    332: (200, 285, 130, 340, 355),
    341: (202, 470, 135, 540, 830),
    342: (203, 125, 135, 540, 830),
    343: (203, 840, 135, 500, 830),
    344: (204, 405, 130, 455, 835),
    353: (207, 100, 130, 470, 835),
    354: (207, 845, 130, 490, 835),
    355: (208, 380, 125, 455, 835),
    406: (221, 115, 125, 455, 525),
    407: (221, 745, 125, 600, 445),
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, default=ROOT / "ExamSources" / "Справочник_КЭ.pdf")
    parser.add_argument("--output", type=Path, default=ROOT / "Content" / "diagrams" / "questions")
    args = parser.parse_args()
    if not args.reference.is_file():
        raise SystemExit(f"Reference PDF not found: {args.reference}")
    if shutil.which("pdftoppm") is None or shutil.which("sips") is None:
        raise SystemExit("pdftoppm and macOS sips are required")

    cache = ROOT / ".build" / "figure-pages"
    cache.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    rendered: dict[int, Path] = {}
    for page in sorted({value[0] for value in CROPS.values()}):
        target = cache / f"page-{page}.png"
        subprocess.run([
            "pdftoppm", "-f", str(page), "-l", str(page), "-r", "130", "-png", "-singlefile",
            str(args.reference), str(target.with_suffix("")),
        ], check=True)
        rendered[page] = target

    for number, (page, top, left, height, width) in CROPS.items():
        target = args.output / f"q-{number:03d}.png"
        shutil.copyfile(rendered[page], target)
        subprocess.run([
            "sips", "-c", str(height), str(width), "--cropOffset", str(top), str(left),
            str(target), "--out", str(target),
        ], check=True, stdout=subprocess.DEVNULL)
    print(f"Extracted {len(CROPS)} answer-free figures to {args.output}")


if __name__ == "__main__":
    main()
