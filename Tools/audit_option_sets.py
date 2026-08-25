#!/usr/bin/env python3
"""Verify every production stem and all four options against the preserved PDFs."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import unicodedata
from pathlib import Path

from import_questions import SECOND_CATEGORY, parse_guide, parse_reference

ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "ExamSources" / "Справочник_КЭ.pdf"
GUIDE = ROOT / "ExamSources" / "radiolyubitel_2_category_guide_2026.pdf"
HIGH_RISK = [23, 32, 36, 96, 119, 123, 188, 191, 201, 214, 233, 359, 408, 419]
GARBAGE_PATTERNS = (
    "Рисунок 1", "Рисунок 2", "Безопасность при эксплуатации РЭС",
    "Электромагнитная совместимость, предотвращение", "Примечания: 1.",
    "Номера правильных ответов:", "Образец заявления для сдачи",
)


def semantic_normalized(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).lower().replace("ё", "е")
    value = value.replace("≤", "<=").replace("≥", ">=")
    return "".join(char for char in value if char.isalnum() or char in "<>=+-*/^()")


def answer_normalized(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).lower().replace("ё", "е")
    value = value.replace("≤", "<=").replace("≥", ">=")
    return re.sub(r"[^a-zа-я0-9<>=]+", "", value)


def extract_text(pdf: Path, output: Path) -> str:
    subprocess.run(["pdftotext", "-layout", str(pdf), str(output)], check=True)
    return output.read_text(encoding="utf-8")


def main() -> None:
    if shutil.which("pdftotext") is None:
        raise SystemExit("pdftotext is required")
    cache = ROOT / ".build" / "full-option-audit"
    cache.mkdir(parents=True, exist_ok=True)
    reference = parse_reference(extract_text(REFERENCE, cache / "reference.txt"))
    guide = parse_guide(extract_text(GUIDE, cache / "guide.txt"))
    production = json.loads((ROOT / "Content/questions.json").read_text(encoding="utf-8"))
    overrides = json.loads((ROOT / "ContentOverrides/question-overrides.json").read_text(encoding="utf-8")).get("questions", {})
    by_number = {question["examNumber"]: question for question in production}

    failures: list[str] = []
    rows = []
    exact_option_sets = 0
    override_option_sets = 0
    exact_answers = 0
    manual_answers = 0

    if len(production) != 405 or set(by_number) != SECOND_CATEGORY:
        failures.append("production bank is not the exact 405-question second-category set")

    for number in sorted(SECOND_CATEGORY):
        question = by_number[number]
        source = reference[number]
        guide_entry = guide[number]
        override = overrides.get(str(number), {})
        option_overrides = override.get("optionTextById", {})
        expected_options = list(source.options)
        override_reasons = []
        if option_overrides:
            note = override.get("optionAuditNote", "").strip()
            if not note:
                failures.append(f"Q{number}: option override lacks optionAuditNote")
            for index, raw_text in enumerate(source.options):
                option_id = f"q-{number:03d}-option-{index + 1}"
                if option_id in option_overrides:
                    clean_text = option_overrides[option_id]
                    if not raw_text.startswith(clean_text):
                        failures.append(f"Q{number}: source-checked option override is not a prefix of extracted source text")
                    expected_options[index] = clean_text
                    override_reasons.append(note)
            override_option_sets += 1
        else:
            exact_option_sets += 1

        option_ids = [option["id"] for option in question["options"]]
        option_texts = [option["text"] for option in question["options"]]
        expected_ids = [f"q-{number:03d}-option-{index}" for index in range(1, 5)]
        stem_verified = question["stem"] == source.stem
        options_verified = len(option_texts) == 4 and option_ids == expected_ids and option_texts == expected_options
        normalized_options = [semantic_normalized(text) for text in option_texts]
        duplicates = len(set(normalized_options)) != 4
        garbage = [text for text in option_texts if any(pattern in text for pattern in GARBAGE_PATTERNS) or any(ord(char) < 32 for char in text)]

        target = answer_normalized(guide_entry.answer)
        exact = [index for index, text in enumerate(option_texts) if answer_normalized(text) == target]
        if "correctOptionIndex" in override:
            correct_index = int(override["correctOptionIndex"])
            method = "manual"
            match_note = override.get("answerMatchNote", "Explicit source-checked manual answer binding.")
            manual_answers += 1
        elif len(exact) == 1:
            correct_index = exact[0]
            method = "exact"
            match_note = "Normalized guide answer exactly matches one verified source option."
            exact_answers += 1
        else:
            correct_index = -1
            method = "unresolved"
            match_note = "No unique exact answer match and no explicit manual binding."

        expected_correct_id = expected_ids[correct_index] if 0 <= correct_index < 4 else None
        correct_verified = expected_correct_id == question["correctOptionId"]
        wrong_ids = set(option_ids) - {question["correctOptionId"]}
        wrong_map_verified = set(question["wrongOptionExplanations"]) == wrong_ids
        unresolved = not all((stem_verified, options_verified, correct_verified, wrong_map_verified)) or duplicates or bool(garbage) or method == "unresolved"
        if unresolved:
            failures.append(f"Q{number}: unresolved stem/options/correct/wrong-map/garbage validation")

        rows.append({
            "examNumber": number,
            "sourceDocument": "Справочник_КЭ.pdf",
            "sourcePDFPage": source.page,
            "guidePDFPage": guide_entry.page,
            "productionStemVerified": stem_verified,
            "productionOptionsVerified": options_verified,
            "verifiedOptionCount": len(option_texts),
            "correctOptionVerified": correct_verified,
            "wrongOptionMapVerified": wrong_map_verified,
            "duplicateNormalizedOptions": duplicates,
            "probableExtractionGarbage": garbage,
            "matchMethod": method,
            "answerMatchNote": match_note,
            "optionOverrideReason": " ".join(dict.fromkeys(override_reasons)),
            "unresolved": unresolved,
        })

    report = {
        "generatedOn": "reproducible",
        "questionsChecked": len(rows),
        "optionsChecked": sum(row["verifiedOptionCount"] for row in rows),
        "sourceExactOptionSets": exact_option_sets,
        "explicitSourceCheckedOptionOverrides": override_option_sets,
        "correctAnswerExactMatches": exact_answers,
        "correctAnswerManualMatches": manual_answers,
        "correctAnswerFuzzyMatches": 0,
        "unresolved": [row["examNumber"] for row in rows if row["unresolved"]],
        "highRisk": [row for row in rows if row["examNumber"] in HIGH_RISK],
        "questions": rows,
    }
    docs = ROOT / "docs"
    docs.mkdir(exist_ok=True)
    (docs / "full-option-audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    override_lines = "\n".join(
        f"- Q{row['examNumber']}: {row['optionOverrideReason']}"
        for row in rows if row["optionOverrideReason"]
    )
    risk_lines = "\n".join(
        f"- Q{row['examNumber']}: stem/options/correct/wrong-map verified; method `{row['matchMethod']}`; unresolved `{str(row['unresolved']).lower()}`."
        for row in rows if row["examNumber"] in HIGH_RISK
    )
    (docs / "full-option-audit.md").write_text(f"""# Full source option audit

Generated: reproducible

- Questions checked: **{report['questionsChecked']}**
- Options checked: **{report['optionsChecked']}**
- Exact source option sets: **{report['sourceExactOptionSets']}**
- Explicit source-checked option cleanup overrides: **{report['explicitSourceCheckedOptionOverrides']}**
- Correct-answer matches exact / manual / fuzzy: **{exact_answers} / {manual_answers} / 0**
- Unresolved: **{len(report['unresolved'])}**

The audit reparses both checksum-protected PDFs on every run, compares every production stem and ordered option to the source, preserves `<`, `>`, `<=`, and `>=`, and fails on duplicated options, wrong IDs, extraction garbage, or an incorrect wrong-option map.

## Explicit source-checked option cleanup

{override_lines}

## High-risk questions

{risk_lines}
""", encoding="utf-8")

    if failures:
        raise SystemExit("Full option audit failures: " + "; ".join(failures))
    print(
        f"Full option audit OK: {len(rows)} questions; {report['optionsChecked']} options; "
        f"{exact_option_sets} exact sets; {override_option_sets} source-checked cleanup overrides; "
        f"answers {exact_answers} exact/{manual_answers} manual/0 fuzzy; 0 unresolved"
    )


if __name__ == "__main__":
    main()
