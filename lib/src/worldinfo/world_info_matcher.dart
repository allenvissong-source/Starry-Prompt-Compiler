// Package-internal service: WorldInfoMatcher.
//
// Provenance: extracted from the Starry host matcher while keeping this package
// pure Dart over WorldInfoEntry / WorldInfoMatchContext.

import 'dart:collection';

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

    // Delay levels open one at a time, lowest first, mirroring SillyTavern's
    // `availableRecursionDelayLevels`. Deduplicated and sorted so the order is a
    // pure function of the entry set rather than of map iteration.
    final pendingDelayLevels = SplayTreeSet<int>();
    for (final entry in entries) {
      final level = entry.effectiveDelayLevel;
      if (level != null) pendingDelayLevels.add(level);
    }
    // The lowest level is consumed up front, exactly as SillyTavern does
    // (`currentRecursionDelayLevel = available.shift() ?? 0`). Two behaviors
    // depend on this and both would be wrong if the loop opened it instead:
    // level 1 must already be open during the *first* recursion pass rather than
    // costing a depth step, and only the levels still queued afterwards may
    // extend scanning past the point where cascading stops.
    var currentDelayLevel = 0;
    if (pendingDelayLevels.isNotEmpty) {
      currentDelayLevel = pendingDelayLevels.first;
      pendingDelayLevels.remove(currentDelayLevel);
    }

    while (recursionDepth <= maxRecursionDepth) {
      final isRecursionPass = recursionDepth != 0;
      final newMatches = <WorldInfoMatch>[];
      for (final entry in entries) {
        if (processedIds.contains(entry.id)) continue;
        // "Non-recursable": refuses to be activated *by another entry*. A direct
        // hit on the user's own text still counts, which is why this is scoped to
        // recursion passes only.
        if (entry.excludeRecursion && isRecursionPass) continue;
        // "Delay until recursion": invisible outside recursion, and inside it
        // only once its level has been opened.
        final delayLevel = entry.effectiveDelayLevel;
        if (delayLevel != null &&
            (!isRecursionPass || delayLevel > currentDelayLevel)) {
          continue;
        }
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

      // Only entries that may feed the cascade extend the scan text. This is
      // SillyTavern's `successfulNewEntries.filter(x => !x.preventRecursion)`:
      // "Prevent further recursion" still injects the entry, it just withholds
      // its text from the next pass.
      final cascadeText = <String>[];
      for (final match in newMatches) {
        processedIds.add(match.entry.id);
        allMatched.add(match);
        if (!match.entry.preventRecursion) {
          cascadeText.add(match.entry.content);
        }
      }

      if (cascadeText.isEmpty) {
        // Cascading has stalled. SillyTavern's escape hatch — advance to the next
        // queued delay level and keep scanning — applies only when a level is
        // still queued, so a lone delayed entry with nothing to trigger it stays
        // silent instead of quietly firing anyway.
        final nextLevel = pendingDelayLevels.firstOrNull;
        if (nextLevel == null || recursionDepth >= maxRecursionDepth) break;
        pendingDelayLevels.remove(nextLevel);
        currentDelayLevel = nextLevel;
        // Delayed entries only activate inside a recursion pass, so make sure the
        // next iteration is one even if the very first pass matched nothing.
        recursionDepth = recursionDepth == 0 ? 1 : recursionDepth + 1;
        continue;
      }

      currentContext = '$currentContext\n${cascadeText.join('\n')}';
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
