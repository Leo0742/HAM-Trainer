#!/usr/bin/env python3
"""Write honest structural, curated-coverage, source, and asset audit reports."""

from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "Content"
DOCS = ROOT / "docs"
REQUIRED_CURATED = {
    "explanationShort", "explanationBeginner", "explanationReasoning",
    "wrongOptionExplanations", "memoryHint", "glossaryTerms",
}
EXPECTED_SOURCE_HASHES = {
    "Справочник_КЭ.pdf": "8108c82eb316069167a7ae3e525a9991637e2f547f12fbbde637e684dbad55d7",
    "radiolyubitel_2_category_guide_2026.pdf": "163c01bded0c4b5cee92892948f15eab32b226f6f0bd0edc70f0beecd6317749",
}
GENERIC_MARKERS = (
    "Этот вариант не соответствует правилу",
    "Нужно сравнить варианты и выбрать правильный",
    "Это число не следует из условия",
    "Другой ответ меняет ключевой признак",
    "утверждает иной признак, назначение или причинную связь",
    "предлагает другое разрешение, обязанность или область применения",
)


def load_curated() -> tuple[dict[str, dict], list[str]]:
    result: dict[str, dict] = {}
    files = []
    for path in sorted((ROOT / "ContentOverrides").glob("questions-*.json")):
        files.append(str(path.relative_to(ROOT)))
        payload = json.loads(path.read_text(encoding="utf-8")).get("questions", {})
        overlap = set(result).intersection(payload)
        if overlap:
            raise AssertionError(f"duplicate curated IDs in {path}: {sorted(overlap)}")
        result.update(payload)
    return result, files


