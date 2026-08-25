#!/usr/bin/env python3
"""Deterministically extract the visually audited category-2 exam figures."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DPI = 220

# Every crop was visually checked against the preserved source PDF. Coordinates
# are x, y, width, height at baseDPI and deliberately exclude the red answer key.
ASSETS = {
    "q-032.png": {"page": 127, "baseDPI": 130, "crop": (125, 540, 835, 610), "questions": [32], "purpose": "Figure 2 HAREC national-license table"},
    "q-136.png": {"page": 151, "baseDPI": 130, "crop": (125, 740, 750, 410), "questions": [136], "purpose": "Three waveform variants"},
    "q-137.png": {"page": 152, "baseDPI": 130, "crop": (130, 295, 390, 370), "questions": [137], "purpose": "Four spectrum variants"},
    "q-138.png": {"page": 152, "baseDPI": 130, "crop": (130, 875, 390, 370), "questions": [138], "purpose": "Four spectrum variants"},
    "q-139.png": {"page": 153, "baseDPI": 130, "crop": (130, 295, 390, 370), "questions": [139], "purpose": "Four spectrum variants"},
    "q-140.png": {"page": 153, "baseDPI": 130, "crop": (130, 875, 390, 370), "questions": [140], "purpose": "Four spectrum variants"},
    "q-141.png": {"page": 154, "baseDPI": 130, "crop": (130, 295, 390, 370), "questions": [141], "purpose": "Four spectrum variants"},
    "q-142.png": {"page": 154, "baseDPI": 130, "crop": (130, 875, 390, 370), "questions": [142], "purpose": "Four spectrum variants"},
    "fm-transmitter.png": {"page": 162, "baseDPI": 160, "crop": (145, 275, 340, 190), "questions": [173, 174, 175, 176], "purpose": "Shared neutral FM-transmitter block diagram"},
    "superhet-receiver.png": {"page": 163, "baseDPI": 160, "crop": (140, 580, 345, 165), "questions": [177, 178, 179, 180], "purpose": "Shared neutral superheterodyne receiver block diagram"},
    "q-263.png": {"page": 181, "baseDPI": 130, "crop": (125, 820, 750, 395), "questions": [263], "purpose": "Three waveform variants"},
    "q-322.png": {"page": 196, "baseDPI": 130, "crop": (135, 575, 400, 340), "questions": [322], "purpose": "Four filter circuit variants"},
    "q-323.png": {"page": 196, "baseDPI": 130, "crop": (135, 1020, 400, 330), "questions": [323], "purpose": "Four filter circuit variants"},
    "q-326.png": {"page": 197, "baseDPI": 130, "crop": (130, 1000, 750, 330), "questions": [326], "purpose": "Four rectifier circuit variants"},
    "q-327.png": {"page": 198, "baseDPI": 130, "crop": (130, 370, 750, 285), "questions": [327], "purpose": "Four rectifier circuit variants"},
    "q-328.png": {"page": 198, "baseDPI": 130, "crop": (130, 880, 750, 315), "questions": [328], "purpose": "Four rectifier circuit variants"},
    "q-331.png": {"page": 199, "baseDPI": 130, "crop": (130, 1030, 355, 390), "questions": [331], "purpose": "Two detector circuit variants"},
    "q-332.png": {"page": 200, "baseDPI": 130, "crop": (130, 285, 355, 340), "questions": [332], "purpose": "Two detector circuit variants"},
    "q-341.png": {"page": 202, "baseDPI": 130, "crop": (135, 470, 830, 540), "questions": [341], "purpose": "Two receiver block-diagram variants"},
    "q-342.png": {"page": 203, "baseDPI": 130, "crop": (135, 125, 830, 540), "questions": [342], "purpose": "Two receiver block-diagram variants"},
    "q-343.png": {"page": 203, "baseDPI": 130, "crop": (135, 840, 830, 500), "questions": [343], "purpose": "Two receiver block-diagram variants"},
    "q-344.png": {"page": 204, "baseDPI": 130, "crop": (130, 405, 835, 455), "questions": [344], "purpose": "Two receiver block-diagram variants"},
    "q-353.png": {"page": 207, "baseDPI": 130, "crop": (130, 100, 835, 470), "questions": [353], "purpose": "Two transmitter block-diagram variants"},
    "q-354.png": {"page": 207, "baseDPI": 130, "crop": (130, 845, 835, 490), "questions": [354], "purpose": "Two transmitter block-diagram variants"},
    "q-355.png": {"page": 208, "baseDPI": 130, "crop": (125, 380, 835, 455), "questions": [355], "purpose": "Two transmitter block-diagram variants"},
    "q-406.png": {"page": 221, "baseDPI": 130, "crop": (125, 115, 525, 455), "questions": [406], "purpose": "Two linearity-test setup variants"},
    "q-407.png": {"page": 221, "baseDPI": 130, "crop": (125, 745, 445, 600), "questions": [407], "purpose": "Four two-tone waveform variants"},
}


def scaled(value: int, base_dpi: int) -> int:
    return round(value * OUTPUT_DPI / base_dpi)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, default=ROOT / "ExamSources" / "Справочник_КЭ.pdf")
    parser.add_argument("--output", type=Path, default=ROOT / "Content" / "diagrams" / "questions")
    args = parser.parse_args()
    if not args.reference.is_file():
        raise SystemExit(f"Reference PDF not found: {args.reference}")
    if shutil.which("pdftoppm") is None:
        raise SystemExit("pdftoppm is required")

    args.output.mkdir(parents=True, exist_ok=True)
    expected_files = set(ASSETS) | {"figure-manifest.json"}
    for stale in args.output.iterdir():
        if stale.is_file() and stale.name not in expected_files and stale.suffix == ".png":
            stale.unlink()

    question_entries = []
    for filename, spec in ASSETS.items():
        base_dpi = int(spec["baseDPI"])
        x, y, width, height = (scaled(value, base_dpi) for value in spec["crop"])
        target = args.output / filename
        subprocess.run([
            "pdftoppm", "-f", str(spec["page"]), "-l", str(spec["page"]),
            "-r", str(OUTPUT_DPI), "-png", "-singlefile",
            "-x", str(x), "-y", str(y), "-W", str(width), "-H", str(height),
            str(args.reference), str(target.with_suffix("")),
        ], check=True)
        if target.stat().st_size == 0:
            raise SystemExit(f"empty extracted asset: {target}")
        crop = {"baseDPI": base_dpi, "x": spec["crop"][0], "y": spec["crop"][1], "width": spec["crop"][2], "height": spec["crop"][3]}
        for number in spec["questions"]:
            question_entries.append({
                "examNumber": number,
                "sourceDocument": "Справочник_КЭ.pdf",
                "sourcePDFPage": spec["page"],
                "crop": crop,
                "asset": f"diagrams/questions/{filename}",
                "purpose": spec["purpose"],
                "visuallyInspected": True,
                "answerKeyExcluded": True,
            })

    manifest = {
        "schemaVersion": 1,
        "renderDPI": OUTPUT_DPI,
        "answerKeyExcluded": True,
        "questions": sorted(question_entries, key=lambda item: item["examNumber"]),
    }
    (args.output / "figure-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Extracted {len(ASSETS)} audited assets for {len(question_entries)} figure questions")


if __name__ == "__main__":
    main()
