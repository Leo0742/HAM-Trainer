# HAM Exam UX audit

## Inspection result

The application was located at `/Applications/HAM Exam.app`. macOS identified its visible product name and LaunchServices identifier, but the embedded application could not be opened on this Apple Silicon/macOS installation. LaunchServices returned `kLSExecutableIncorrectFormat: No compatible executable was found` for its wrapped executable. Automated accessibility inspection therefore could not reach a question screen, settings, navigation, keyboard behavior, progress, or diagrams.

No decompilation, database reading, asset extraction, protection bypass, or source inspection was performed. The app was treated only as a requested launch target. This limitation did not block HAM Trainer implementation.

## Concepts retained independently

The useful baseline for any desktop exam trainer remains a visually dominant question, restrained chrome, persistent progress context, explicit answer feedback, and quick navigation. HAM Trainer implements those concepts with native macOS patterns rather than copying the unavailable product.

## Problems HAM Trainer is designed to solve

- Random drilling that repeatedly serves mastered material.
- No distinction between a guess and an honest “I don't know.”
- Correct-answer feedback without a beginner explanation.
- Memorization of answer positions.
- Immediate, irritating repetition after an error.
- Progress that cannot be exported or inspected by topic.
- Diagrams presented without provenance or scalable navigation.
- Legal/historical bank answers silently mixed with current-practice notes.

These gaps are addressed through adaptive state, stable option IDs, delayed repeats, layered explanations, glossary cards, local backup, topic statistics, and separate official/practice fields.
