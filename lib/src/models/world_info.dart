// Package-internal model: world info entries + runtime policy + resolution.
//
// Provenance: verbatim copy of
//   lib/features/chat_character/data/models/world_info.dart
// Import rewrite only:
//   package:starry/features/starry/domain/models/worldbook_entities.dart
//     as starry_worldbook
//   -> 'worldbook_entities.dart' as starry_worldbook
// The `starry_worldbook.WorldbookEntry` alias inside
// `WorldInfoEntry.fromCanonicalEntry` is preserved so downstream call
// sites remain byte-identical to the Starry source. Class/field/enum
// names are byte-identical to the Starry source.

import 'worldbook_entities.dart' as starry_worldbook;

enum WorldInfoPosition {
  before,
  after,
  anTop,
  anBottom,
  atDepth,
  emTop,
  emBottom,
  outlet,
}

WorldInfoPosition worldInfoPositionFromString(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'after':
    case 'after_char':
    case 'afterchardefs':
      return WorldInfoPosition.after;
    case 'before_author_note':
    case 'antop':
      return WorldInfoPosition.anTop;
    case 'after_author_note':
    case 'anbottom':
      return WorldInfoPosition.anBottom;
    case 'at_depth':
    case 'atdepth':
      return WorldInfoPosition.atDepth;
    case 'before_example':
    case 'emtop':
      return WorldInfoPosition.emTop;
    case 'after_example':
    case 'embottom':
      return WorldInfoPosition.emBottom;
    case 'outlet':
      return WorldInfoPosition.outlet;
    case 'before':
    case 'before_char':
    case 'beforechardefs':
    default:
      return WorldInfoPosition.before;
  }
}

enum WorldInfoScanSource {
  history,
  personaDescription,
  characterDescription,
  characterPersonality,
  characterDepthPrompt,
  scenario,
  creatorNotes,
  authorNote,
}

WorldInfoScanSource? worldInfoScanSourceFromString(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'history':
      return WorldInfoScanSource.history;
    case 'persona_description':
      return WorldInfoScanSource.personaDescription;
    case 'character_description':
      return WorldInfoScanSource.characterDescription;
    case 'character_personality':
      return WorldInfoScanSource.characterPersonality;
    case 'character_depth_prompt':
      return WorldInfoScanSource.characterDepthPrompt;
    case 'scenario':
      return WorldInfoScanSource.scenario;
    case 'creator_notes':
      return WorldInfoScanSource.creatorNotes;
    case 'author_note':
      return WorldInfoScanSource.authorNote;
    default:
      return null;
  }
}

class WorldInfoActivationPolicy {
  const WorldInfoActivationPolicy({this.generationTriggers = const <String>[]});

  final List<String> generationTriggers;

  bool supportsGenerationTrigger(String? trigger) {
    if (generationTriggers.isEmpty) return true;
    final normalized = (trigger ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return generationTriggers.any(
      (item) => item.trim().toLowerCase() == normalized,
    );
  }
}

class WorldInfoBudgetPolicy {
  const WorldInfoBudgetPolicy({this.ignoreLimit = false, this.tier});

  final bool ignoreLimit;

  /// Budget precedence tier (`mandatory` / `high` / `normal` / `low`).
  ///
  /// Populated when the source dialect carries an explicit allocation priority
  /// (SillyTavern's `weight`, translated to a tier at import time). `null` means
  /// "no explicit tier", and the planner falls back to deriving one from
  /// [ignoreLimit].
  final String? tier;
}

class WorldInfoTargetingPolicy {
  const WorldInfoTargetingPolicy({
    this.scanSources = const <WorldInfoScanSource>[],
  });

  final List<WorldInfoScanSource> scanSources;
}

class WorldInfoOutputPolicy {
  const WorldInfoOutputPolicy({this.outlet});

  final String? outlet;
}

class WorldInfoRuntimePolicy {
  const WorldInfoRuntimePolicy({
    this.activation = const WorldInfoActivationPolicy(),
    this.budget = const WorldInfoBudgetPolicy(),
    this.targeting = const WorldInfoTargetingPolicy(),
    this.output = const WorldInfoOutputPolicy(),
  });

