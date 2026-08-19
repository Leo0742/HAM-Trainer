#!/usr/bin/env python3
"""Fail-fast validation for the authored learning bank."""

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTHORED_PATH = ROOT / "ContentAuthored" / "second-category-405-explanations.json"
AUTHORED_SHA256 = "bbbbb344bc8f770a135bb380b7e8bd341ee1d4986d17f4ac502f4fdfd07159f8"
EXPECTED = set(range(1, 39)) | set(range(47, 99)) | set(range(100, 375)) | set(range(387, 427))


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower().replace("ё", "е"))


def main() -> None:
    questions = json.loads((ROOT / "Content/questions.json").read_text(encoding="utf-8"))
    glossary = json.loads((ROOT / "Content/glossary.json").read_text(encoding="utf-8"))
    source_map = json.loads((ROOT / "Content/source-map.json").read_text(encoding="utf-8"))
    raw = json.loads((ROOT / "ContentRaw/questions-imported.json").read_text(encoding="utf-8"))
    authored_bytes = AUTHORED_PATH.read_bytes()
    assert hashlib.sha256(authored_bytes).hexdigest() == AUTHORED_SHA256, "authored JSON checksum"
    authored = json.loads(authored_bytes)["questions"]

    assert len(questions) == len(authored) == 405
    assert {q["examNumber"] for q in questions} == {int(number) for number in authored} == EXPECTED
    assert len({q["id"] for q in questions}) == 405
    assert all(len(q["options"]) == 4 for q in questions), "every question must have four official options"
    assert set(source_map) == {q["id"] for q in questions}, "source map differs from bank"

    term_ids = {entry["id"] for entry in glossary}
    assert len(term_ids) == len(glossary), "duplicate glossary IDs"
    identical_beginner = []
    for entry in glossary:
        for field in ("term", "shortDefinition", "fromZero", "radioExample"):
            assert entry.get(field, "").strip(), f"missing {field} in {entry['id']}"
        assert set(entry.get("relatedTerms", [])) <= term_ids, f"broken related term in {entry['id']}"
        if normalized(entry["shortDefinition"]) == normalized(entry["fromZero"]):
            identical_beginner.append(entry["id"])
        if entry.get("diagramAsset"):
            assert (ROOT / "Content" / entry["diagramAsset"]).is_file(), entry["diagramAsset"]
    assert not identical_beginner, f"glossary fromZero duplicates: {identical_beginner}"

    raw_by_number = {q["examNumber"]: q for q in raw}
    for question in questions:
        number = question["examNumber"]
        record = authored[str(number)]
        baseline = raw_by_number[number]
        assert question["stem"] == baseline["stem"], f"question {number}: official stem changed"
        assert question["options"] == baseline["options"], f"question {number}: official options changed"
        option_ids = {option["id"] for option in question["options"]}
        assert question["correctOptionId"] in option_ids, f"question {number}: correct option"
        assert set(question["wrongOptionExplanations"]) == option_ids - {question["correctOptionId"]}, f"question {number}: wrong-option map"
        assert len(question["wrongOptionExplanations"]) == 3
        assert all(value.strip() for value in question["wrongOptionExplanations"].values())
        for field in ("explanationShort", "explanationBeginner", "explanationReasoning", "memoryHint"):
            assert question[field] == record[field], f"question {number}: authored {field} changed"
        assert set(question.get("glossaryTerms", [])) <= term_ids, f"question {number}: glossary reference"
        if question.get("figureAsset"):
            assert (ROOT / "Content" / question["figureAsset"]).is_file(), question["figureAsset"]
        if question.get("teachingDiagramAsset"):
            assert (ROOT / "Content" / question["teachingDiagramAsset"]).is_file(), question["teachingDiagramAsset"]
        if question.get("useExamFigure"):
            assert question.get("figureAsset"), f"question {number}: requested exam figure"
        source = question["sourceReference"]
        assert source["sourceQuestionNumber"] == number and source["page"] > 0 and source["explanationPage"] > 0

    print(
        f"Content integrity OK: {len(questions)} questions; {len(authored)} authored; "
        f"0 fallback; {len(glossary)} glossary; {len(identical_beginner)} identical fromZero"
    )


if __name__ == "__main__":
    main()