def main() -> None:
    subprocess.run(["python3", str(ROOT / "Tools" / "validate_content.py")], check=True)
    subprocess.run(["python3", str(ROOT / "Tools" / "audit_answer_matches.py")], check=True)

    questions = json.loads((CONTENT / "questions.json").read_text(encoding="utf-8"))
    raw = json.loads((ROOT / "ContentRaw" / "questions-imported.json").read_text(encoding="utf-8"))
    glossary = json.loads((CONTENT / "glossary.json").read_text(encoding="utf-8"))
    answer_audit = json.loads((DOCS / "answer-match-audit.json").read_text(encoding="utf-8"))
    curated, curated_files = load_curated()
    by_number = {q["examNumber"]: q for q in questions}
    raw_by_number = {q["examNumber"]: q for q in raw}
    curated_numbers = {int(number) for number in curated}
    bank_numbers = set(by_number)

    unchanged_stems = sum(by_number[n]["stem"] == raw_by_number[n]["stem"] for n in bank_numbers)
    unchanged_options = sum(by_number[n]["options"] == raw_by_number[n]["options"] for n in bank_numbers)
    resolved_correct_ids = sum(any(option["id"] == q["correctOptionId"] for option in q["options"]) for q in questions)
    curated_wrong = sum(
        n in curated_numbers
        and set(curated[str(n)].get("wrongOptionExplanations", {}))
        == {option["id"] for option in by_number[n]["options"] if option["id"] != by_number[n]["correctOptionId"]}
        for n in bank_numbers
    )
    fallback = sorted(bank_numbers - curated_numbers)

    term_ids = {entry["id"] for entry in glossary}
    unresolved_glossary = sorted(set(term for q in questions for term in q.get("glossaryTerms", [])) - term_ids)
    original_assets = sorted({q["figureAsset"] for q in questions if q.get("figureAsset")})
    teaching_assets = sorted({entry["diagramAsset"] for entry in glossary if entry.get("diagramAsset")})
    missing_assets = sorted(asset for asset in original_assets + teaching_assets if not (CONTENT / asset).is_file())
    generic_matches = sorted({
        q["examNumber"] for q in questions
        if any(marker in " ".join([
            q["explanationBeginner"], q["explanationReasoning"],
            *q["wrongOptionExplanations"].values(),
        ]) for marker in GENERIC_MARKERS)
    })

    source_files = []
    for name in ("Справочник_КЭ.pdf", "radiolyubitel_2_category_guide_2026.pdf"):
        path = ROOT / "ExamSources" / name
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        source_files.append({"file": name, "bytes": path.stat().st_size, "sha256": digest, "unchanged": digest == EXPECTED_SOURCE_HASHES[name]})

    report = {
        "generatedOn": "reproducible",
        "structural": {
            "totalQuestions": len(questions),
            "uniqueExamNumbers": len(bank_numbers),
            "resolvedCorrectOptionIds": resolved_correct_ids,
            "unchangedOfficialStems": unchanged_stems,
            "unchangedOfficialOptionSets": unchanged_options,
            "withBeginnerExplanation": sum(bool(q["explanationBeginner"].strip()) for q in questions),
            "withReasoningExplanation": sum(bool(q["explanationReasoning"].strip()) for q in questions),
            "withCompleteWrongOptionExplanations": sum(len(q["wrongOptionExplanations"]) == len(q["options"]) - 1 for q in questions),
            "withSourceReferences": sum(bool(q.get("sourceReference")) for q in questions),
            "unresolvedGlossaryReferences": unresolved_glossary,
            "missingDiagramAssets": missing_assets,
            "genericBoilerplateQuestionIds": generic_matches,
        },
        "curated": {
            "overrideFiles": curated_files,
            "explicitQuestionRecords": len(curated_numbers),
            "explicitBeginnerExplanations": sum("explanationBeginner" in value for value in curated.values()),
            "explicitReasoningExplanations": sum("explanationReasoning" in value for value in curated.values()),
            "explicitWrongOptionSets": curated_wrong,
            "recordsWithEveryRequiredField": sum(REQUIRED_CURATED <= set(value) for value in curated.values()),
            "fallbackQuestionIds": fallback,
            "requiresManualReview": [],
            "method": "Curated means an explicit committed per-question override record. Fallback-generated text is excluded from all curated counts. Counts do not claim an automated factual-quality score.",
        },
        "answerMatching": {
            "exact": answer_audit["exact"], "manual": answer_audit["manual"],
            "unresolvedFuzzy": answer_audit["fuzzy"], "unresolved": answer_audit["unresolved"],
        },
        "glossary": {
            "entries": len(glossary),
            "withDefinitions": sum(bool(entry["shortDefinition"].strip()) for entry in glossary),
            "withExamples": sum(bool(entry["radioExample"].strip()) for entry in glossary),
        },
        "assets": {"originalExamFigures": len(original_assets), "additionalTeachingDiagrams": len(teaching_assets)},
        "documentedSourceConflicts": [
            {"question": 201, "note": "Guide says U or E; official options contain U. Explicit source match selects U and the in-app historical note preserves the discrepancy."}
        ],
        "sourceFiles": source_files,
    }

    failures = []
    if len(questions) != 405 or len(bank_numbers) != 405: failures.append("question count")
    if unchanged_stems != 405 or unchanged_options != 405: failures.append("official wording/options changed")
    if resolved_correct_ids != 405: failures.append("unresolved correctOptionId")
    if fallback or report["curated"]["recordsWithEveryRequiredField"] != 405 or curated_wrong != 405: failures.append("curated coverage")
    if answer_audit["fuzzy"] or answer_audit["unresolved"]: failures.append("answer matching")
    if unresolved_glossary or missing_assets: failures.append("references/assets")
    if generic_matches: failures.append("generic boilerplate")
    if not all(item["unchanged"] for item in source_files): failures.append("source PDF hash")
    report["failures"] = failures

    DOCS.mkdir(exist_ok=True)
    (DOCS / "content-audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    s, c, a, g = report["structural"], report["curated"], report["assets"], report["glossary"]
    source_lines = "\n".join(f"- `{item['file']}` — {item['bytes']} bytes; SHA-256 `{item['sha256']}`" for item in source_files)
    markdown = f"""# Content audit

Generated: {report['generatedOn']}

## Structural checks

- Questions / unique exam numbers: **{s['totalQuestions']} / {s['uniqueExamNumbers']}**.
- Resolved correct options: **{s['resolvedCorrectOptionIds']}/405**.
- Official stems and option sets unchanged from `ContentRaw`: **{s['unchangedOfficialStems']}/405** and **{s['unchangedOfficialOptionSets']}/405**.
- Structurally complete beginner / reasoning / wrong-option fields: **{s['withBeginnerExplanation']}/405**, **{s['withReasoningExplanation']}/405**, **{s['withCompleteWrongOptionExplanations']}/405**.
- Source references: **{s['withSourceReferences']}/405**; unresolved glossary references: **{len(s['unresolvedGlossaryReferences'])}**; missing assets: **{len(s['missingDiagramAssets'])}**.
- Questions matching known generic-boilerplate phrases: **{len(s['genericBoilerplateQuestionIds'])}**.

## Explicit curated coverage

- Explicit question records: **{c['explicitQuestionRecords']}/405**.
- Curated beginner explanations: **{c['explicitBeginnerExplanations']}/405**.
- Curated reasoning explanations: **{c['explicitReasoningExplanations']}/405**.
- Curated wrong-option sets: **{c['explicitWrongOptionSets']}/405**.
- Records with all required curated fields: **{c['recordsWithEveryRequiredField']}/405**.
- Production questions using fallback text: **{len(c['fallbackQuestionIds'])}**.

“Curated” means an explicit committed per-question override. Fallback text is not counted. The audit intentionally does not invent an automated educational-quality score.

## Answer matching and assets

- Exact / explicit manual / unresolved fuzzy answer matches: **{answer_audit['exact']} / {answer_audit['manual']} / {answer_audit['fuzzy']}**.
- Glossary entries: **{g['entries']}**.
- Original exam figures: **{a['originalExamFigures']}**; additional teaching diagrams: **{a['additionalTeachingDiagrams']}**.
- Documented source conflicts: **{len(report['documentedSourceConflicts'])}** (question 201).

## Preserved source files

{source_lines}

Machine-readable details: [`content-audit.json`](content-audit.json) and [`answer-match-audit.json`](answer-match-audit.json).
"""
    (DOCS / "content-audit.md").write_text(markdown, encoding="utf-8")
    if failures: raise SystemExit(f"Content audit failures: {failures}")
    print(f"Content audit OK: 405 structural; 405 curated; {answer_audit['fuzzy']} fuzzy; {a['additionalTeachingDiagrams']} teaching diagrams")


if __name__ == "__main__":
    main()
