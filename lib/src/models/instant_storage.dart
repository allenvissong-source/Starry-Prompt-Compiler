/// The single conversion every persisted instant in this package goes through.
///
/// Extracted only AFTER all seven serialization sites had been unified onto a
/// UTC basis. The ordering matters: a shared helper introduced while the sites
/// still disagreed would have had to pick one behaviour, and whichever it
/// picked would then carry the authority of being "the shared implementation"
/// in the one place reviewers are least likely to question. Unifying first
/// makes this file a pure refactor whose serialized output is byte-identical
/// to what the seven inlined `.toUtc().toIso8601String()` calls produced.
///
/// Why UTC: a stored instant must not depend on the zone of the host that
/// wrote it. Three sites (`character_entities.dart`, `worldbook_entities.dart`)
/// already normalized; the other four wrote bare local time with no `Z`, so a
/// reader could not recover the writer's zone. See the
/// `unify-persisted-instant-to-utc` change for the full inventory.
library;

/// Serializes [instant] for storage on an unambiguous UTC basis.
///
/// The returned string always carries the `Z` marker, whatever the basis of
/// the input: `toUtc()` is a no-op on a value that is already UTC, so this is
/// safe to apply at every site regardless of how the [DateTime] was built.
///
/// This is the storage form only. Display formatting is a separate concern and
/// deliberately not handled here — code that renders a timestamp to a user
/// should convert to the viewer's zone at the point of display, not rely on
/// the basis it happens to be stored in.
String instantToStorageString(DateTime instant) =>
    instant.toUtc().toIso8601String();
