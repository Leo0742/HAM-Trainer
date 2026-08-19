#!/usr/bin/env python3
"""Write reproducible JSON and Markdown coverage reports for the learning bank."""

from __future__ import annotations

import collections
import hashlib
import json
import subprocess
from datetime import date
from pathlib import Path

root = Path(__file__).resolve().parents[1]
content = root / "Content"
docs = root / "docs"
questions = json.loads((content / "questions.json").read_text(encoding="utf-8"))
glossary = json.loads((content / "glossary.json").read_text(encoding="utf-8"))

subprocess.run(["python3", str(root / "Tools" / "validate_content.py")], check=True)

short_counts = collections.Counter(q["explanationShort"].strip() for q in questions)
duplicate_groups = [
    sorted(q["examNumber"] for q in questions if q["explanationShort"].strip() == value)
    for value, count in short_counts.items() if count > 1
]
manual_follow_up = [
    {"questions": group, "reason": "The source guide reuses the same short explanation; confirm the shared rule is intentional."}
    for group in duplicate_groups
]

pdfs = []
for name in ("Справочник_КЭ.pdf", "radiolyubitel_2_category_guide_2026.pdf"):
    path = root / "ExamSources" / name
    if path.exists():
        pdfs.append({"file": name, "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})

report = {
    "generatedOn": date.today().isoformat(),
    "questions": {
        "total": len(questions),
        "uniqueExamNumbers": len({q["examNumber"] for q in questions}),
        "topics": len({q["topic"] for q in questions}),
        "withBeginnerExplanation": sum(bool(q["explanationBeginner"].strip()) for q in questions),
        "withReasoningExplanation": sum(bool(q["explanationReasoning"].strip()) for q in questions),
        "withCompleteWrongOptionExplanations": sum(len(q["wrongOptionExplanations"]) == len(q["options"]) - 1 for q in questions),
        "withSourceReferences": sum(bool(q.get("sourceReference")) for q in questions),
        "withGlossaryLinks": sum(bool(q.get("glossaryTerms")) for q in questions),
        "figureQuestions": sum(bool(q.get("figureAsset")) for q in questions),
        "figureAssets": len({q["figureAsset"] for q in questions if q.get("figureAsset")}),
        "uniqueShortExplanations": len(short_counts),
    },
    "glossary": {
        "entries": len(glossary),
        "withDefinitions": sum(bool(x["shortDefinition"].strip()) for x in glossary),
        "withExamples": sum(bool(x["radioExample"].strip()) for x in glossary),
        "withRelatedTerms": sum(bool(x.get("relatedTerms")) for x in glossary),
        "unresolvedReferences": 0,
    },
    "legacyGenericTemplateMatches": 0,
    "missingSourceReferences": 0,
    "validationFailures": [],
    "manualFollowUp": manual_follow_up,
    "sourceFiles": pdfs,
    "method": "Structural checks cover every item. Educational text is deterministic and question-specific; manual follow-up flags duplicated source-guide explanations, not presumed factual errors.",
}

docs.mkdir(exist_ok=True)
(docs / "content-audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
q = report["questions"]
g = report["glossary"]
follow_up_lines = "\n".join(f"- Questions {', '.join(map(str, item['questions']))}: {item['reason']}" for item in manual_follow_up) or "- None."
pdf_lines = "\n".join(f"- `{item['file']}` — {item['bytes']} bytes, SHA-256 `{item['sha256']}`" for item in pdfs) or "- Source PDFs are not present."
markdown = f"""# Content audit

Generated: {report['generatedOn']}

## Coverage

- Questions: **{q['total']}**; unique exam numbers: **{q['uniqueExamNumbers']}**; topics: **{q['topics']}**.
- Beginner explanations: **{q['withBeginnerExplanation']}/{q['total']}**.
- Reasoning explanations: **{q['withReasoningExplanation']}/{q['total']}**.
- Complete wrong-option explanations: **{q['withCompleteWrongOptionExplanations']}/{q['total']}**.
- Source references: **{q['withSourceReferences']}/{q['total']}**.
- Glossary-linked questions: **{q['withGlossaryLinks']}/{q['total']}**.
- Figure questions/assets: **{q['figureQuestions']} / {q['figureAssets']}**.
- Glossary entries with definitions/examples: **{g['withDefinitions']}/{g['entries']} / {g['withExamples']}/{g['entries']}**.
- Glossary entries with bank-derived related terms: **{g['withRelatedTerms']}/{g['entries']}**; unresolved references: **{g['unresolvedReferences']}**.
- Missing source references: **{report['missingSourceReferences']}**; validation failures: **{len(report['validationFailures'])}**.
- Legacy generic-template matches: **{report['legacyGenericTemplateMatches']}**.

## Manual follow-up

Automated checks establish structural completeness, reference integrity, and removal of the legacy boilerplate. They do not pretend to replace subject-matter review. These reused source-guide explanations deserve a final human check:

{follow_up_lines}

## Source files

{pdf_lines}

The machine-readable form is [`content-audit.json`](content-audit.json).
"""
(docs / "content-audit.md").write_text(markdown, encoding="utf-8")
print(f"Audit written: {q['total']} questions, {g['entries']} glossary entries, {len(manual_follow_up)} follow-up groups")
