#!/usr/bin/env python3
"""Fail-fast validation for the generated learning bank."""

import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
questions = json.loads((root / "Content/questions.json").read_text(encoding="utf-8"))
glossary = json.loads((root / "Content/glossary.json").read_text(encoding="utf-8"))
source_map = json.loads((root / "Content/source-map.json").read_text(encoding="utf-8"))
expected = set(range(1, 39)) | set(range(47, 99)) | set(range(100, 375)) | set(range(387, 427))
term_ids = {entry["id"] for entry in glossary}
banned = (
    "Если слова в формулировке незнакомы",
    "Сначала определите, что именно проверяет вопрос",
    "не соответствует правилу из экзаменационного банка",
)

assert len(questions) == 405, f"expected 405, got {len(questions)}"
assert {q["examNumber"] for q in questions} == expected
assert len({q["id"] for q in questions}) == 405
assert len(glossary) >= 120, f"glossary is too small: {len(glossary)}"
assert len(term_ids) == len(glossary), "duplicate glossary IDs"
assert set(source_map) == {q["id"] for q in questions}, "source map differs from bank"

for entry in glossary:
    for field in ("term", "shortDefinition", "fromZero", "radioExample"):
        assert entry.get(field, "").strip(), f"missing {field} in {entry['id']}"
    assert set(entry.get("relatedTerms", [])) <= term_ids, f"broken related term in {entry['id']}"

for q in questions:
    number = q["examNumber"]
    assert q["stem"].strip(), number
    assert 2 <= len(q["options"]) <= 6, number
    assert all(option["text"].strip() for option in q["options"]), number
    option_ids = {option["id"] for option in q["options"]}
    assert len(option_ids) == len(q["options"]), number
    assert q["correctOptionId"] in option_ids, number
    assert q["topic"].strip() and q["subtopic"].strip(), number
    for field in ("explanationShort", "explanationBeginner", "explanationReasoning", "memoryHint"):
        assert q[field].strip(), f"question {number}: missing {field}"
    assert len(q["explanationBeginner"]) >= 250, f"question {number}: beginner layer too short"
    assert len(q["explanationReasoning"]) >= 180, f"question {number}: reasoning layer too short"
    wrong_ids = option_ids - {q["correctOptionId"]}
    assert set(q["wrongOptionExplanations"]) == wrong_ids, f"question {number}: wrong-option map"
    assert all(len(value.strip()) >= 80 for value in q["wrongOptionExplanations"].values()), number
    assert set(q.get("glossaryTerms", [])) <= term_ids, f"question {number}: broken glossary ref"
    source = q["sourceReference"]
    assert source["sourceQuestionNumber"] == number
    assert source["page"] > 0 and source["explanationPage"] > 0
    assert source["document"] == "Справочник_КЭ.pdf"
    assert source["explanationDocument"] == "radiolyubitel_2_category_guide_2026.pdf"
    combined = " ".join(str(q.get(field, "")) for field in ("explanationBeginner", "explanationReasoning"))
    combined += " " + " ".join(q["wrongOptionExplanations"].values())
    assert not any(marker in combined for marker in banned), f"question {number}: legacy template"
    assert not re.search(r"\b(?:TODO|TBD|FIXME)\b", combined, re.I), number
    if q.get("figureAsset"):
        assert (root / "Content" / q["figureAsset"]).is_file(), q["figureAsset"]

print(f"Content integrity OK: {len(questions)} questions, {len(glossary)} glossary entries")
