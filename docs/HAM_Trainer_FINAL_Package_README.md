# HAM Trainer — Final Codex Handoff Package

This package is the final handoff for the current repository:

`https://github.com/Leo0742/HAM-Trainer.git`

Codex must start from the latest remote `main`. The repository, not any older
ZIP, is the source of truth for application code and official exam-bank content.

## Authoritative educational files

### 1. 405-question explanation layer

`HAM_Trainer_Second_Category_405_Authored_Explanations_FINAL.json`

SHA-256:

`d0f1a131f0495a1914f02a052e678bcbd471a6e1f884c0a5bc9f6a190b3c0253`

Coverage:

`1–38, 47–98, 100–374, 387–426` = **405 questions**.

Each record contains:

- `explanationShort`
- `explanationBeginner`
- `explanationReasoning`
- `wrongOptionExplanationsByText`
- `memoryHint`
- `glossaryTerms`

This file is **static authored content**. It must be merged into the app by
`examNumber` and must not be regenerated or paraphrased.

Wrong-option explanations are keyed by human-readable option text for safe
handoff. Codex must bind them to the app's stable option IDs after normalized,
unique text matching. It must never bind by displayed A/B/C/D or 1/2/3/4
position because answer order can be shuffled.

Known clean-text/source-extraction bindings: Q23, Q32, Q408, Q419.

The previous authored-source errors Q96/Q123/Q188/Q214 are fixed in this file.
After successful integration, remove the app-side
`WRONG_OPTION_AUTHORED_REPAIRS` workaround.

### 2. Built-in glossary educational layer

`HAM_Trainer_BuiltIn_Glossary_Content_FINAL.json`

SHA-256:

`f2b193c916ce5be64475e6e9cbb01a6f5348930fc4d51cfb494488ffff05bc4c`

Contains **176** concepts referenced by the final question explanations.

For existing glossary entries:

- preserve stable ID;
- preserve aliases;
- preserve relatedTerms;
- preserve diagramAsset;
- preserve all user-owned concept progress/notes;
- use the supplied authored `fromZero` text;
- do not generate `fromZero` using a common wrapper.

`shortDefinition` and `radioExample` are supplied as safe authored/fallback
content. If the current repository already has a better non-template short
definition/example, it may be preserved. The `fromZero` content in this package
is the authoritative beginner explanation.

If a referenced concept does not have a unique existing term/alias match,
create the minimal built-in glossary entry using the supplied record and a
stable new ID. Do not change personal glossary data.

## QA

See:

`HAM_Trainer_FINAL_Content_QA.md`

The QA includes:

- 405/405 authored question records;
- 1,215/1,215 wrong-option explanation records;
- zero correct-answer/wrong-map collisions;
- zero same-question duplicate wrong explanations;
- zero remaining known bad legacy boilerplate patterns;
- explicit high-risk, figure and calculation review sets;
- source-PDF hashes;
- 176/176 glossary concept coverage.

## Screenshots

The package includes the user's current UI screenshots under `Screenshots/`.
They are a **before** reference for the requested readability/layout fixes.

They show the key visual problems:

- text too small;
- study/mock content too narrow on a large desktop window;
- unnecessary blank space;
- weak-question empty state vertically awkward;
- All Questions master column too narrow;
- personal glossary editor cramped.

Do not pixel-copy the screenshots. Use them to verify that the final version is
clearly easier to read and uses the window better.

## Codex task

Use:

`CODEX_HAM_TRAINER_FINAL_COMPLETION_PROMPT_EN.txt`

The task intentionally separates responsibilities:

**Educational content is already supplied here. Codex must not rewrite it.**

Codex's remaining work is primarily:

- integrate these authored files;
- remove obsolete source-repair workarounds;
- improve UI readability/responsive width;
- add a persistent text-size setting;
- add safe Back/Forward navigation inside a study session;
- add `Были ошибки` and 1/3/5 intensive rounds to Weak Questions;
- preserve the existing question-distance scheduler;
- add regression tests;
- perform real visual QA;
- keep GitHub Actions green;
- open a PR and do not merge it automatically.

## Source PDFs

The complete PDFs already present in `ExamSources/` must remain byte-for-byte
unchanged.

Expected hashes:

- handbook / `Справочник_КЭ.pdf`:
  `8108c82eb316069167a7ae3e525a9991637e2f547f12fbbde637e684dbad55d7`
- 2026 study guide:
  `163c01bded0c4b5cee92892948f15eab32b226f6f0bd0edc70f0beecd6317749`

Do not replace the complete PDFs with cropped pages or derived figures.
