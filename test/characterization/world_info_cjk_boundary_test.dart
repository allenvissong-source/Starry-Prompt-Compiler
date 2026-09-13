import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

WorldInfoEntry entry({
  required String id,
  required List<String> keys,
  List<String> secondaryKeys = const <String>[],
  bool selective = false,
  int selectiveLogic = 0,
  bool matchWholeWords = false,
}) {
  return WorldInfoEntry(
    id: id,
    worldbookId: 'wb',
    keys: keys,
    secondaryKeys: secondaryKeys,
    content: 'content',
    comment: '',
    enabled: true,
    constant: false,
    selective: selective,
    selectiveLogic: selectiveLogic,
    insertionOrder: 0,
    caseSensitive: false,
    matchWholeWords: matchWholeWords,
    useGroupScoring: false,
    probability: 100,
    useProbability: false,
    position: WorldInfoPosition.before,
    depth: 0,
    group: null,
    groupWeight: 100,
    preventRecursion: false,
    excludeRecursion: false,
    delayUntilRecursion: false,
    scanDepth: 0,
    role: 0,
    sticky: 0,
    cooldown: 0,
    delay: 0,
    characterFilter: const <String, dynamic>{},
  );
}

List<WorldInfoMatch> match(List<WorldInfoEntry> entries, String probe) {
  return const WorldInfoMatcher().findMatchingEntriesWithMetadata(
    context: WorldInfoMatchContext(history: probe),
    entries: entries,
    characterId: 'card-a',
    characterTags: const <String>[],
    maxRecursionDepth: 0,
  );
}

void main() {
  group('CJK whole-word matching', () {
    test('does not match a CJK key inside a longer word', () {
      expect(
        match(<WorldInfoEntry>[
          entry(id: 'tower', keys: <String>['塔'], matchWholeWords: true),
        ], '塔罗牌好玩吗'),
        isEmpty,
      );
    });

    test('matches a CJK key at non-CJK boundaries', () {
      final matches = match(<WorldInfoEntry>[
        entry(id: 'tower', keys: <String>['塔'], matchWholeWords: true),
      ], '这是 塔 的资料');
      expect(matches, hasLength(1));
      expect(matches.single.matchedKey, '塔');
    });

    test('applies the same boundary to secondary keys', () {
      expect(
        match(<WorldInfoEntry>[
          entry(
            id: 'e',
            keys: <String>['组织'],
            secondaryKeys: <String>['塔'],
            selective: true,
            selectiveLogic: 3,
            matchWholeWords: true,
          ),
        ], '组织和塔罗牌'),
        isEmpty,
      );
    });

    test('keeps ASCII word-boundary semantics', () {
      final item = entry(
        id: 'pus',
        keys: <String>['pus'],
        matchWholeWords: true,
      );
      expect(match(<WorldInfoEntry>[item], 'the pus agency'), hasLength(1));
      expect(match(<WorldInfoEntry>[item], 'opusculum'), isEmpty);
    });
  });
}
