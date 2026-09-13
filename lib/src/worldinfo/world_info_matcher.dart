// Package-internal service: WorldInfoMatcher.
//
// Provenance: extracted from the Starry host matcher while keeping this package
// pure Dart over WorldInfoEntry / WorldInfoMatchContext.

import '../models/world_info.dart';

/// Why an entry entered the match set.
enum WorldInfoActivationReason { keyword, constant }

/// One matched entry plus the metadata callers need to explain the match.
class WorldInfoMatch {
  const WorldInfoMatch({
    required this.entry,
    required this.activationReason,
    this.matchedKey,
  });

  final WorldInfoEntry entry;
  final WorldInfoActivationReason activationReason;
  final String? matchedKey;
}

class WorldInfoMatcher {
  const WorldInfoMatcher();

  List<WorldInfoEntry> findMatchingEntries({
    required WorldInfoMatchContext context,
    required List<WorldInfoEntry> entries,
    required String characterId,
    required List<String> characterTags,
    int maxRecursionDepth = 3,
    String? generationTrigger,
  }) {
    return findMatchingEntriesWithMetadata(
      context: context,
      entries: entries,
      characterId: characterId,
      characterTags: characterTags,
      maxRecursionDepth: maxRecursionDepth,
      generationTrigger: generationTrigger,
    ).map((match) => match.entry).toList(growable: false);
  }

  List<WorldInfoMatch> findMatchingEntriesWithMetadata({
    required WorldInfoMatchContext context,
    required List<WorldInfoEntry> entries,
    required String characterId,
    required List<String> characterTags,
    int maxRecursionDepth = 3,
    String? generationTrigger,
  }) {
    final allMatched = <WorldInfoMatch>[];
    final processedIds = <String>{};
    var currentContext = context.mergedText;
    var recursionDepth = 0;

    while (recursionDepth <= maxRecursionDepth) {
      final newMatches = <WorldInfoMatch>[];
      for (final entry in entries) {
        if (processedIds.contains(entry.id)) continue;
        if (entry.preventRecursion && recursionDepth != 0) continue;
        final matchedKey = _matchedPrimaryKey(
          entry: entry,
          mergedContext: currentContext,
          context: context,
          characterId: characterId,
          characterTags: characterTags,
          generationTrigger: generationTrigger,
        );
        if (matchedKey == null) continue;
        newMatches.add(
          WorldInfoMatch(
            entry: entry,
            activationReason: WorldInfoActivationReason.keyword,
            matchedKey: matchedKey,
          ),
        );
      }
      if (newMatches.isEmpty) break;
      for (final match in newMatches) {
        processedIds.add(match.entry.id);
        allMatched.add(match);
        currentContext = '$currentContext\n${match.entry.content}';
      }
      recursionDepth++;
    }

    for (final entry in entries) {
      final isConstant = entry.constant || entry.keys.isEmpty;
      if (!entry.enabled || !isConstant || processedIds.contains(entry.id)) {
        continue;
      }
      if (!entry.appliesToCharacter(characterId, characterTags)) continue;
      if (!entry.supportsGenerationTrigger(generationTrigger)) continue;
      allMatched.add(
        WorldInfoMatch(
          entry: entry,
          activationReason: WorldInfoActivationReason.constant,
        ),
      );
      processedIds.add(entry.id);
    }

    allMatched.sort(
      (a, b) => a.entry.insertionOrder.compareTo(b.entry.insertionOrder),
    );
    return allMatched;
  }

  Map<WorldInfoPosition, List<WorldInfoEntry>> groupByPosition(
    List<WorldInfoEntry> entries,
  ) {
    final grouped = <WorldInfoPosition, List<WorldInfoEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.position, () => <WorldInfoEntry>[]).add(entry);
    }
    return grouped;
  }

  String? _matchedPrimaryKey({
    required WorldInfoEntry entry,
    required String mergedContext,
    required WorldInfoMatchContext context,
    required String characterId,
    required List<String> characterTags,
    required String? generationTrigger,
  }) {
    if (!entry.enabled) return null;
    if (!entry.appliesToCharacter(characterId, characterTags)) return null;
    if (!entry.supportsGenerationTrigger(generationTrigger)) return null;
    if (!entry.shouldTriggerByProbability()) return null;
    if (entry.keys.isEmpty) return null;

    final scopedContext = _scopedContext(
      mergedContext: mergedContext,
      context: context,
      scanSources: entry.runtimePolicy.targeting.scanSources,
    );
    final haystack = entry.caseSensitive
        ? scopedContext
        : scopedContext.toLowerCase();

    String? matchedKey;
    for (final rawKey in entry.keys) {
      final key = rawKey.trim();
      if (key.isEmpty) continue;
      if (_matchesKey(entry: entry, haystack: haystack, key: key)) {
        matchedKey = rawKey;
        break;
      }
    }
    if (matchedKey == null) return null;
    if (!_satisfiesSecondaryKeys(entry: entry, haystack: haystack)) return null;
    return matchedKey;
  }

  bool _satisfiesSecondaryKeys({
    required WorldInfoEntry entry,
    required String haystack,
  }) {
    if (!entry.selective) return true;
    final keys = entry.secondaryKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toList(growable: false);
    if (keys.isEmpty) return true;

    var matchedCount = 0;
    for (final key in keys) {
      if (_matchesKey(entry: entry, haystack: haystack, key: key)) {
        matchedCount++;
      }
    }
    final anyMatched = matchedCount > 0;
    final allMatched = matchedCount == keys.length;
    return switch (entry.selectiveLogic) {
      1 => !allMatched,
      2 => !anyMatched,
      3 => allMatched,
      _ => anyMatched,
    };
  }

  bool _matchesKey({
    required WorldInfoEntry entry,
    required String haystack,
    required String key,
  }) {
    final needle = entry.caseSensitive ? key : key.toLowerCase();
    if (needle.isEmpty) return false;
    if (entry.matchWholeWords) {
      return RegExp(r'\b' + RegExp.escape(needle) + r'\b').hasMatch(haystack);
    }
    return haystack.contains(needle);
  }

  String _scopedContext({
    required String mergedContext,
    required WorldInfoMatchContext context,
    required List<WorldInfoScanSource> scanSources,
  }) {
    if (scanSources.isEmpty) return mergedContext;
    return context.scopedText(scanSources);
  }
}
