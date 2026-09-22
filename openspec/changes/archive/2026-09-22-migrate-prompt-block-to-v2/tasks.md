## 1. Baseline

- [~] 1.1 Record the pre-change baseline: `dart analyze` and `dart test` in this package, and the byte-identity status of all 22 fixtures under `test/fixtures/starry_prompt_compiler/behavior_v1/` via `flutter test test/features/prompt_compiler/behavior_baseline_golden_test.dart` in `Starry-Flutter-Frontend`. Without a green starting point a later red is unattributable
- [~] 1.2 Record the measured fixture count and SHA256 of every committed `expected.json`, so any later edit to an expectation is detectable rather than assumed absent

## 2. V2 model and conversion

- [~] 2.1 Add the V2 block model matching `docs/prompt_compiler/schema/prompt_block_v2.schema.json`: `schemaVersion`, open `kind`, discriminated `placement`, `activation`, `priority`, `protection`, `provenance`, `extensions`
- [~] 2.2 Implement V1 to V2 conversion per `compat_matrix_v1_v2.md` §2 field mapping, §3 the 15 `kind` to `core:*` mappings, §4.1 the placement pattern table, §4.2 the `injectionOrder` mirror rule, §5 `isMarker` drop, §6 `config.sections`, §7 unknown keys into `extensions.legacy_v1`
- [~] 2.3 Unit-test the conversion: all 15 kinds, every placement pattern in §4.1, an unknown kind, an unknown JSON key, and a block with all five policy objects away from defaults. Assert `injectionOrder` is mirrored only for the four variants that admit it

## 3. Compiler consumes V2

- [~] 3.1 Change the planner to take V2 blocks, keeping every routing, ordering and filtering rule semantically unchanged
- [~] 3.2 Convert at the boundary so no version branch exists inside the planner
- [~] 3.3 Update the call sites in `Starry-Flutter-Frontend` that construct or read blocks, and confirm `flutter analyze` is clean — the goldens cannot run if the host does not compile

## 4. Byte-identity gate

- [~] 4.1 Run the 22 fixtures and record, per fixture, the SHA256 of the produced snapshot and of the committed `expected.json`. All 22 must match
- [~] 4.2 Confirm no expectation was modified: `git status --porcelain` and `git diff --stat HEAD` both clean for the fixture tree and `test/goldens/`
- [~] 4.3 If any fixture differs, record the exact difference and stop here; sections 5 and 6 MUST NOT proceed on an unproven conversion

## 5. Remove the superseded path

- [~] 5.1 Only after 4.1 is 22/22: delete the V1 block consumption path from the compiler
- [~] 5.2 Re-run the 22 fixtures after deletion and confirm they are still byte-identical

## 6. Flatten the naming

- [~] 6.1 Rename the surviving shape to unversioned names, so no `V1`/`V2` pair remains in the public surface
- [~] 6.2 Align `lib/src/models/session_prompt_context.dart` so the serialized `version` describes the shape actually written, and update the comment at `:82` which currently documents the field as an unread stamp
- [~] 6.3 Final gate: `dart analyze`, `dart test` and `dart format --set-exit-if-changed .` in this package, plus `flutter analyze` and the golden run in `Starry-Flutter-Frontend`
