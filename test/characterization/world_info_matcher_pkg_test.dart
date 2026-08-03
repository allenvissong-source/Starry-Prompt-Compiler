// Characterization tests for WorldInfoMatcher, extracted from the main-project
// dual-SUT test into a pure-Dart, in-package test.
// Source of truth:
//   test/features/prompt_compiler/world_info_matcher_characterization_test.dart
// (SUT=package groups). Import rewrites + `pkg.` prefix stripped.
import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

WorldInfoEntry _pkgEntry({
  required String id,
  List<String> keys = const [],
  List<String> secondaryKeys = const [],
  String content = 'content',
  bool enabled = true,
  bool constant = false,
  bool selective = false,
  int insertionOrder = 0,
  bool caseSensitive = false,
  bool matchWholeWords = false,
  WorldInfoPosition position = WorldInfoPosition.before,
  bool preventRecursion = false,
  List<String> generationTriggers = const [],
  List<String> scanSources = const [],
}) {
  return WorldInfoEntry(
    id: id,
    worldbookId: 'wb_1',
    keys: keys,
    secondaryKeys: secondaryKeys,
    content: content,
    comment: '',
    enabled: enabled,
    constant: constant,
    selective: selective,
    insertionOrder: insertionOrder,
    caseSensitive: caseSensitive,
    matchWholeWords: matchWholeWords,
    useGroupScoring: false,
    probability: 100,
    useProbability: false,
    position: position,
    depth: 0,
    group: null,
    groupWeight: 100,
    preventRecursion: preventRecursion,
    delayUntilRecursion: false,
    scanDepth: 0,
    role: 0,
    sticky: 0,
    cooldown: 0,
    delay: 0,
    characterFilter: const <String, dynamic>{},
    generationTriggers: generationTriggers,
    scanSources: scanSources,
  );
}

List<String> _pkgIds(List<WorldInfoEntry> entries) =>
    entries.map((e) => e.id).toList(growable: false);

void main() {
  const pkgMatcher = WorldInfoMatcher();

  List<WorldInfoEntry> pkgMatch(
    List<WorldInfoEntry> entries, {
    String history = '',
    String characterDescription = '',
    String? generationTrigger,
  }) {
    final context = WorldInfoMatchContext(
      history: history,
      characterDescription: characterDescription,
    );
    return pkgMatcher.findMatchingEntries(
      context: context,
      entries: entries,
      characterId: 'char_1',
      characterTags: const <String>[],
      generationTrigger: generationTrigger,
    );
  }

  group('SUT=package | WorldInfoMatcher keyword matching (behavior baseline)', () {
    test('plain keyword substring match (case-insensitive by default)', () {
      final e = _pkgEntry(id: 'e1', keys: ['dragon']);
      expect(_pkgIds(pkgMatch([e], history: 'A DRAGON appears')), ['e1']);
      expect(pkgMatch([e], history: 'nothing here'), isEmpty);
    });

    test('caseSensitive requires exact case', () {
      final e = _pkgEntry(id: 'e1', keys: ['Dragon'], caseSensitive: true);
      expect(pkgMatch([e], history: 'a Dragon'), isNotEmpty);
      expect(pkgMatch([e], history: 'a dragon'), isEmpty);
    });

    test('matchWholeWords rejects substrings inside larger words', () {
      final e = _pkgEntry(id: 'e1', keys: ['cat'], matchWholeWords: true);
      expect(pkgMatch([e], history: 'the cat sat'), isNotEmpty);
      expect(pkgMatch([e], history: 'concatenate'), isEmpty);
    });

    test('disabled entry never matches even with keyword present', () {
      final e = _pkgEntry(id: 'e1', keys: ['dragon'], enabled: false);
      expect(pkgMatch([e], history: 'a dragon'), isEmpty);
    });

    test('empty-keys entry activates as constant even when constant=false',
        () {
      final e = _pkgEntry(id: 'e1', keys: const []);
      expect(_pkgIds(pkgMatch([e], history: 'anything')), ['e1']);
    });

    test('constant entry always activates regardless of keywords', () {
      final e = _pkgEntry(id: 'e1', keys: ['neverpresent'], constant: true);
      expect(_pkgIds(pkgMatch([e], history: 'unrelated')), ['e1']);
    });

    test('empty-keys entry is treated as constant (always on)', () {
      final e = _pkgEntry(id: 'e1', keys: const [], constant: true);
      expect(_pkgIds(pkgMatch([e], history: 'unrelated')), ['e1']);
    });
  });

  group('SUT=package | WorldInfoMatcher selective secondary keys (behavior baseline)', () {
    test('selective requires a secondary key also present', () {
      final e = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        secondaryKeys: ['fire'],
        selective: true,
      );
      expect(pkgMatch([e], history: 'a fire dragon'), isNotEmpty);
      expect(pkgMatch([e], history: 'a water dragon'), isEmpty);
    });

    test('selective with empty secondaryKeys behaves as plain match', () {
      final e = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        secondaryKeys: const [],
        selective: true,
      );
      expect(pkgMatch([e], history: 'a dragon'), isNotEmpty);
    });
  });

  group('SUT=package | WorldInfoMatcher generation trigger gating (behavior baseline)', () {
    test('entry with triggers only fires on matching trigger', () {
      final e = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        generationTriggers: const ['regenerate'],
      );
      expect(
        pkgMatch([e], history: 'a dragon', generationTrigger: 'regenerate'),
        isNotEmpty,
      );
      expect(
        pkgMatch([e], history: 'a dragon', generationTrigger: 'normal'),
        isEmpty,
      );
    });

    test('entry with no triggers fires for any trigger', () {
      final e = _pkgEntry(id: 'e1', keys: ['dragon']);
      expect(
        pkgMatch([e], history: 'a dragon', generationTrigger: 'anything'),
        isNotEmpty,
      );
    });
  });

  group('SUT=package | WorldInfoMatcher ordering & recursion (behavior baseline)', () {
    test('results sorted ascending by insertionOrder', () {
      final a = _pkgEntry(id: 'a', keys: ['k'], insertionOrder: 30);
      final b = _pkgEntry(id: 'b', keys: ['k'], insertionOrder: 10);
      final c = _pkgEntry(id: 'c', keys: ['k'], insertionOrder: 20);
      expect(_pkgIds(pkgMatch([a, b, c], history: 'k')), ['b', 'c', 'a']);
    });

    test('recursive activation: one entry content triggers another', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final e2 = _pkgEntry(id: 'e2', keys: ['treasure'], insertionOrder: 1);
      final result = _pkgIds(pkgMatch([e1, e2], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'e2']));
    });

    test('preventRecursion entry does not activate from injected content', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final e2 = _pkgEntry(
        id: 'e2',
        keys: ['treasure'],
        preventRecursion: true,
        insertionOrder: 1,
      );
      final result = _pkgIds(pkgMatch([e1, e2], history: 'a dragon'));
      expect(result, contains('e1'));
      expect(result, isNot(contains('e2')));
    });
  });
}
