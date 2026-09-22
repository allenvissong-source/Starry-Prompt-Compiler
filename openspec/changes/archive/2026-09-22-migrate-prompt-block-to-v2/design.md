## Context

The V2 protocol is fully specified in `Starry-Flutter-Frontend/docs/prompt_compiler/`
(`schema/prompt_block_v2.schema.json`, `prompt_block_v2_schema.md`, `compat_matrix_v1_v2.md`)
and implemented nowhere. Measured in this workspace: zero occurrences of `PromptBlockV2`,
`promptBlockV2`, `blockV2`, `toV2` or `fromV1` across the three candidate `lib` trees; 147
lines in `Starry-Prompt-Compiler/lib` mention `PromptBlock`.

Three facts from reconnaissance shape the plan, and two of them contradict the documents:

- **The corpus is 22 fixtures, not 19.** `compat_matrix_v1_v2.md` says 19 in three places.
  `test/fixtures/starry_prompt_compiler/behavior_v1/` contains 22 directories, each with
  `case.json`, `input.json`, `expected.json`, and none flagged `nondeterministic`. The golden
  test file's own docstring already says 22. The measured number governs.
- **V1 truth lives in this package, not the frontend.** The frontend file the compat matrix
  names as ground truth (`lib/features/prompt_lab/data/models/prompt_manager.dart`) is a 531-byte
  re-export shim. The classes are in `lib/src/models/prompt_manager.dart` here.
- **The goldens can only be run from the frontend.** The fixtures, the deserializer, the
  canonical serializer and the golden runner all live in `Starry-Flutter-Frontend/test/`, and
  they drive this package through a path dependency. So "byte-identical" is a `flutter test`
  result, and this package's own `dart test` cannot establish it.

## Goals / Non-Goals

Goals:

- One block shape inside the compiler, with conversion at the boundary.
- A conversion that is lossless per `compat_matrix_v1_v2.md`, including unknown-key retention.
- Byte-identical output on all 22 fixtures, demonstrated against the committed expectations.
- After that: the superseded path gone, one unversioned name for the surviving shape, and a
  version stamp on `SessionPromptContext` that describes what is actually serialized.

Non-Goals:

- Designing the mapping. It is given in full by `compat_matrix_v1_v2.md` §2–§7 and is
  implemented as written, not re-derived.
- A separately published codec package.
- Interpreting third-party `kind` namespaces beyond passthrough.
- Backfilling persisted rows.
- Any claim about CI. It is not observable from this workstation.

## Decisions

**Decision: conversion is a boundary function, not a branch inside the planner.**
The planner keeps a single input type. Adding a version check inside `_collectPromptBlockUnits`
would put both shapes inside the routing logic, which is exactly the two-definitions problem the
migration is meant to end. `compat_matrix_v1_v2.md` §1 states the same terminal shape: the core
compiler consumes V2 only, and each V1 profile is converted before it enters.
Alternative considered: dual-dispatch in the planner. Rejected — it is the cheapest change today
and the most expensive one to reverse later.

**Decision: `placement` is derived by pattern-matching the V1 fields, with no new judgement.**
`compat_matrix_v1_v2.md` §4.1 gives the full pattern table and §4.2 gives the `injectionOrder`
mirror rule (mirrored only for `relative`, `author_note`, `before_history`, `after_history`;
omitted for `absolute`, `history_splice`, `outlet`). `default_anchor_for(kind)` is read from the
existing frozen marker mapping rather than re-encoded as a second switch — a duplicate switch is
a second source of truth that will diverge.

**Decision: unknown keys go to a single reserved extension namespace.**
§7 assigns `extensions.legacy_v1` to the codec. Silently dropping unknown keys turns a visible
import failure into an invisible content change, which is the one failure mode a passthrough
slot exists to prevent.

**Decision: byte-identity is checked by SHA256 per fixture against the committed file.**
A per-fixture digest names which fixture diverged; an aggregate pass/fail does not. The
comparison also asserts the enumerated count, so a fixture that stops being discovered fails the
run instead of quietly shrinking the corpus — the corpus size is the thing the 19-vs-22
discrepancy proves can drift unnoticed.

**Decision: steps 4 and 5 are conditional on step 3, and the condition is honoured.**
If any fixture differs, the difference is reported and the superseded path stays. Deleting the
old path while the new one produces different bytes would remove the only thing that could
explain the difference.

**Decision: the `SessionPromptContext` version stamp is corrected last, not first.**
Today `:89` defaults it to `2`, `:216` writes it, and no code branches on it — so the payload
claims a version its semantics do not implement. Correcting the stamp before the semantics exist
would just move the lie; correcting it after the terminal shape is settled makes it true.

## Risks / Trade-offs

- **The goldens depend on the frontend compiling.** A change in this package that the frontend
  cannot build makes the acceptance gate unrunnable, which reads as "no result", not as "pass".
  → The frontend call sites are part of this change's impact, not an afterthought, and
  `flutter analyze` on the frontend is a gate before the golden run is trusted.
- **A single `flutter test` run in the frontend is long (~23 min measured previously).** →
  Target the single golden test file for iteration and keep the broad run for the final check.
- **`core.autocrlf=true` in this workspace.** A whole-file line-ending rewrite would produce a
  large diff that hides the real change. → Every commit is checked with `git diff --stat` and
  the changed-line count is compared against what was intended.
- **Expectations are the only oracle.** If they were rewritten, byte-identity would be
  self-fulfilling. → `test/goldens/` and the fixture tree are verified untouched with both
  `git status --porcelain` and `git diff --stat HEAD` before the result is reported.
- **The 19-vs-22 discrepancy means the documents are stale in at least one respect.** → Where a
  document and the tree disagree, the tree is measured and the discrepancy is recorded rather
  than silently reconciled.

## Migration Plan

1. Add the V2 block model and the V1→V2 conversion; unit-test the conversion against every
   pattern in §3 and §4.1, including an unknown kind and an unknown key.
2. Route the planner through V2, converting at the boundary. No planning rule changes meaning.
3. Run the 22 fixtures; record a SHA256 per fixture for the produced snapshot and the committed
   expectation. All 22 must match.
4. Only on 22/22: delete the superseded consumption path.
5. Only after 4: flatten the surviving names, and align the `SessionPromptContext` stamp.

Rollback: each step is a separate commit with explicit paths. Steps 1–2 are additive and
revertable in isolation; steps 4–5 are only reachable after the gate in step 3, so a rollback
never leaves the tree with a deleted path and an unproven replacement.

## Open Questions

- Whether `compat_matrix_v1_v2.md` and `prompt_block_v2_schema.md` should be corrected from 19
  to 22 as part of this change or separately. They live in the frontend repo's docs tree, which
  another workstream is editing; the count is recorded here either way.