  factory WorldInfoRuntimePolicy.fromEntryExtensions(
    Map<String, dynamic> extensions,
  ) {
    final activationPolicy = _map(extensions['activationPolicy']);
    final budgetPolicy = _map(extensions['budgetPolicy']);
    final targetingPolicy = _map(extensions['targetingPolicy']);
    final outputPolicy = _map(extensions['outputPolicy']);
    return WorldInfoRuntimePolicy(
      activation: WorldInfoActivationPolicy(
        generationTriggers: _stringList(
          activationPolicy['generationTriggers'] ?? extensions['triggers'],
        ),
      ),
      budget: WorldInfoBudgetPolicy(
        ignoreLimit:
            budgetPolicy['ignoreLimit'] == true ||
            extensions['ignoreBudget'] == true,
        tier: _normalizedOrNull(budgetPolicy['tier']),
      ),
      targeting: WorldInfoTargetingPolicy(
        scanSources: _scanSourceList(
          targetingPolicy['scanSources'] ?? extensions['scanSources'],
        ),
      ),
      output: WorldInfoOutputPolicy(
        outlet: _normalizedOrNull(
          outputPolicy['outlet'] ?? extensions['outletName'],
        ),
      ),
    );
  }

  final WorldInfoActivationPolicy activation;
  final WorldInfoBudgetPolicy budget;
  final WorldInfoTargetingPolicy targeting;
  final WorldInfoOutputPolicy output;
}

class WorldInfoMatchContext {
  const WorldInfoMatchContext({
    this.history = '',
    this.personaDescription = '',
    this.characterDescription = '',
    this.characterPersonality = '',
    this.characterDepthPrompt = '',
    this.scenario = '',
    this.creatorNotes = '',
    this.authorNote = '',
  });

  final String history;
  final String personaDescription;
  final String characterDescription;
  final String characterPersonality;
  final String characterDepthPrompt;
  final String scenario;
  final String creatorNotes;
  final String authorNote;

  String get mergedText => scopedText();

  String scopedText([List<WorldInfoScanSource> sources = const []]) {
    final scopedSources = sources.isEmpty
        ? WorldInfoScanSource.values
        : sources;
    final buffer = StringBuffer();
    for (final source in scopedSources) {
      final value = valueFor(source);
      if (value.trim().isEmpty) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(value);
    }
    return buffer.toString();
  }

  String valueFor(WorldInfoScanSource source) {
    switch (source) {
      case WorldInfoScanSource.history:
        return history;
      case WorldInfoScanSource.personaDescription:
        return personaDescription;
      case WorldInfoScanSource.characterDescription:
        return characterDescription;
      case WorldInfoScanSource.characterPersonality:
        return characterPersonality;
      case WorldInfoScanSource.characterDepthPrompt:
        return characterDepthPrompt;
      case WorldInfoScanSource.scenario:
        return scenario;
      case WorldInfoScanSource.creatorNotes:
        return creatorNotes;
      case WorldInfoScanSource.authorNote:
        return authorNote;
    }
  }
}

class WorldInfoEntry {
  WorldInfoEntry({
    required this.id,
    required this.worldbookId,
    required this.keys,
    required this.secondaryKeys,
    required this.content,
    required this.comment,
    required this.enabled,
    required this.constant,
    required this.selective,
    required this.insertionOrder,
    required this.caseSensitive,
    required this.matchWholeWords,
    required this.useGroupScoring,
    required this.probability,
    required this.useProbability,
    required this.position,
    required this.depth,
    required this.group,
    required this.groupWeight,
    required this.preventRecursion,
    required this.delayUntilRecursion,
    required this.scanDepth,
    required this.role,
    required this.sticky,
    required this.cooldown,
    required this.delay,
    required this.characterFilter,
    this.selectiveLogic = 0,
    this.generationTriggers = const <String>[],
    this.ignoreBudget = false,
    this.outletName,
    this.scanSources = const <String>[],
    WorldInfoRuntimePolicy? runtimePolicy,
  }) : runtimePolicy =
           runtimePolicy ??
           WorldInfoRuntimePolicy(
             activation: WorldInfoActivationPolicy(
               generationTriggers: generationTriggers,
             ),
             budget: WorldInfoBudgetPolicy(ignoreLimit: ignoreBudget),
             targeting: WorldInfoTargetingPolicy(
               scanSources: _scanSourceList(scanSources),
             ),
             output: WorldInfoOutputPolicy(outlet: outletName),
           );

