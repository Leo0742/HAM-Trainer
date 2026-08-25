#!/usr/bin/env python3
"""Fail-fast validation for the authored learning bank."""

import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUTHORED_PATH = ROOT / "ContentAuthored" / "second-category-405-explanations.json"
AUTHORED_SHA256 = "f069523c53b9f9e8658d01ee550335c5d8407486f93eab4979a58b9aa4e9975f"
GLOSSARY_AUTHORED_PATH = ROOT / "ContentAuthored" / "built-in-glossary-176.json"
GLOSSARY_AUTHORED_SHA256 = "2d3902bb049064066bc71766405237ab7ab39cc7b2b123de249700a1230bc1d3"
EXPECTED = set(range(1, 39)) | set(range(47, 99)) | set(range(100, 375)) | set(range(387, 427))
REQUIRED_FIGURES = {
    32: "diagrams/questions/q-032.png",
    **{number: f"diagrams/questions/q-{number:03d}.png" for number in range(136, 143)},
    **{number: "diagrams/questions/fm-transmitter.png" for number in range(173, 177)},
    **{number: "diagrams/questions/superhet-receiver.png" for number in range(177, 181)},
    263: "diagrams/questions/q-263.png",
    **{number: f"diagrams/questions/q-{number:03d}.png" for number in (322, 323, 326, 327, 328, 331, 332)},
    **{number: f"diagrams/questions/q-{number:03d}.png" for number in range(341, 345)},
    **{number: f"diagrams/questions/q-{number:03d}.png" for number in range(353, 356)},
    406: "diagrams/questions/q-406.png",
    407: "diagrams/questions/q-407.png",
}


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower().replace("ё", "е"))


