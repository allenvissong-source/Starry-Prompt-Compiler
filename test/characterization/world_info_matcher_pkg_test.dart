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
  bool excludeRecursion = false,
  bool delayUntilRecursion = false,
  int? delayUntilRecursionLevel,
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
    excludeRecursion: excludeRecursion,
    delayUntilRecursion: delayUntilRecursion,
    delayUntilRecursionLevel: delayUntilRecursionLevel,
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

    // Renamed from `preventRecursion entry does not activate from injected
    // content`. That title named the wrong flag: the assertion describes
    // SillyTavern's "Non-recursable" (refuse to be activated by another entry),
    // which is `excludeRecursion`. The old name matched the implementation only
    // because the matcher read `preventRecursion` in that slot, so the golden
    // locked the mix-up in place. The behavior asserted here is unchanged.
    test('excludeRecursion entry is not activated by other entries', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final e2 = _pkgEntry(
        id: 'e2',
        keys: ['treasure'],
        excludeRecursion: true,
        insertionOrder: 1,
      );
      final result = _pkgIds(pkgMatch([e1, e2], history: 'a dragon'));
      expect(result, contains('e1'));
      expect(result, isNot(contains('e2')));
    });

    test('excludeRecursion still allows a direct hit from user text', () {
      // It closes the entrance to *other entries*, not to the user. Blocking a
      // direct hit would make the flag a mute switch.
      final e = _pkgEntry(id: 'e1', keys: ['dragon'], excludeRecursion: true);
      expect(_pkgIds(pkgMatch([e], history: 'a dragon')), ['e1']);
    });

    test('excludeRecursion entry still feeds the cascade itself', () {
      // Entrance closed, exit open: it can activate others even though others
      // cannot activate it.
      final e1 = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        content: 'guards treasure',
        excludeRecursion: true,
      );
      final e2 = _pkgEntry(id: 'e2', keys: ['treasure'], insertionOrder: 1);
      final result = _pkgIds(pkgMatch([e1, e2], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'e2']));
    });

    test('preventRecursion entry is injected but feeds nothing downstream', () {
      // The real semantics, never implemented before: SillyTavern's
      // `successfulNewEntries.filter(x => !x.preventRecursion)` withholds the
      // entry's text from the scan buffer while still injecting the entry.
      final e1 = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        content: 'guards treasure',
        preventRecursion: true,
      );
      final e2 = _pkgEntry(id: 'e2', keys: ['treasure'], insertionOrder: 1);
      final result = _pkgIds(pkgMatch([e1, e2], history: 'a dragon'));
      expect(result, contains('e1'), reason: 'the entry itself still injects');
      expect(result, isNot(contains('e2')), reason: 'its content cannot cascade');
    });

    test('preventRecursion on every hit ends the cascade', () {
      final e1 = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        content: 'guards treasure',
        preventRecursion: true,
      );
      final e2 = _pkgEntry(
        id: 'e2',
        keys: ['dragon'],
        content: 'hoards gold',
        preventRecursion: true,
      );
      final e3 = _pkgEntry(id: 'e3', keys: ['treasure'], insertionOrder: 1);
      final e4 = _pkgEntry(id: 'e4', keys: ['gold'], insertionOrder: 2);
      final result = _pkgIds(pkgMatch([e1, e2, e3, e4], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'e2']));
      expect(result, isNot(contains('e3')));
      expect(result, isNot(contains('e4')));
    });

    test('the two recursion flags are independent', () {
      // Entrance and exit both closed: injected on a direct hit, reachable by
      // nobody, and feeding nobody.
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final e2 = _pkgEntry(
        id: 'e2',
        keys: ['treasure', 'dragon'],
        content: 'buried gold',
        preventRecursion: true,
        excludeRecursion: true,
        insertionOrder: 1,
      );
      final e3 = _pkgEntry(id: 'e3', keys: ['gold'], insertionOrder: 2);

      final direct = _pkgIds(pkgMatch([e1, e2, e3], history: 'a dragon'));
      expect(direct, containsAll(<String>['e1', 'e2']));
      expect(direct, isNot(contains('e3')), reason: 'exit closed');
    });
  });

  group('SUT=package | delayUntilRecursion', () {
    test('a delayed entry with nothing to trigger it stays silent', () {
      // Matches SillyTavern: the first pass suppresses it, and since its level is
      // consumed at init there is no queued level left to force a recursion pass.
      // "Delay until recursion" means another entry must bring it in — it is not
      // a "fire one pass later" switch.
      final e = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        delayUntilRecursion: true,
      );
      expect(pkgMatch([e], history: 'a dragon'), isEmpty);
    });

    test('a delayed entry fires once recursion begins', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final e2 = _pkgEntry(
        id: 'e2',
        keys: ['treasure'],
        delayUntilRecursion: true,
        insertionOrder: 1,
      );
      final result = _pkgIds(pkgMatch([e1, e2], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'e2']));
    });

    test('true means level 1, so it opens in the first recursion pass', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final lvl1 = _pkgEntry(
        id: 'lvl1',
        keys: ['treasure'],
        delayUntilRecursion: true,
        insertionOrder: 1,
      );
      final explicit = _pkgEntry(
        id: 'explicit',
        keys: ['treasure'],
        delayUntilRecursion: true,
        delayUntilRecursionLevel: 1,
        insertionOrder: 2,
      );
      final result = _pkgIds(pkgMatch([e1, lvl1, explicit], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'lvl1', 'explicit']));
    });

    test('a higher level waits until its own level opens', () {
      // The level-2 entry shares the level-1 entry's key, so it *could* have
      // matched in the same pass; only the level gate holds it back, and it must
      // still arrive once that level opens.
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final lvl1 = _pkgEntry(
        id: 'lvl1',
        keys: ['treasure'],
        delayUntilRecursion: true,
        delayUntilRecursionLevel: 1,
        insertionOrder: 1,
      );
      final lvl2 = _pkgEntry(
        id: 'lvl2',
        keys: ['treasure'],
        delayUntilRecursion: true,
        delayUntilRecursionLevel: 2,
        insertionOrder: 2,
      );
      final result = _pkgIds(pkgMatch([e1, lvl1, lvl2], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'lvl1', 'lvl2']));
    });

    test('sparse levels open in ascending order, deterministically', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      List<String> run() {
        final entries = <WorldInfoEntry>[
          e1,
          _pkgEntry(
            id: 'l7',
            keys: ['treasure'],
            delayUntilRecursion: true,
            delayUntilRecursionLevel: 7,
            insertionOrder: 7,
          ),
          _pkgEntry(
            id: 'l1',
            keys: ['treasure'],
            delayUntilRecursion: true,
            delayUntilRecursionLevel: 1,
            insertionOrder: 1,
          ),
          _pkgEntry(
            id: 'l3',
            keys: ['treasure'],
            delayUntilRecursion: true,
            delayUntilRecursionLevel: 3,
            insertionOrder: 3,
          ),
        ];
        // Levels are declared out of order here on purpose; each one that opens
        // also spends a depth step, so the cap is raised to let all three run and
        // isolate ordering from budget.
        return _pkgIds(
          pkgMatcher.findMatchingEntries(
            context: const WorldInfoMatchContext(history: 'a dragon'),
            entries: entries,
            characterId: 'char_1',
            characterTags: const <String>[],
            maxRecursionDepth: 10,
          ),
        );
      }

      final first = run();
      expect(first, containsAll(<String>['e1', 'l1', 'l3', 'l7']));
      expect(run(), first, reason: 'level order must not depend on iteration');
    });

    test('level advancement cannot outrun maxRecursionDepth', () {
      // Delayed levels must not become a back door around the depth cap. Same
      // entries as above, but with the default budget the deepest level is never
      // reached — the cap wins.
      final entries = <WorldInfoEntry>[
        _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure'),
        _pkgEntry(
          id: 'l1',
          keys: ['treasure'],
          delayUntilRecursion: true,
          delayUntilRecursionLevel: 1,
          insertionOrder: 1,
        ),
        _pkgEntry(
          id: 'l7',
          keys: ['treasure'],
          delayUntilRecursion: true,
          delayUntilRecursionLevel: 7,
          insertionOrder: 7,
        ),
      ];
      final result = _pkgIds(
        pkgMatcher.findMatchingEntries(
          context: const WorldInfoMatchContext(history: 'a dragon'),
          entries: entries,
          characterId: 'char_1',
          characterTags: const <String>[],
          maxRecursionDepth: 1,
        ),
      );
      expect(result, containsAll(<String>['e1', 'l1']));
      expect(result, isNot(contains('l7')));
    });

    test('entries sharing a level open together', () {
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final a = _pkgEntry(
        id: 'a',
        keys: ['treasure'],
        delayUntilRecursion: true,
        delayUntilRecursionLevel: 2,
        insertionOrder: 1,
      );
      final b = _pkgEntry(
        id: 'b',
        keys: ['treasure'],
        delayUntilRecursion: true,
        delayUntilRecursionLevel: 2,
        insertionOrder: 2,
      );
      final result = _pkgIds(pkgMatch([e1, a, b], history: 'a dragon'));
      expect(result, containsAll(<String>['e1', 'a', 'b']));
    });

    test('a level without the gate is ignored, not promoted to a delay', () {
      // Guards the one risk of carrying the level outside the canonical field:
      // the boolean is authoritative, so a stray level must not delay an entry
      // its author never delayed.
      final e = _pkgEntry(
        id: 'e1',
        keys: ['dragon'],
        delayUntilRecursionLevel: 3,
      );
      expect(_pkgIds(pkgMatch([e], history: 'a dragon')), ['e1']);
    });

    test('a delayed entry never activates when recursion is off', () {
      // `maxRecursionDepth: 0` is how a book with `recursive_scanning: false`
      // reaches the matcher. SillyTavern agrees: its level gate only applies
      // inside a recursion pass, which that setting makes unreachable. Delayed
      // levels must not become a back door around the depth cap.
      final e1 = _pkgEntry(id: 'e1', keys: ['dragon'], content: 'guards treasure');
      final e2 = _pkgEntry(
        id: 'e2',
        keys: ['treasure'],
        delayUntilRecursion: true,
        insertionOrder: 1,
      );
      final result = pkgMatcher.findMatchingEntries(
        context: const WorldInfoMatchContext(history: 'a dragon'),
        entries: <WorldInfoEntry>[e1, e2],
        characterId: 'char_1',
        characterTags: const <String>[],
        maxRecursionDepth: 0,
      );
      expect(_pkgIds(result), ['e1']);
    });

    test('a constant entry ignores the recursion gates entirely', () {
      // The constant sweep runs after the cascade, so these flags never apply.
      final e = _pkgEntry(
        id: 'e1',
        keys: const [],
        constant: true,
        delayUntilRecursion: true,
        excludeRecursion: true,
        preventRecursion: true,
      );
      expect(_pkgIds(pkgMatch([e], history: 'unrelated')), ['e1']);
    });
  });
}