  factory WorldInfoEntry.fromCanonicalEntry(
    starry_worldbook.WorldbookEntry entry,
  ) {
    final policy = WorldInfoRuntimePolicy.fromEntryExtensions(entry.extensions);
    return WorldInfoEntry(
      id: entry.id,
      worldbookId: entry.worldbookId,
      keys: entry.keys,
      secondaryKeys: entry.secondaryKeys,
      content: entry.content,
      comment: entry.comment,
      enabled: entry.enabled,
      constant: entry.constant,
      selective: entry.selective,
      selectiveLogic: entry.selectiveLogic,
      insertionOrder: entry.insertionOrder,
      caseSensitive: entry.caseSensitive,
      matchWholeWords: entry.matchWholeWords,
      useGroupScoring: entry.useGroupScoring,
      probability: entry.probability,
      useProbability: entry.useProbability,
      position: worldInfoPositionFromString(entry.position),
      depth: entry.depth,
      group: entry.groupName.isEmpty ? null : entry.groupName,
      groupWeight: entry.groupWeight,
      preventRecursion: entry.preventRecursion,
      delayUntilRecursion: entry.delayUntilRecursion,
      scanDepth: entry.entryScanDepth ?? 0,
      role: entry.role,
      sticky: entry.sticky,
      cooldown: entry.cooldown,
      delay: entry.delay,
      characterFilter: entry.characterFilter,
      generationTriggers: policy.activation.generationTriggers,
      ignoreBudget: policy.budget.ignoreLimit,
      outletName: policy.output.outlet,
      scanSources: policy.targeting.scanSources
          .map(_scanSourceToWireValue)
          .toList(growable: false),
      runtimePolicy: policy,
    );
  }

  final String id;
  final String worldbookId;
  final List<String> keys;
  final List<String> secondaryKeys;
  final String content;
  final String comment;
  final bool enabled;
  final bool constant;
  final bool selective;

  /// Multi-key activation logic: 0=AND_ANY, 1=NOT_ALL, 2=NOT_ANY, 3=AND_ALL.
  final int selectiveLogic;
  final int insertionOrder;
  final bool caseSensitive;
  final bool matchWholeWords;
  final bool useGroupScoring;
  final int probability;
  final bool useProbability;
  final WorldInfoPosition position;
  final int depth;
  final String? group;
  final int groupWeight;
  final bool preventRecursion;
  final bool delayUntilRecursion;
  final int scanDepth;
  final int role;
  final int sticky;
  final int cooldown;
  final int delay;
  final Map<String, dynamic> characterFilter;
  final List<String> generationTriggers;
  final bool ignoreBudget;
  final String? outletName;
  final List<String> scanSources;
  final WorldInfoRuntimePolicy runtimePolicy;

  bool supportsGenerationTrigger(String? trigger) {
    return runtimePolicy.activation.supportsGenerationTrigger(trigger);
  }

  bool appliesToCharacter(String characterId, List<String> tags) {
    final type = (characterFilter['type'] ?? 'none')
        .toString()
        .trim()
        .toLowerCase();
    final ids =
        ((characterFilter['character_ids'] ?? characterFilter['characterIds'])
                as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];
    final filterTags =
        ((characterFilter['tags']) as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];

    switch (type) {
      case 'include':
        return ids.contains(characterId) || filterTags.any(tags.contains);
      case 'exclude':
        return !(ids.contains(characterId) || filterTags.any(tags.contains));
      case 'none':
      default:
        return true;
    }
  }

  bool shouldTriggerByProbability() {
    if (!useProbability || probability <= 0 || probability >= 100) {
      return true;
    }
    return (DateTime.now().millisecondsSinceEpoch % 100) < probability;
  }
}

class WorldInfoResolution {
  const WorldInfoResolution({
    required this.entries,
    required this.groupedEntries,
    required this.candidateWorldInfoIds,
    required this.contextText,
  });

  final List<WorldInfoEntry> entries;
  final Map<WorldInfoPosition, List<WorldInfoEntry>> groupedEntries;
  final List<String> candidateWorldInfoIds;
  final String contextText;
}

Map<String, dynamic> _map(dynamic raw) {
  if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return <String, dynamic>{};
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<WorldInfoScanSource> _scanSourceList(dynamic raw) {
  final items = _stringList(raw);
  return items
      .map(worldInfoScanSourceFromString)
      .whereType<WorldInfoScanSource>()
      .toList(growable: false);
}

String _scanSourceToWireValue(WorldInfoScanSource source) {
  switch (source) {
    case WorldInfoScanSource.history:
      return 'history';
    case WorldInfoScanSource.personaDescription:
      return 'persona_description';
    case WorldInfoScanSource.characterDescription:
      return 'character_description';
    case WorldInfoScanSource.characterPersonality:
      return 'character_personality';
    case WorldInfoScanSource.characterDepthPrompt:
      return 'character_depth_prompt';
    case WorldInfoScanSource.scenario:
      return 'scenario';
    case WorldInfoScanSource.creatorNotes:
      return 'creator_notes';
    case WorldInfoScanSource.authorNote:
      return 'author_note';
  }
}

String? _normalizedOrNull(dynamic raw) {
  final normalized = (raw ?? '').toString().trim();
  return normalized.isEmpty ? null : normalized;
}
