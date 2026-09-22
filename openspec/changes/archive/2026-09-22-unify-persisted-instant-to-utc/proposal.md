## Why

This package serializes instants two different ways. Some sites normalize to UTC before writing — `character_entities.dart:181-182,231-232` and `worldbook_entities.dart:112-113` all call `.toUtc().toIso8601String()`. Others do not: `prompt_profile.dart:96-97`, `prompt_manager.dart:893-894`, `regex_profile.dart:132-133` and `regex_script.dart:255-256` call `.toIso8601String()` on whatever the value already is, and the values feeding them come from bare `DateTime.now()` (`prompt_profile.dart:44,47`, `prompt_manager.dart:855-856`, `regex_profile.dart:91,94`, `regex_script.dart:120,123`).

`DateTime.now()` is local. So the same logical timestamp serializes as `...Z` on one path and as a bare local string on another, and a reader cannot tell which basis a stored value used. A real run produced `2026-03-01T09:30:15.000` with no `Z`.

## What Changes

- Make every serialized instant in this package UTC, matching what the already-correct sites do.
- **Unify first, extract second.** Only once every site is UTC may a shared helper be factored
  out. Extracting first would freeze the current two-semantics behaviour into a single
  implementation that then looks authoritative.
- Add a round-trip test fed by a non-UTC input, so the guard can actually fail.

## Capabilities

### New Capabilities

- `instant-serialization-basis` — the single time basis for any instant this package serializes,
  and what a round-trip must preserve.

## Impact

- **BREAKING for already-stored rows** written through the non-UTC paths: the same column now
  holds values under two bases. This change does not migrate them.
- Consumers reading these fields see a format change on the affected paths: a bare local string
  becomes a `Z`-suffixed one.
- Files: `prompt_profile.dart`, `prompt_manager.dart`, `regex_profile.dart`, `regex_script.dart`,
  plus tests.

## Non-goals

- Migrating or backfilling stored rows.
- Changing `Clock`/`FrozenClock` injection — determinism in tests is already handled there.
- Extracting the shared helper in this change. That is the deliberate second step.
