# Testing and visual verification

## Automated tests

Run `Tools/run_tests.sh`. It compiles the production model, scheduler, session, and persistence files directly into a native arm64 test executable. The installed Command Line Tools package lacks XCTest and Swift Testing, so the runner deliberately has no testing-framework dependency.

The ten core tests cover:

1. failed items do not repeat immediately;
2. normal sessions cap repeat appearances;
3. correct spaced reviews expand intervals and eventually master;
4. a lapse removes mastery;
5. weak items recover after successful reviews;
6. “Не знаю” and reveal-before-answer are distinct failures;
7. mastered maintenance remains rare;
8. mock exams contain 30 unique bank questions and use 25/30;
9. progress survives restart and export/import;
10. the decoded content bank satisfies integrity rules.

`Tools/validate_content.py` independently fails on an incorrect count/range, duplicate IDs, missing choices, invalid correct option IDs, missing topics/explanations, or missing figures.

Latest result: **10/10 core tests passed; content integrity OK: 405 questions.** The release binary is arm64 Mach-O, and the final application passes `codesign --verify --deep --strict` with an ad-hoc local signature.

## Visual QA

The release application was launched through macOS LaunchServices. The system's accessibility screenshot service crashed when reading this SwiftUI window, so an inert `--snapshot` production-view hook was used for deterministic visual QA. It renders the exact application views and does nothing in ordinary launches.

Inspected snapshots:

- 1180×780 light dashboard;
- 900×620 dark Smart Study;
- 900×620 light long legal/procedural question;
- 1180×900 dark diagram question with a large source figure.

The first forced-appearance snapshot revealed stale appearance colors. The root snapshot scheme and adaptive answer-card fills were corrected, rebuilt, and rerendered. Final inspection found readable hierarchy, wrapped long text, adaptive colors, visible scrollbars, non-clipped controls, and legible figures.
