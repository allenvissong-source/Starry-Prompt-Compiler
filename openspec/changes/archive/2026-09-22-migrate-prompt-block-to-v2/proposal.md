## Why

The V2 Prompt Block is fully specified and implemented nowhere. Measured here: `PromptBlockV2`,
`promptBlockV2`, `blockV2`, `toV2` and `fromV1` occur 0 times across all three candidate `lib`
trees, while V1 `PromptBlock` occurs on 147 lines of this package. A protocol that exists only
as a document constrains nothing, and every month of new V1 call sites makes the move larger.

A smaller defect is in scope because the migration is what makes it honest:
`lib/src/models/session_prompt_context.dart:89` defaults `version` to `2` and `:216` serializes
it, but no code branches on it — the payload claims v2 while the semantics are v1.

## What Changes

- Add a V2 block model and a V1→V2 conversion in `starry_prompt_compiler`, implementing
  `compat_matrix_v1_v2.md` as written: §2 field mapping, §3 the 15 `kind` → `core:*` mappings,
  §4 placement collapse, §4.2 the `injectionOrder` mirror rule, §5 `isMarker` removal, §6
  `config.sections`, §7 `extensions.legacy_v1` for unknown keys.
- Make the planner — the core compiler — consume V2 blocks only. V1 input is converted at the
  boundary before it reaches the planner.
- Verify against the behavior corpus: **22** fixture directories under
  `test/fixtures/starry_prompt_compiler/behavior_v1/`, compared by SHA256 of the canonical
  snapshot against the committed `expected.json`. The corpus is 22, not the 19 named in
  `compat_matrix_v1_v2.md`; the document is stale and the measured count governs.
- Only if all 22 are byte-identical: remove the V1 consumption path, then flatten the naming so
  exactly one block shape survives under unversioned names, and correct
  `session_prompt_context.dart` so the stamped version matches the terminal shape.

## Capabilities

### New Capabilities

- `prompt-block-schema` — the versioned block contract the compiler consumes, the losslessness
  guarantee of the V1→V2 conversion, and the output-stability guarantee that gates it.

## Impact

- `Starry-Prompt-Compiler`: `lib/src/models/` (block model, profile, session context),
  `lib/src/codec/` (new), `lib/src/planner/prompt_execution_planner.dart`.
- `Starry-Flutter-Frontend`: call sites that construct or read blocks — the prompt-lab payload
  codec and authoring store, the prompt-context resolver, and the fixture deserializer that
  drives the goldens. The frontend is a path dependency of the package, so it must keep
  compiling for the goldens to be runnable at all.
- `test/fixtures/starry_prompt_compiler/behavior_v1/` is read-only for this change. No
  `expected.json` is edited and no baseline is re-recorded; byte-identity is an outcome of a
  correct conversion, and rewriting the expectation would destroy the only evidence that the
  conversion is correct.

## Non-goals

- Publishing a separate codec package. The conversion lands inside `starry_prompt_compiler`
  behind its own library; extracting it is a packaging decision, not a protocol one.
- Accepting or emitting third-party `kind` namespaces beyond passthrough. The compiler routes
  unknown kinds to the `core:custom` default rule and does not interpret them.
- Migrating rows already persisted in the V1 layout. The conversion runs on read; no backfill
  is performed and none is implied.
- Any change to CI configuration. CI red/green is not observable from this workstation, so no
  claim about it is made here.
