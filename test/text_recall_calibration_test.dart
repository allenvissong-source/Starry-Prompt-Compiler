// Calibration for lexical recall, measured against the real Kalabiyou assets.
//
// The sweep exists to *derive* the policy rather than pick numbers that feel
// right — and it changed the design. The first attempt gated on a BM25 score
// floor alone; the measured distribution killed that idea:
//
//   「欧泊是干什么的」 → the 欧泊 entry        0.727   (wanted)
//   「晚饭吃什么」     → the father entry     2.198   (junk, via 什么)
//   「你父亲怎么了」   → the father entry     3.525   (wanted)
//
// The ranges overlap outright, so no floor separates them: raw BM25 scores are
// not comparable across queries. What does separate them is whether the query
// touches a key the author actually declared, hence
// `WorldInfoRecallOptions.requireKeyOverlap`.
//
// The printed table is the artifact. The assertions pin the resulting behavior so
// a future tokenizer or scoring change fails here instead of silently changing
// what gets injected.

import 'dart:convert';
import 'dart:io';

import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

/// A probe plus the entry id it should surface, or null for "must stay quiet".
class _Case {
  const _Case(this.probe, this.expected);
  final String probe;
  final String? expected;
}

/// Probes whose wanted entry the keyword path cannot reach, plus small-talk
/// controls that must recall nothing at all.
///
/// Every entry here is a *verified* keyword miss — see the
/// `the keyword path really does miss these probes` test, which fails if any of
/// them starts matching literally. That guard matters: 「欧泊是干什么的」 looks
/// like a good sample but contains the key 「欧泊」 verbatim, so keyword matching
/// already handles it and listing it would make these assertions pass for the
/// wrong reason.
///
/// The pattern each miss shares: the author wrote a *longer* key than the user
/// types (米雪儿的父亲 / 回归地球 / 狄拉克矿区 / 星芒咖啡 / 轮回治疗法 /
/// 官方政府). Substring matching only fires when the probe contains the whole
/// key, which is backwards — the user says the short form.
const _cases = <_Case>[
  _Case('你父亲怎么了', 'klbq-collapse:3'), // key 米雪儿的父亲
  _Case('他的父亲还好吗', 'klbq-collapse:3'),
  _Case('他们要回地球吗', 'klbq-factions:1'), // key 回归地球
  _Case('那个矿区危险吗', 'klbq-worldview-core:3'), // key 狄拉克矿区
  _Case('咖啡店在哪', 'klbq-factions:7'), // key 星芒咖啡
  _Case('有什么治疗方法', 'klbq-collapse:1'), // key 轮回治疗法
  _Case('政府是怎么管事的', 'klbq-factions:0'), // key 官方政府
  _Case('今天天气不错', null),
  _Case('晚饭吃什么', null),
  _Case('哈哈哈', null),
  _Case('你觉得怎么样', null),
];

