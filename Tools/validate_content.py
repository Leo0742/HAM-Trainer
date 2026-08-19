#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
questions = json.loads((root / "Content/questions.json").read_text(encoding="utf-8"))
expected = set(range(1, 39)) | set(range(47, 99)) | set(range(100, 375)) | set(range(387, 427))
assert len(questions) == 405, f"expected 405, got {len(questions)}"
assert {q["examNumber"] for q in questions} == expected
assert len({q["id"] for q in questions}) == 405
for q in questions:
    assert q["options"], q["examNumber"]
    assert all(option["text"].strip() for option in q["options"]), q["examNumber"]
    ids = {option["id"] for option in q["options"]}
    assert q["correctOptionId"] in ids, q["examNumber"]
    assert q["topic"].strip(), q["examNumber"]
    assert q["explanationShort"].strip() and q["explanationBeginner"].strip() and q["explanationReasoning"].strip(), q["examNumber"]
    if q.get("figureAsset"):
        assert (root / "Content" / q["figureAsset"]).is_file(), q["figureAsset"]
print(f"Content integrity OK: {len(questions)} questions")
