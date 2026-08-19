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

`Content/glossary.json` contains simple definitions, a from-zero explanation, aliases, and a real-radio example. `Content/topics.json` is a generated topic catalog. `Content/source-map.json` is a generated compact provenance index.

Mutable fields such as attempts, notes, bookmarks, intervals, and due dates are intentionally absent from content JSON and live in the progress store.

## Overrides

`ContentOverrides/question-overrides.json` is applied after PDF extraction and answer matching. It is the right place for a stable correction, historical/practice note, mnemonic, or an explicitly resolved source ambiguity. Do not edit generated JSON for a correction that must survive the next import.