void main() {
  final fixtures = Directory('../starry_injection_service/test/fixtures');

  group('lexical recall calibration', () {
    late List<WorldInfoEntry> entries;

    setUpAll(() {
      expect(
        fixtures.existsSync(),
        isTrue,
        reason: 'calibration needs the real assets at ${fixtures.path}',
      );
      entries = _loadEntries(fixtures);
      expect(entries.length, greaterThan(15));
    });

    test('sweep: the key-overlap gate is what buys precision', () {
      final buffer = StringBuffer()
        ..writeln('keyGate  minScore  maxCand   hit   miss   false')
        ..writeln('-----------------------------------------------');

      for (final keyGate in <bool>[false, true]) {
        for (final minScore in <double>[0.3, 0.6, 1.0, 2.0]) {
          for (final maxCandidates in <int>[2, 3, 5]) {
            var hit = 0;
            var miss = 0;
            var falsePositive = 0;
            for (final probe in _cases) {
              final recalled = _recall(
                entries: entries,
                probe: probe.probe,
                minScore: minScore,
                maxCandidates: maxCandidates,
                requireKeyOverlap: keyGate,
              );
              if (probe.expected == null) {
                falsePositive += recalled.length;
              } else if (recalled.contains(probe.expected)) {
                hit++;
              } else {
                miss++;
              }
            }
            buffer.writeln(
              '${keyGate.toString().padRight(9)}'
              '${minScore.toStringAsFixed(1).padRight(10)}'
              '${maxCandidates.toString().padRight(9)}'
              '${hit.toString().padRight(6)}'
              '${miss.toString().padRight(7)}'
              '$falsePositive',
            );
          }
        }
      }
      // ignore: avoid_print
      print(buffer);
    });

    test('raising the score floor cannot replace the key gate', () {
      // The core finding: without the gate, the floor that would silence
      // 「晚饭吃什么」 (score 2.198) also silences the wanted recall for
      // 「欧泊是干什么的」 (score 0.727). Precision and recall move together, so
      // no floor value is acceptable.
      final junkAtLowFloor = _recall(
        entries: entries,
        probe: '晚饭吃什么',
        minScore: 0.3,
        maxCandidates: 3,
        requireKeyOverlap: false,
      );
      expect(junkAtLowFloor, isNotEmpty, reason: 'junk passes a low floor');

      final wantedAtHighFloor = _recall(
        entries: entries,
        probe: '欧泊是干什么的',
        minScore: 2.2,
        maxCandidates: 3,
        requireKeyOverlap: false,
      );
      expect(
        wantedAtHighFloor,
        isNot(contains('klbq-factions:0')),
        reason: 'the floor that stops the junk also stops a wanted recall',
      );
    });

    test('defaults: every wanted probe recalls its entry', () {
      for (final probe in _cases.where((item) => item.expected != null)) {
        expect(
          _recall(entries: entries, probe: probe.probe),
          contains(probe.expected),
          reason: '"${probe.probe}" should recall ${probe.expected}',
        );
      }
    });

    test('defaults: small talk recalls nothing', () {
      for (final probe in _cases.where((item) => item.expected == null)) {
        expect(
          _recall(entries: entries, probe: probe.probe),
          isEmpty,
          reason: 'recall must not inject lore for "${probe.probe}"',
        );
      }
    });

    test('the keyword path really does miss these probes', () {
      // Guards the premise of every wanted case above. If a future change makes
      // keyword matching catch one of these, the recall assertions would still
      // pass while no longer testing recall.
      for (final probe in _cases.where((item) => item.expected != null)) {
        final keywordOnly = const WorldInfoMatcher().findMatchingEntries(
          context: WorldInfoMatchContext(history: probe.probe),
          entries: entries,
          characterId: 'card-a',
          characterTags: const <String>[],
          maxRecursionDepth: 0,
        );
        expect(
          keywordOnly.where((entry) => entry.id == probe.expected),
          isEmpty,
          reason:
              'keyword matching should still miss "${probe.probe}" — '
              'otherwise this is not a recall test',
        );
      }
    });

    test('an entry already matched by keyword is not reported as recall', () {
      // 「弦化」 is a literal key hit, so the entry must arrive as `keyword` and
      // must not appear twice. Recall runs after keyword matching and shares the
      // processed-id set precisely so this cannot happen.
      final matches = const WorldInfoMatcher().findMatchingEntriesWithMetadata(
        context: const WorldInfoMatchContext(history: '弦化到底是什么原理'),
        entries: entries,
        characterId: 'card-a',
        characterTags: const <String>[],
        maxRecursionDepth: 0,
        recall: WorldInfoRecallOptions.standard,
      );
      final target = matches
          .where((match) => match.entry.id == 'klbq-worldview-core:1')
          .toList();
      expect(target, hasLength(1));
      expect(target.single.activationReason, WorldInfoActivationReason.keyword);
      expect(target.single.matchedKey, '弦化');
      expect(target.single.score, isNull);
    });

    test('recall is deterministic across repeated passes', () {
      final first = _recall(entries: entries, probe: '你父亲怎么了');
      final second = _recall(entries: entries, probe: '你父亲怎么了');
      expect(first, second);
    });
  });
}

/// Entry ids recalled *only* by the lexical channel for [probe].
Set<String> _recall({
  required List<WorldInfoEntry> entries,
  required String probe,
  double minScore = WorldInfoRecallOptions.defaultMinScore,
  int maxCandidates = WorldInfoRecallOptions.defaultMaxCandidates,
  bool requireKeyOverlap = true,
}) {
  final matches = const WorldInfoMatcher().findMatchingEntriesWithMetadata(
    context: WorldInfoMatchContext(history: probe),
    entries: entries,
    characterId: 'card-a',
    characterTags: const <String>[],
    maxRecursionDepth: 0,
    recall: WorldInfoRecallOptions(
      minScore: minScore,
      maxCandidates: maxCandidates,
      requireKeyOverlap: requireKeyOverlap,
    ),
  );
  return <String>{
    for (final match in matches)
      if (match.activationReason == WorldInfoActivationReason.semantic)
        match.entry.id,
  };
}

/// Reads the ST-dialect fixtures directly, mapping them onto compiler entries.
///
/// Ids are `<book>:<uid>` so failures name entries the way the contract does.
List<WorldInfoEntry> _loadEntries(Directory dir) {
  final entries = <WorldInfoEntry>[];
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.worldbook.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final book = file.uri.pathSegments.last.replaceAll('.worldbook.json', '');
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final raw = json['entries'];
    final list = raw is Map
        ? raw.values.cast<Map<String, dynamic>>().toList()
        : (raw as List).cast<Map<String, dynamic>>();
    for (final item in list) {
      final uid = '${item['uid']}';
      entries.add(
        WorldInfoEntry(
          id: '$book:$uid',
          worldbookId: book,
          keys: _strings(item['key'] ?? item['keys']),
          secondaryKeys: _strings(
            item['keysecondary'] ?? item['secondary_keys'],
          ),
          content: (item['content'] ?? '').toString(),
          comment: (item['comment'] ?? '').toString(),
          enabled: item['disable'] != true,
          constant: item['constant'] == true,
          selective: item['selective'] == true,
          insertionOrder: -((item['order'] as num?)?.toInt() ?? 0),
          caseSensitive: item['caseSensitive'] == true,
          matchWholeWords: item['matchWholeWords'] == true,
          useGroupScoring: false,
          probability: (item['probability'] as num?)?.toInt() ?? 100,
          useProbability: false,
          position: WorldInfoPosition.before,
          depth: 0,
          group: null,
          groupWeight: 0,
          preventRecursion: item['preventRecursion'] == true,
          delayUntilRecursion: false,
          scanDepth: 0,
          role: 0,
          sticky: 0,
          cooldown: 0,
          delay: 0,
          characterFilter: const <String, dynamic>{},
        ),
      );
    }
  }
  return entries;
}

List<String> _strings(Object? raw) {
  if (raw is List) {
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
