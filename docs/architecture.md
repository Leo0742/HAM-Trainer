# Architecture

HAM Trainer is a native SwiftUI macOS application. It is fully local and has no networking layer.

## Boundaries

- `Content/` is immutable study material bundled with the application.
- `QuestionProgress` and `ProgressBackup` are mutable user data stored in Application Support.
- `AdaptiveReviewScheduler` contains deterministic scheduling and queue composition.
- `StudySession` owns same-session delayed reinsertion and summary counts.
- `AppStore` is the main-actor persistence boundary and autosaves each mutation atomically.
- SwiftUI views consume `AppStore` through the environment and never modify question JSON.

The separation means a content update can replace or correct questions without replacing learning history. Progress keys use stable question IDs, while correct answers use stable option IDs rather than display letters or indexes.

## Main flows

`SmartStudyView` asks the scheduler for a balanced queue. `StudyRunnerView` records an attempt, updates long-term scheduling through `AppStore`, and tells `StudySession` whether to add a delayed repeat. Answer order is randomized only at presentation time.

`MockExamView` samples 30 unique questions uniformly from the complete bank, suppresses explanations until completion, applies the 25/30 threshold, and records failed questions into adaptive progress.

`QuestionBrowserView` performs in-memory local search across numbers, stems, options, topics, and explanations. The bank is small enough that indexing would add complexity without measurable benefit.

## Persistence

`ProgressBackup` currently has schema version 1. Dates use ISO 8601. Writes use `Data.write(..., .atomic)`. The source content is never mutated. Export and import use native save/open panels. Future migrations should decode the prior version, transform in memory, and write the current schema only after a successful conversion.

## Privacy and platform

The target is arm64 macOS 14+. It uses SwiftUI, AppKit panels, Combine observation, Foundation Codable/FileManager, and no third-party libraries. There are no entitlements for network, microphone, contacts, location, or telemetry.
