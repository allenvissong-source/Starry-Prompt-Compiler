// Legacy wire format for prompt blocks.
//
// The persisted catalog payload for resource type `prompt_block` was written by
// the V1 model's `toJson`, so on disk and on the server it looks like this:
//
//   kind:              bare enum name, e.g. "systemPrompt" (no namespace)
//   placementPolicy:   { anchor, injectionPosition?, depth? }
//   activationPolicy:  { generationTriggers }
//   priorityPolicy:    { sortOrder, injectionOrder? }
//   protectionPolicy:  { locked, forbidOverride }
//   provenance:        { source, identifier?, extension }
//
// The V2 model serializes different key names (`placement`, `activation`,
// `priority`, `protection`) and a namespaced `kind`, plus `schemaVersion` and
// `extensions`. Writing V2's own `toJson` to the catalog would therefore change
// a persisted format that already has rows in it — on this device, on the
// server, and on other clients still running the old build.
//
// The failure mode that would cause is worth naming precisely, because it is
// not a loud one. `LegacyPromptBlock.fromJson` resolved an unknown kind with
// `orElse: () => custom`, so an older client reading a namespaced
// "core:systemPrompt" would not fail — it would silently file the block as
// `custom`. A system prompt quietly demoted to a custom block, with nothing in
// any log. Silent reclassification is harder to notice than a decode error, so
// the wire stays exactly as it was.
//
// These two functions are inverses and are the only place that knows the legacy
// spelling. Everything above them speaks V2.

import '../models/prompt_block.dart';
import 'prompt_block_from_legacy.dart' show kLegacyV1ExtensionNamespace;

/// Keys the legacy wire shape owns at the top level of a block object.
const Set<String> _legacyWireKeys = <String>{
  'id',
  'promptProfileId',
  'kind',
  'name',
  'enabled',
  'content',
  'role',
  'placementPolicy',
  'activationPolicy',
  'priorityPolicy',
  'protectionPolicy',
  'provenance',
  // Emitted by some legacy tooling as a convenience mirror of `kind`. V2
  // answers that question from `kind`, so it is read and discarded rather than
  // round-tripped: keeping it would be a second source of truth that can go
  // stale against the kind it duplicates.
  'isMarker',
};

/// Reads a block written in the legacy V1 wire shape into the V2 model.
///
/// Unrecognised top-level keys are preserved under `extensions.legacy_v1` so a
/// field written by a fork, or by a future version, survives a read/write cycle
/// through this build instead of being dropped.
PromptBlock promptBlockFromLegacyJson(Map<String, dynamic> json) {
  final placement = _asMap(json['placementPolicy']);
  final priority = _asMap(json['priorityPolicy']);

  final unknown = <String, dynamic>{};
  for (final entry in json.entries) {
    if (_legacyWireKeys.contains(entry.key)) continue;
    unknown[entry.key] = entry.value;
  }

  return PromptBlock(
    id: (json['id'] ?? '').toString(),
    promptProfileId: _stringOrNull(json['promptProfileId']),
    // A bare legacy name becomes `core:<name>`; an unrecognised one lands on
    // `core:custom`, which is the same reclassification V1's own `orElse` did.
    kind: normalizePromptBlockKind((json['kind'] ?? '').toString()),
    name: (json['name'] ?? '').toString(),
    enabled: json['enabled'] != false,
    content: (json['content'] ?? '').toString(),
    role: _stringOrNull(json['role']),
    placement: PromptBlockPlacement(
      anchor: _stringOrNull(placement['anchor']),
      injectionPosition: _intOrNull(placement['injectionPosition']),
      // V1 accepted either spelling on read; the newer one wins when both are
      // present, matching the order V1's own `??` chain used.
      depth: _intOrNull(placement['depth'] ?? placement['injectionDepth']),
      injectionOrder: _intOrNull(priority['injectionOrder']),
    ),
    activation: PromptBlockActivation(
      generationTriggers: _stringList(
        _asMap(json['activationPolicy'])['generationTriggers'] ??
            _asMap(json['activationPolicy'])['injectionTrigger'],
      ),
    ),
    priority: PromptBlockPriority(
      sortOrder: _intOrNull(priority['sortOrder'] ?? priority['order']) ?? 0,
      injectionOrder: _intOrNull(priority['injectionOrder']),
    ),
    protection: PromptBlockProtection(
      locked: _asMap(json['protectionPolicy'])['locked'] == true,
      forbidOverride:
          _asMap(json['protectionPolicy'])['forbidOverride'] == true ||
          _asMap(json['protectionPolicy'])['forbid_overrides'] == true,
    ),
    provenance: PromptBlockProvenance(
      source: (_asMap(json['provenance'])['source'] ?? 'local').toString(),
      identifier: _stringOrNull(_asMap(json['provenance'])['identifier']),
      extension: _asMap(json['provenance'])['extension'] == true,
    ),
    extensions: unknown.isEmpty
        ? const <String, dynamic>{}
        : <String, dynamic>{kLegacyV1ExtensionNamespace: unknown},
  );
}

/// Writes a V2 block back out in the legacy V1 wire shape.
///
/// Inverse of [promptBlockFromLegacyJson]: the bytes this produces are the
/// bytes the V1 model's `toJson` produced for the equivalent block, so a row
/// rewritten by this build stays readable by a client that has not migrated.
/// Keys recovered into `extensions.legacy_v1` on the way in are spread back to
/// the top level on the way out, which is what closes the round trip.
Map<String, dynamic> promptBlockToLegacyJson(PromptBlock block) {
  final legacy = block.extensions[kLegacyV1ExtensionNamespace];
  return <String, dynamic>{
    if (legacy is Map)
      for (final entry in legacy.entries) entry.key.toString(): entry.value,
    'id': block.id,
    if (block.promptProfileId != null) 'promptProfileId': block.promptProfileId,
    // Namespace stripped: the wire has always carried the bare name.
    'kind': block.kindName,
    'name': block.name,
    'enabled': block.enabled,
    'content': block.content,
    if (block.role != null) 'role': block.role,
    'placementPolicy': <String, dynamic>{
      'anchor': block.placement.anchor ?? 'relative',
      if (block.placement.injectionPosition != null)
        'injectionPosition': block.placement.injectionPosition,
      if (block.placement.depth != null) 'depth': block.placement.depth,
    },
    'activationPolicy': <String, dynamic>{
      'generationTriggers': block.activation.generationTriggers,
    },
    'priorityPolicy': <String, dynamic>{
      'sortOrder': block.priority.sortOrder,
      if (block.priority.injectionOrder != null)
        'injectionOrder': block.priority.injectionOrder,
    },
    'protectionPolicy': <String, dynamic>{
      'locked': block.protection.locked,
      'forbidOverride': block.protection.forbidOverride,
    },
    'provenance': <String, dynamic>{
      'source': block.provenance.source,
      if (block.provenance.identifier != null)
        'identifier': block.provenance.identifier,
      'extension': block.provenance.extension,
    },
  };
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
