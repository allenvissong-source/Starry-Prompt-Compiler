// Package-internal model: canonical worldbook entities.
//
// Provenance: verbatim copy of
//   lib/features/starry/domain/models/worldbook_entities.dart
// No external dependencies (core Dart only). Byte-identical class/field
// names to the Starry source so behavior_v1 goldens remain valid under
// SUT=package. The single import below is package-internal, added when the
// persisted-instant conversion was extracted to one helper.
import 'instant_storage.dart';

class Worldbook {
  const Worldbook({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.description,
    required this.scanDepth,
    required this.tokenBudget,
    required this.recursiveScanning,
    required this.maxRecursionDepth,
    required this.allowEntryCascade,
    required this.tags,
    required this.creatorNotes,
    required this.extensions,
    required this.isSystem,
    required this.visibilityScope,
    required this.createdAt,
    required this.updatedAt,
    this.syncState = 'synced',
    this.localUpdatedAt,
    this.entries = const <WorldbookEntry>[],
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String description;
  final int scanDepth;
  final int? tokenBudget;
  final bool recursiveScanning;
  final int maxRecursionDepth;
  final bool allowEntryCascade;
  final List<String> tags;
  final String creatorNotes;
  final Map<String, dynamic> extensions;
  final bool isSystem;
  final String visibilityScope;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  final DateTime? localUpdatedAt;
  final List<WorldbookEntry> entries;

  Worldbook copyWith({
    String? id,
    String? ownerUserId,
    String? name,
    String? description,
    int? scanDepth,
    int? tokenBudget,
    bool? recursiveScanning,
    int? maxRecursionDepth,
    bool? allowEntryCascade,
    List<String>? tags,
    String? creatorNotes,
    Map<String, dynamic>? extensions,
    bool? isSystem,
    String? visibilityScope,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
    DateTime? localUpdatedAt,
    List<WorldbookEntry>? entries,
  }) {
    return Worldbook(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      description: description ?? this.description,
      scanDepth: scanDepth ?? this.scanDepth,
      tokenBudget: tokenBudget ?? this.tokenBudget,
      recursiveScanning: recursiveScanning ?? this.recursiveScanning,
      maxRecursionDepth: maxRecursionDepth ?? this.maxRecursionDepth,
      allowEntryCascade: allowEntryCascade ?? this.allowEntryCascade,
      tags: tags ?? this.tags,
      creatorNotes: creatorNotes ?? this.creatorNotes,
      extensions: extensions ?? this.extensions,
      isSystem: isSystem ?? this.isSystem,
      visibilityScope: visibilityScope ?? this.visibilityScope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson({bool includeEntries = true}) {
    return <String, dynamic>{
      'id': id,
      'owner_user_id': ownerUserId,
      'name': name,
      'description': description,
      'scan_depth': scanDepth,
      'token_budget': tokenBudget,
      'recursive_scanning': recursiveScanning,
      'max_recursion_depth': maxRecursionDepth,
      'allow_entry_cascade': allowEntryCascade,
      'tags': tags,
      'creator_notes': creatorNotes,
      'extensions': extensions,
      'is_system': isSystem,
      'visibility_scope': visibilityScope,
      'created_at': instantToStorageString(createdAt),
      'updated_at': instantToStorageString(updatedAt),
      if (includeEntries)
        'entries': entries.map((item) => item.toJson()).toList(),
    };
  }
}

class WorldbookEntry {
  const WorldbookEntry({
    required this.id,
    required this.worldbookId,
    required this.entryUid,
    required this.comment,
    required this.content,
    required this.keys,
    required this.secondaryKeys,
    required this.enabled,
    required this.position,
    required this.role,
    required this.entryOrder,
    required this.depth,
    required this.probability,
    required this.useProbability,
    required this.sticky,
    required this.cooldown,
    required this.delay,
    required this.selectiveLogic,
    required this.caseSensitive,
    required this.matchWholeWords,
    required this.constant,
    required this.selective,
    required this.groupName,
    required this.groupWeight,
    required this.groupOverride,
    required this.useGroup,
    required this.useGroupScoring,
    required this.preventRecursion,
    required this.excludeRecursion,
    required this.delayUntilRecursion,
    required this.automationId,
    required this.addMemo,
    required this.characterFilter,
    required this.entryScanDepth,
    required this.insertionOrder,
    required this.vectorizedValue,
    required this.displayIndex,
    required this.isFavorite,
    required this.extensions,
    required this.createdAt,
    required this.updatedAt,
    this.syncState = 'synced',
    this.localUpdatedAt,
  });

  final String id;
  final String worldbookId;
  final String entryUid;
  final String comment;
  final String content;
  final List<String> keys;
  final List<String> secondaryKeys;
  final bool enabled;
  final String position;
  final int role;
  final int entryOrder;
  final int depth;
  final int probability;
  final bool useProbability;
  final int sticky;
  final int cooldown;
  final int delay;
  final int selectiveLogic;
  final bool caseSensitive;
  final bool matchWholeWords;
  final bool constant;
  final bool selective;
  final String groupName;
  final int groupWeight;
  final int groupOverride;
  final bool useGroup;
  final bool useGroupScoring;
  final bool preventRecursion;
  final bool excludeRecursion;
  final bool delayUntilRecursion;
  final String automationId;
  final bool addMemo;
  final Map<String, dynamic> characterFilter;
  final int? entryScanDepth;
  final int insertionOrder;
  final String? vectorizedValue;
  final int displayIndex;
  final bool isFavorite;
  final Map<String, dynamic> extensions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  final DateTime? localUpdatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'worldbook_id': worldbookId,
      'uid': entryUid,
      'comment': comment,
      'content': content,
      'keys': keys,
      'secondary_keys': secondaryKeys,
      'enabled': enabled,
      'position': position,
      'role': role,
      'order': entryOrder,
      'depth': depth,
      'probability': probability,
      'use_probability': useProbability,
      'sticky': sticky,
      'cooldown': cooldown,
      'delay': delay,
      'selective_logic': selectiveLogic,
      'case_sensitive': caseSensitive,
      'match_whole_words': matchWholeWords,
      'constant': constant,
      'selective': selective,
      'group': groupName,
      'group_weight': groupWeight,
      'group_override': groupOverride,
      'use_group': useGroup,
      'use_group_scoring': useGroupScoring,
      'prevent_recursion': preventRecursion,
      'exclude_recursion': excludeRecursion,
      'delay_until_recursion': delayUntilRecursion,
      'automation_id': automationId,
      'add_memo': addMemo,
      'character_filter': characterFilter,
      'scan_depth': entryScanDepth,
      'insertion_order': insertionOrder,
      'vectorized': vectorizedValue,
      'display_index': displayIndex,
      'is_favorite': isFavorite,
      'extensions': extensions,
    };
  }
}
