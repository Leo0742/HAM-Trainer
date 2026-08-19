# Content format

`Content/questions.json` is an array of immutable `Question` objects.

Important fields:

- `id`: stable internal ID such as `q-136`;
- `examNumber`: official bank number;
- `options`: objects with stable IDs and exact source wording;
- `correctOptionId`: points to an option ID, never an answer letter;
- `officialCorrectAnswerText`: official semantic answer from the newer guide;
- `topic`, `subtopic`, `type`;
- four explanation layers plus wrong-option explanations and a memory hint;
- linked glossary IDs;
- optional local `figureAsset`;
- `sourceReference` with both documents and pages;
- optional `legalHistoricalNote`, separate from the official bank answer.

`Content/glossary.json` contains a short definition, from-zero explanation, aliases, a real-radio example, related-term IDs, and an optional teaching diagram. `Content/topics.json` is a generated topic catalog. `Content/source-map.json` is a generated compact provenance index.

Mutable fields such as attempts, notes, bookmarks, review stage, completed study step, next-due study step, concept state, and personal glossary entries are intentionally absent from content JSON and live in the progress store.

## Overrides

`ContentRaw/questions-imported.json` is the immutable handoff from PDF extraction. `ContentOverrides/questions-*.json` contains an explicit six-field educational record for every question; these files, not fallback output, define curated coverage. `Tools/build_content.py` assembles those records and applies `ContentOverrides/question-overrides.json` last for source corrections, historical notes, and explicitly resolved ambiguities. Do not edit generated `Content/questions.json` for a correction that must survive the next import.
