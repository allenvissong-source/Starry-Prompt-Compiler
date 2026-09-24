# Starry Prompt Compiler

Pure Dart package that compiles character, persona and worldbook material into prompts.

## Boundary

- Owns prompt assembly, worldbook recall (including BM25 ranking) and prompt profile models.
- Consumed by `starry` and by `starry_injection_service`.
- Contains no Flutter dependency and must stay platform-agnostic.

## Conventions

- Timestamps that are persisted or exchanged must use a single, explicit time semantics.
- Tests: `dart test` (177 cases as of 2026-09-19) must stay green; `dart analyze` must be clean.

## Known governance context (2026-09-19)

- Timestamp helpers are split between UTC and local-time semantics: 9 occurrences in this package
  (plus 6 in `starry_domain_entities`). Production writes local time without a `Z` suffix.
- Existing round-trip tests all feed `...Z` inputs, so they pass regardless of the defect.
- BM25 recall is wired on the injection path but the host application still calls the old signature.
