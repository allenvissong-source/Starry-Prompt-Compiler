## Context

The split, by file and line:

| Site | Call | Basis |
|---|---|---|
| `character_entities.dart:181-182` | `.toUtc().toIso8601String()` | UTC |
| `character_entities.dart:231-232` | `.toUtc().toIso8601String()` | UTC |
| `worldbook_entities.dart:112-113` | `.toUtc().toIso8601String()` | UTC |
| `prompt_profile.dart:96-97` | `.toIso8601String()` | whatever it was given |
| `prompt_manager.dart:893-894` | `.toIso8601String()` | whatever it was given |
| `regex_profile.dart:132-133` | `.toIso8601String()` | whatever it was given |
| `regex_script.dart:255-256` | `.toIso8601String()` | whatever it was given |

What "whatever it was given" resolves to in production: `prompt_profile.dart:44,47`,
`prompt_manager.dart:855-856`, `regex_profile.dart:91,94` and `regex_script.dart:120,123` all
construct from a bare `DateTime.now()`, which is local. So the four lower rows write local time
with no `Z`.

The existing round-trip tests pass anyway, because every input they supply is already `...Z` —
the normalization they appear to verify is never exercised.

**Sibling packages, for scope.** `starry_domain_entities` has the same split (6 sites) and is
covered by its own change. `starry_character_card_codec` and `starry_injection_service` have
zero occurrences and are out of scope entirely.

## Goals / Non-Goals

Goals:

- One basis for every serialized instant in this package.
- Test coverage that would fail if the normalization were removed.
- The ordering constraint below recorded where the implementer will read it.

Non-Goals:

- Migrating rows already written in local time. Out of scope and called out as an open question.
- Touching `Clock` / `FrozenClock`. Test determinism is already handled and is a separate axis
  from serialization basis.
- Extracting the shared helper here.

## Decisions

**Decision: UTC is the target basis.** Three sites already do this, it is the conventional
choice for a stored instant, and it makes the stored value independent of the writing host.
Converging on local time would mean changing three correct sites to match four incorrect ones.

**Decision (load-bearing): unify the basis first, extract the helper second.**
This ordering is the whole point of the change. A shared `toStorageString(DateTime)` extracted
while the sites still disagree would have to pick one behaviour — and whichever it picked would
then wear the authority of being "the shared implementation", in a single place that reviewers
are least likely to question. The bug would stop being seven visible call sites and become one
invisible utility. Unify first, and the extraction afterwards is a pure refactor whose output
diff must be empty.

**Decision: add a failing-capable test before the fix.**
The current suite is green and wrong. Add a round-trip case fed a non-UTC input, watch it fail,
then fix. A test written after the fix, from the fixed code, tends to encode what the code does
rather than what it should do.

**Decision: do not migrate stored rows.**
A row written as `2026-03-01T09:30:15.000` cannot be interpreted without knowing the writing
host's zone, which is not recorded. Any backfill would be guessing. This is the user's call, not
ours — see Open Questions.

## Risks / Trade-offs

- **Stored values become inconsistent across the cut-over.** → Already inconsistent; this change
  makes new writes uniform and makes the old ambiguity explicit rather than hidden.
- **A consumer parses the bare-local form specifically.** → The host application's analyze and
  tests are the check. Named as a task, not assumed away.
- **Someone "helpfully" extracts the helper first.** → Stated in the spec as a requirement and
  in tasks as an ordering constraint, not left to reviewer memory.
- **Display code might be re-rendering these as local.** → Serialization basis and display
  formatting are different concerns; this change touches only the former. If display breaks, it
  was relying on the storage basis, which is itself a defect.

## Migration Plan

1. Add the non-UTC round-trip case. Confirm it fails.
2. Normalize the four non-UTC sites to `.toUtc()` before serializing.
3. Confirm the new test passes and the existing 177 stay green.
4. Verify in the host application.
5. Only then, extract the shared helper, with an empty output diff as the acceptance bar.

## Open Questions

- **What happens to rows already written in local time?** Their zone was not recorded, so no
  backfill can be correct without an assumption. Not decided here.
- **Should the reading side reject a basis-less string, or accept and assume?** Rejecting
  surfaces old rows loudly; accepting hides them. Depends on the answer above.
- **Should the ordering constraint be enforced mechanically** (for example, a check that no
  shared helper exists while any site is still non-UTC), or is the written requirement enough?
