# HAM Trainer — authored educational content package

This file accompanies `HAM_Trainer_Second_Category_405_Authored_Explanations.json`.

## Purpose

The JSON is the educational source layer for the 405 second-category exam questions used by HAM Trainer. It is intended to replace template-generated beginner/reasoning/wrong-option text.

The official question stems, official options, correct option IDs, exam figures, and source PDFs are **not** replaced by this package.

## Covered exam numbers

Exactly 405 records:

- 1–38
- 47–98
- 100–374
- 387–426

## Per-question fields

- `explanationShort` — concise exam-focused explanation.
- `explanationBeginner` — explanation from zero, defining needed terms before using them.
- `explanationReasoning` — how to reason from the question to the correct answer.
- `wrongOptionExplanationsByText` — three explanations, one for each wrong option, keyed by clean option text rather than displayed A/B/C/D.
- `memoryHint` — short memory anchor.
- `glossaryTerms` — human-readable glossary concepts that should be mapped to the app's stable glossary IDs/aliases.
- `teachingDiagramKey` — optional teaching diagram suggestion.
- `useExamFigure` — optional marker that the original exam figure is important.
- `sourceExtractionNote` — present only where PDF extraction required special care.

## Integration rules

1. Map question records by `examNumber`.
2. Preserve the official stems/options/correct answer already present in HAM Trainer.
3. Map `wrongOptionExplanationsByText` to stable option IDs using normalized exact text; never bind explanations to displayed letters because the app can shuffle options.
4. Questions 23 and 32 had table/figure text appended to one option by PDF extraction. This package already uses the clean intended option keys (`RL3DX` and `Лицензию HAREC.`); reconcile them against the current official bank rather than reintroducing PDF table text.
5. `glossaryTerms` contains human-readable names, not guaranteed internal IDs. Resolve them against existing glossary `term`/`aliases`; add a missing built-in concept only when truly needed.
6. Treat this package as immutable authored source data. Build/CI may validate and merge it, but must not paraphrase, regenerate, rotate templates, or overwrite it.
7. Do not use `Tools/curate_content.py` (or equivalent generic text generation) to recreate these explanations.

## Source integrity

The package was prepared against these preserved source files:

- study guide SHA-256: `163c01bded0c4b5cee92892948f15eab32b226f6f0bd0edc70f0beecd6317749`
- official handbook SHA-256: `8108c82eb316069167a7ae3e525a9991637e2f547f12fbbde637e684dbad55d7`

## QA performed before handoff

- exactly 405 expected exam numbers;
- all required educational fields non-empty;
- exactly three wrong-option explanations per question;
- no legacy generic filler markers;
- no duplicate exact beginner/reasoning records;
- PDF table text removed from wrong-option mapping keys for questions 23 and 32;
- targeted review of calculations, receiver/transmitter theory, antennas, propagation, electronics, operational procedure, and safety sections;
- explicit exam-bank caveat for question 148 (FM span convention);
- explicit physical caveat for question 317 (`Q ≈ X/Rloss`).

This package is educational content only. The application's answer mapping audit (`400 exact + 5 manual + 0 fuzzy`) remains the authority for binding the official correct option in the existing repository.