def main() -> None:
    questions = json.loads((ROOT / "Content/questions.json").read_text(encoding="utf-8"))
    glossary = json.loads((ROOT / "Content/glossary.json").read_text(encoding="utf-8"))
    source_map = json.loads((ROOT / "Content/source-map.json").read_text(encoding="utf-8"))
    raw = json.loads((ROOT / "ContentRaw/questions-imported.json").read_text(encoding="utf-8"))
    overrides = json.loads((ROOT / "ContentOverrides/question-overrides.json").read_text(encoding="utf-8")).get("questions", {})
    authored_bytes = AUTHORED_PATH.read_bytes()
    assert hashlib.sha256(authored_bytes).hexdigest() == AUTHORED_SHA256, "authored JSON checksum"
    authored = json.loads(authored_bytes)["questions"]
    glossary_authored_bytes = GLOSSARY_AUTHORED_PATH.read_bytes()
    assert hashlib.sha256(glossary_authored_bytes).hexdigest() == GLOSSARY_AUTHORED_SHA256, "authored glossary JSON checksum"
    glossary_authored = json.loads(glossary_authored_bytes)["entries"]

    assert len(questions) == len(authored) == 405
    assert {q["examNumber"] for q in questions} == {int(number) for number in authored} == EXPECTED
    assert len({q["id"] for q in questions}) == 405
    assert all(len(q["options"]) == 4 for q in questions), "every question must have four official options"
    assert set(source_map) == {q["id"] for q in questions}, "source map differs from bank"

    assert len(glossary) == len(glossary_authored) == 176, "authored glossary coverage"
    term_ids = {entry["id"] for entry in glossary}
    assert len(term_ids) == len(glossary), "duplicate glossary IDs"
    authored_by_term = {entry["term"]: entry for entry in glossary_authored}
    assert len(authored_by_term) == 176, "duplicate authored glossary terms"
    identical_beginner = []
    for entry in glossary:
        for field in ("term", "shortDefinition", "fromZero", "radioExample"):
            assert entry.get(field, "").strip(), f"missing {field} in {entry['id']}"
        assert set(entry.get("relatedTerms", [])) <= term_ids, f"broken related term in {entry['id']}"
        if normalized(entry["shortDefinition"]) == normalized(entry["fromZero"]):
            identical_beginner.append(entry["id"])
        source = authored_by_term[entry["term"]]
        for field in ("shortDefinition", "fromZero", "radioExample"):
            assert entry[field] == source[field], f"authored glossary {field} changed: {entry['term']}"
        if entry.get("diagramAsset"):
            assert (ROOT / "Content" / entry["diagramAsset"]).is_file(), entry["diagramAsset"]
    # Equality is allowed only when it is present in the checksum-verified
    # authored source; the builder must not generate a wrapper or fallback.

    raw_by_number = {q["examNumber"]: q for q in raw}
    for question in questions:
        number = question["examNumber"]
        record = authored[str(number)]
        baseline = raw_by_number[number]
        assert question["stem"] == baseline["stem"], f"question {number}: official stem changed"
        expected_options = baseline["options"]
        option_text = overrides.get(str(number), {}).get("optionTextById", {})
        if option_text:
            expected_options = [
                {**option, "text": option_text.get(option["id"], option["text"])}
                for option in expected_options
            ]
        assert question["options"] == expected_options, f"question {number}: official options changed outside a source-checked override"
        assert not any(pattern in option["text"] for option in question["options"] for pattern in (
            "Рисунок 1", "Рисунок 2", "Безопасность при эксплуатации РЭС",
            "Электромагнитная совместимость, предотвращение", "Примечания: 1.",
        )), f"question {number}: source extraction garbage leaked into answer options"
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

    known_bindings = {
        23: ("q-023-option-4", "RL3DX"),
        32: ("q-032-option-4", "Лицензию HAREC."),
        408: ("q-408-option-4", "Для измерения текущего значения выходной мощности."),
        419: ("q-419-option-4", "Только углекислотные огнетушители."),
        426: ("q-426-option-4", "14 МГц."),
    }
    for number, (option_id, authored_text) in known_bindings.items():
        question = next(question for question in questions if question["examNumber"] == number)
        assert question["wrongOptionExplanations"][option_id] == authored[str(number)]["wrongOptionExplanationsByText"][authored_text]

    by_number = {question["examNumber"]: question for question in questions}
    assert {number: by_number[number].get("figureAsset") for number in REQUIRED_FIGURES} == REQUIRED_FIGURES
    assert {question["examNumber"] for question in questions if question.get("figureAsset")} == set(REQUIRED_FIGURES)
    manifest_path = ROOT / "Content/diagrams/questions/figure-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest_by_number = {item["examNumber"]: item for item in manifest["questions"]}
    assert set(manifest_by_number) == set(REQUIRED_FIGURES), "figure manifest question set"
    assert manifest.get("answerKeyExcluded") is True
    expected_files = {ROOT / "Content" / asset for asset in set(REQUIRED_FIGURES.values())}
    actual_files = set((ROOT / "Content/diagrams/questions").glob("*.png"))
    assert actual_files == expected_files, "unexplained extra or missing source figure asset"
    for number, asset in REQUIRED_FIGURES.items():
        item = manifest_by_number[number]
        assert item["asset"] == asset and item["visuallyInspected"] is True and item["answerKeyExcluded"] is True
        assert item["sourceDocument"] == "Справочник_КЭ.pdf" and item["sourcePDFPage"] > 0
        assert set(item["crop"]) == {"baseDPI", "x", "y", "width", "height"}
        path = ROOT / "Content" / asset
        assert path.stat().st_size > 0
        with path.open("rb") as stream:
            header = stream.read(24)
        assert header[:8] == b"\x89PNG\r\n\x1a\n"
        width, height = struct.unpack(">II", header[16:24])
        assert width >= 300 and height >= 150, f"implausibly small figure {number}: {width}x{height}"

    print(
        f"Content integrity OK: {len(questions)} questions; {len(authored)} authored; "
        f"0 fallback; {len(glossary)} glossary; {len(identical_beginner)} authored-identical fromZero"
    )


if __name__ == "__main__":
    main()
