// Package-internal service: WorldInfoMatcher.
//
// Provenance: extracted verbatim from
//   lib/features/chat_character/presentation/providers/world_info_providers.dart
// (class `WorldInfoMatcher`, lines 13..153 in the Starry source, sibling
// class `WorldInfoContextResolver` intentionally left behind because it
// depends on Repositories / Riverpod / Persona / CharacterEntities —
// Host-side concerns that belong to Block D wiring).
//
// Imports: only `world_info.dart` — the Starry source pulled in Flutter
// foundation, Riverpod, session_prompt_context, character_assembly_models,
// persona, starry_providers, preset_repository, resource_binding_repository,
// worldbook_repository, character_entities exclusively for the Resolver
// class; the Matcher itself is pure Dart over WorldInfoEntry /
// WorldInfoMatchContext / WorldInfoPosition / WorldInfoScanSource.
//
// Class / method / field / parameter names byte-identical to the Starry
// source, including the `const` ctor, so downstream call sites and
// characterization goldens stay valid under SUT=package.

import '../models/world_info.dart';

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
    final allMatched = <WorldInfoEntry>[];
    final processedIds = <String>{};
    var currentContext = context.mergedText;
    var recursionDepth = 0;

    while (recursionDepth <= maxRecursionDepth) {
      final newMatches = entries
          .where(
            (entry) => _matchesEntry(
              entry: entry,
              mergedContext: currentContext,
              context: context,
              characterId: characterId,
              characterTags: characterTags,
              generationTrigger: generationTrigger,
            ),
          )
          .where((entry) => !processedIds.contains(entry.id))
          .where((entry) => !entry.preventRecursion || recursionDepth == 0)
          .toList(growable: false);

      if (newMatches.isEmpty) {
        break;
      }

      for (final entry in newMatches) {
        processedIds.add(entry.id);
        allMatched.add(entry);
        currentContext = '$currentContext\n${entry.content}';
      }

      recursionDepth++;
    }

    for (final entry in entries) {
      final isConstant = entry.constant || entry.keys.isEmpty;
      if (!entry.enabled || !isConstant || processedIds.contains(entry.id)) {
        continue;
      }
      if (!entry.appliesToCharacter(characterId, characterTags)) {
        continue;
      }
      if (!entry.supportsGenerationTrigger(generationTrigger)) {
        continue;
      }
      allMatched.add(entry);
      processedIds.add(entry.id);
    }

    allMatched.sort((a, b) => a.insertionOrder.compareTo(b.insertionOrder));
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

  bool _matchesEntry({
    required WorldInfoEntry entry,
    required String mergedContext,
    required WorldInfoMatchContext context,
    required String characterId,
    required List<String> characterTags,
    required String? generationTrigger,
  }) {
    if (!entry.enabled) return false;
    if (!entry.appliesToCharacter(characterId, characterTags)) return false;
    if (!entry.supportsGenerationTrigger(generationTrigger)) return false;
    if (!entry.shouldTriggerByProbability()) return false;
    if (entry.keys.isEmpty) return false;

    final scopedContext = _scopedContext(
      mergedContext: mergedContext,
      context: context,
      scanSources: entry.runtimePolicy.targeting.scanSources,
    );
    final haystack = entry.caseSensitive
        ? scopedContext
        : scopedContext.toLowerCase();

    var keyMatched = false;
    for (final rawKey in entry.keys) {
      final key = rawKey.trim();
      if (key.isEmpty) continue;
      final needle = entry.caseSensitive ? key : key.toLowerCase();
      if (entry.matchWholeWords) {
        final regex = RegExp(r'\b' + RegExp.escape(needle) + r'\b');
        keyMatched = regex.hasMatch(haystack);
      } else {
        keyMatched = haystack.contains(needle);
      }
      if (keyMatched) {
        break;
      }
    }

    if (!keyMatched) return false;

    if (entry.selective && entry.secondaryKeys.isNotEmpty) {
      for (final rawKey in entry.secondaryKeys) {
        final key = rawKey.trim();
        if (key.isEmpty) continue;
        final needle = entry.caseSensitive ? key : key.toLowerCase();
        if (haystack.contains(needle)) {
          return true;
        }
      }
      return false;
    }

    return true;
  }

  String _scopedContext({
    required String mergedContext,
    required WorldInfoMatchContext context,
    required List<WorldInfoScanSource> scanSources,
  }) {
    if (scanSources.isEmpty) {
      return mergedContext;
    }
    return context.scopedText(scanSources);
  }
}
