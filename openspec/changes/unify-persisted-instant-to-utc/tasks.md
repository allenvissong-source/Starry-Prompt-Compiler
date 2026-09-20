## 1. Re-establish the inventory

- [~] 1.1 Re-grep this package for `toIso8601String` and confirm the 7 serialization sites and which 3 already carry `.toUtc()`: `character_entities.dart:184-185,234-235`, `worldbook_entities.dart:114-115` (UTC) vs `prompt_profile.dart:98-99`, `prompt_manager.dart:905-906`, `regex_profile.dart:133-134`, `regex_script.dart:257-258` (not)
- [~] 1.2 Re-confirm the construction sites feeding the non-UTC serializers: `prompt_profile.dart:46,49`, `prompt_manager.dart:867,868`, `regex_profile.dart:92,95`, `regex_script.dart:122,125` — all bare `DateTime.now()`, i.e. local
- [~] 1.3 Confirm `starry_character_card_codec` and `starry_injection_service` still have zero occurrences, so the blast radius stays two packages
- [~] 1.4 Record the baseline: `dart analyze` clean, `dart test` at 216 cases, `dart format --set-exit-if-changed .` clean

## 2. Make the existing coverage capable of failing

- [~] 2.1 Read the current round-trip tests and confirm every input is already `...Z` — this is why they pass over a real defect
- [~] 2.2 Add a round-trip case whose input is a non-UTC `DateTime` for each of the four affected models
- [~] 2.3 Run it BEFORE changing any production code and confirm it FAILS. A test that has never failed is not evidence
- [~] 2.4 Record the observed failure output, so the fix can be shown to address it

## 3. Unify the basis — this step must complete before section 4 starts

- [~] 3.1 Normalize to UTC at `prompt_profile.dart:98-99`
- [~] 3.2 Normalize to UTC at `prompt_manager.dart:905-906`
- [~] 3.3 Normalize to UTC at `regex_profile.dart:133-134`
- [~] 3.4 Normalize to UTC at `regex_script.dart:257-258`
- [~] 3.5 Decide and record whether normalization belongs at the construction sites (1.2) or at the serialization sites. Normalizing at construction also changes in-memory semantics, which is a wider change than this one claims
- [~] 3.6 Confirm the section-2 tests now pass and all 216 existing cases stay green
- [~] 3.7 Confirm every serialized instant in this package now ends in `Z`

## 4. Extract the shared helper — ONLY after section 3 is fully green

- [~] 4.1 Do not start this section while any site from 1.1 is still non-UTC. Extracting first would bake the local-time behaviour into one authoritative-looking implementation and make the defect harder to see, not easier
- [~] 4.2 Extract the shared conversion used by all 7 sites
- [~] 4.3 Prove the extraction is behaviour-preserving: serialized output before and after must be byte-identical
- [~] 4.4 Confirm the section-2 tests still fail if the normalization is removed from the helper

## 5. Cross-package verification

- [~] 5.1 `dart analyze` and `dart test` in this package
- [~] 5.2 `dart format --set-exit-if-changed .` — CI does not check sibling-package formatting, so this must be run locally
- [~] 5.3 `flutter analyze` and `flutter test` in `Starry-Flutter-Frontend`. A green package does not mean the host compiles
- [~] 5.4 Check whether any consumer parses the bare-local form specifically, and record the result either way
- [~] 5.5 Coordinate with the `starry_domain_entities` change: both packages should land on the same basis, and neither should extract a cross-package helper before both are unified

## 6. Record what was not decided

- [~] 6.1 Record that rows already written in local time are NOT migrated by this change, and that their originating zone was never stored, so no backfill can be correct without an assumption
- [~] 6.2 Record the open question of whether readers should reject or accept a basis-less string
- [~] 6.3 Record whether the unify-before-extract ordering should be mechanically enforced or left as a written requirement
- [~] 6.4 Do not resolve 6.1-6.3 unilaterally; they are for the user
