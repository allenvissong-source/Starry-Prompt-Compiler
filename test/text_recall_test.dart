// Unit tests for tokenization, BM25 scoring, the CJK whole-word fix, and the
// recall channel's gating.
//
// Split from the calibration test on purpose: that one measures policy against
// the real assets, this one pins mechanics with synthetic input.

import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

/// Builds an entry with the knobs these tests care about; everything else takes
/// a neutral value so a test only states what it is actually about.
WorldInfoEntry entry({
  required String id,
  List<String> keys = const <String>[],
  List<String> secondaryKeys = const <String>[],
  String content = '',
  String comment = '',
  bool enabled = true,
  bool constant = false,
  bool selective = false,
  int selectiveLogic = 0,
  bool caseSensitive = false,
  bool matchWholeWords = false,
  bool preventRecursion = false,
  bool excludeRecursion = false,
  bool delayUntilRecursion = false,
  int? delayUntilRecursionLevel,
  int insertionOrder = 0,
  int probability = 100,
  bool useProbability = false,
  Map<String, dynamic> characterFilter = const <String, dynamic>{},
  List<String> scanSources = const <String>[],
  List<String> generationTriggers = const <String>[],
}) {
  return WorldInfoEntry(
    id: id,
    worldbookId: 'book',
    keys: keys,
    secondaryKeys: secondaryKeys,
    content: content,
    comment: comment,
    enabled: enabled,
    constant: constant,
    selective: selective,
    selectiveLogic: selectiveLogic,
    insertionOrder: insertionOrder,
    caseSensitive: caseSensitive,
    matchWholeWords: matchWholeWords,
    useGroupScoring: false,
    probability: probability,
    useProbability: useProbability,
    position: WorldInfoPosition.before,
    depth: 0,
    group: null,
    groupWeight: 0,
    preventRecursion: preventRecursion,
    excludeRecursion: excludeRecursion,
    delayUntilRecursion: delayUntilRecursion,
    delayUntilRecursionLevel: delayUntilRecursionLevel,
    scanDepth: 0,
    role: 0,
    sticky: 0,
    cooldown: 0,
    delay: 0,
    characterFilter: characterFilter,
    scanSources: scanSources,
    generationTriggers: generationTriggers,
  );
}

/// Runs a matching pass. Recall uses the shipped defaults unless a test is
/// specifically about a threshold, mirroring production: there is no off switch.
List<WorldInfoMatch> match(
  List<WorldInfoEntry> entries, {
  required String probe,
  WorldInfoRecallOptions recall = WorldInfoRecallOptions.standard,
  String characterId = 'card-a',
  List<String> characterTags = const <String>[],
  WorldInfoMatchContext? context,
  RecallTokenizer tokenizer = const BigramRecallTokenizer(),
}) {
  return WorldInfoMatcher(tokenizer: tokenizer).findMatchingEntriesWithMetadata(
    context: context ?? WorldInfoMatchContext(history: probe),
    entries: entries,
    characterId: characterId,
    characterTags: characterTags,
    maxRecursionDepth: 0,
    recall: recall,
  );
}

Set<String> semanticIds(List<WorldInfoMatch> matches) => <String>{
  for (final item in matches)
    if (item.activationReason == WorldInfoActivationReason.semantic)
      item.entry.id,
};

void main() {
  group('tokenizeForRecall', () {
    test('CJK text becomes adjacent-character bigrams', () {
      expect(tokenizeForRecall('父亲怎么'), <String>['父亲', '亲怎', '怎么']);
    });

    test('a lone CJK character indexes as itself', () {
      // Otherwise single-character keys such as 「塔」 would be unindexable.
      expect(tokenizeForRecall('塔'), <String>['塔']);
    });

    test('Latin words are whole tokens, lower-cased', () {
      expect(tokenizeForRecall('Hello World'), <String>['hello', 'world']);
    });

    test('mixed script yields both token families', () {
      expect(tokenizeForRecall('弦化Scissors'), <String>['弦化', 'scissors']);
    });

    test('punctuation and whitespace separate runs', () {
      expect(tokenizeForRecall('父亲，昏迷'), <String>['父亲', '昏迷']);
      expect(tokenizeForRecall('P.U.S.'), <String>['p', 'u', 's']);
    });

    test('empty and symbol-only input yield nothing', () {
      expect(tokenizeForRecall(''), isEmpty);
      expect(tokenizeForRecall('？！…'), isEmpty);
    });

    test('digits tokenize', () {
      expect(tokenizeForRecall('2D'), <String>['2d']);
    });

    test('repeated calls are byte-identical', () {
      const text = '米雪儿的父亲 George 2D';
      expect(tokenizeForRecall(text), tokenizeForRecall(text));
    });
  });

  group('Bm25Ranker', () {
    test('a document repeating the term outranks one mentioning it once', () {
      final hits = const Bm25Ranker().rank(
        query: '父亲',
        documents: const <RecallDocument>[
          RecallDocument(id: 'once', text: '父亲在这里'),
          RecallDocument(id: 'twice', text: '父亲父亲都在'),
          RecallDocument(id: 'none', text: '完全无关的内容'),
        ],
      );
      expect(hits.map((hit) => hit.documentId), <String>['twice', 'once']);
    });

    test('a term in every document is heavily discounted', () {
      // With the standard `+1` smoothing, IDF at df == N is log(1.2) ≈ 0.18 —
      // small but not zero. That is enough: a ubiquitous word like 世界 scores an
      // order of magnitude below a rare one, so it cannot dominate the ranking.
      final common = const Bm25Ranker().rank(
        query: '世界',
        documents: const <RecallDocument>[
          RecallDocument(id: 'a', text: '世界'),
          RecallDocument(id: 'b', text: '世界'),
        ],
      );
      final rare = const Bm25Ranker().rank(
        query: '弦化',
        documents: const <RecallDocument>[
          RecallDocument(id: 'a', text: '弦化'),
          RecallDocument(id: 'b', text: '无关内容'),
        ],
      );
      expect(common.first.score, lessThan(rare.first.score / 3));
    });

    test('length normalization keeps a long document from winning by size', () {
      final hits = const Bm25Ranker().rank(
        query: '父亲',
        documents: <RecallDocument>[
          const RecallDocument(id: 'short', text: '父亲'),
          RecallDocument(id: 'long', text: '父亲${'其他内容' * 40}'),
        ],
      );
      expect(hits.first.documentId, 'short');
    });

    test('equal scores break ties on id', () {
      final hits = const Bm25Ranker().rank(
        query: '父亲',
        documents: const <RecallDocument>[
          RecallDocument(id: 'b', text: '父亲'),
          RecallDocument(id: 'a', text: '父亲'),
        ],
      );
      expect(hits.map((hit) => hit.documentId), <String>['a', 'b']);
    });

    test('bestKey names the key sharing the most tokens with the query', () {
      final hits = const Bm25Ranker().rank(
        query: '你父亲怎么了',
        documents: const <RecallDocument>[
          RecallDocument(
            id: 'a',
            text: '关于父亲的记载',
            keys: <String>['乔治', '米雪儿的父亲'],
          ),
        ],
      );
      expect(hits.single.bestKey, '米雪儿的父亲');
    });

    test('bestKey is null when only the body matched', () {
      final hits = const Bm25Ranker().rank(
        query: '父亲',
        documents: const <RecallDocument>[
          RecallDocument(id: 'a', text: '父亲出现在此处', keys: <String>['乔治']),
        ],
      );
      expect(hits.single.bestKey, isNull);
    });

    test('an empty corpus or query yields nothing', () {
      expect(
        const Bm25Ranker().rank(query: '父亲', documents: const []),
        isEmpty,
      );
      expect(
        const Bm25Ranker().rank(
          query: '！！',
          documents: const <RecallDocument>[
            RecallDocument(id: 'a', text: '父亲'),
          ],
        ),
        isEmpty,
      );
    });

    test('eligibility does not weaken as unrelated documents are added', () {
      // Regression guard for a real bug: an optimization once scoped the corpus
      // statistics to the documents that survived key screening, which made the
      // same entry score 0.42 alone but 0.288 within its full binding — dropping
      // it below the default floor. Whether an entry is recalled must not depend
      // on how many unrelated books happen to be bound.
      //
      // The score itself is *expected* to move: a term is genuinely rarer in a
      // larger corpus, and rising IDF is what BM25 is defined to do. What must not
      // happen is the score sagging toward the floor as the binding grows, since
      // that silently disables recall for users with many books.
      const target = RecallDocument(
        id: 'a',
        text: '关于父亲的记载',
        keys: <String>['米雪儿的父亲'],
      );
      double scoreWith(int others) {
        final hits = const Bm25Ranker().rank(
          query: '你父亲怎么了',
          documents: <RecallDocument>[
            target,
            for (var i = 0; i < others; i++)
              RecallDocument(id: 'other$i', text: '毫无关联的条目$i'),
          ],
          requireKeyOverlap: true,
        );
        expect(hits.map((hit) => hit.documentId), <String>['a']);
        return hits.single.score;
      }

      final alone = scoreWith(0);
      for (final others in <int>[1, 12, 60]) {
        final crowded = scoreWith(others);
        expect(
          crowded,
          greaterThanOrEqualTo(alone),
          reason: 'adding $others unrelated documents must not weaken the hit',
        );
        expect(
          crowded,
          greaterThan(WorldInfoRecallOptions.defaultMinScore),
          reason: 'a hit must stay above the floor regardless of binding size',
        );
      }
    });

    test('key screening does not change which documents are returned', () {
      // The screen is an optimization, so it must be observationally equivalent to
      // scoring everything and letting the caller drop null-`bestKey` hits.
      final documents = <RecallDocument>[
        const RecallDocument(id: 'keyed', text: '父亲', keys: <String>['米雪儿的父亲']),
        const RecallDocument(id: 'body-only', text: '这里也提到父亲'),
      ];
      final screened = const Bm25Ranker().rank(
        query: '你父亲怎么了',
        documents: documents,
        requireKeyOverlap: true,
      );
      final unscreened = const Bm25Ranker()
          .rank(query: '你父亲怎么了', documents: documents)
          .where((hit) => hit.bestKey != null);
      expect(
        screened.map((hit) => hit.documentId),
        unscreened.map((hit) => hit.documentId),
      );
      expect(
        screened.map((hit) => hit.score),
        unscreened.map((hit) => hit.score),
      );
    });
  });

  group('matchWholeWords for CJK', () {
    test('a CJK key no longer matches inside a longer word', () {
      // 「塔罗牌」 must not fire the key 「塔」.
      final matches = match(
        <WorldInfoEntry>[
          entry(id: 'tower', keys: <String>['塔'], matchWholeWords: true),
        ],
        probe: '塔罗牌好玩吗',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(matches, isEmpty);
    });

    test('a CJK key matches when nothing CJK abuts it', () {
      // Measured baseline: `RegExp(r'\b塔\b')` is false even here, so before this
      // fix `matchWholeWords: true` made a Chinese key unmatchable outright — the
      // flag disabled the entry rather than narrowing it.
      final matches = match(
        <WorldInfoEntry>[
          entry(id: 'tower', keys: <String>['塔'], matchWholeWords: true),
        ],
        probe: '这是 塔 的资料',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(matches, hasLength(1));
      expect(matches.single.matchedKey, '塔');
    });

    test('the boundary rule applies to multi-character keys too', () {
      // 「科摩斯塔在哪」 has a CJK neighbour (在) right after the key, so whole-word
      // mode rejects it; a punctuation boundary accepts it.
      final abutted = match(
        <WorldInfoEntry>[
          entry(id: 'tower', keys: <String>['科摩斯塔'], matchWholeWords: true),
        ],
        probe: '科摩斯塔在哪',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(abutted, isEmpty);

      final bounded = match(
        <WorldInfoEntry>[
          entry(id: 'tower', keys: <String>['科摩斯塔'], matchWholeWords: true),
        ],
        probe: '目的地：科摩斯塔。',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(bounded, hasLength(1));
    });

    test('substring mode is unchanged', () {
      final matches = match(
        <WorldInfoEntry>[
          entry(id: 'tower', keys: <String>['塔']),
        ],
        probe: '塔罗牌好玩吗',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(matches, hasLength(1), reason: 'opt-in only; default unaffected');
    });

    test('ASCII keys keep word-boundary semantics', () {
      final onWord = match(
        <WorldInfoEntry>[
          entry(id: 'pus', keys: <String>['pus'], matchWholeWords: true),
        ],
        probe: 'the pus agency',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(onWord, hasLength(1));

      final inWord = match(
        <WorldInfoEntry>[
          entry(id: 'pus', keys: <String>['pus'], matchWholeWords: true),
        ],
        probe: 'opusculum',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(inWord, isEmpty);
    });

    test('secondary keys honor the same rule', () {
      final matches = match(
        <WorldInfoEntry>[
          entry(
            id: 'e',
            keys: <String>['组织'],
            secondaryKeys: <String>['塔'],
            selective: true,
            selectiveLogic: 3, // AND_ALL
            matchWholeWords: true,
          ),
        ],
        probe: '组织和塔罗牌',
        recall: WorldInfoRecallOptions.keywordOnlyBaseline,
      );
      expect(matches, isEmpty, reason: '塔 must not match inside 塔罗牌');
    });
  });

  group('recall channel', () {
    test('the keyword engine alone leaves this probe unmatched', () {
      // The premise for the next test. `keywordOnlyBaseline` is what
      // `findMatchingEntries` uses to describe the pre-recall engine; it is not a
      // supported production setting.
      final entries = <WorldInfoEntry>[
        entry(id: 'father', keys: <String>['米雪儿的父亲'], content: '父亲的记载'),
      ];
      expect(
        match(
          entries,
          probe: '你父亲怎么了',
          recall: WorldInfoRecallOptions.keywordOnlyBaseline,
        ),
        isEmpty,
      );
    });

    test('recall reaches the entry the keyword path missed', () {
      final entries = <WorldInfoEntry>[
        entry(id: 'father', keys: <String>['米雪儿的父亲'], content: '父亲的记载'),
      ];
      final matches = match(entries, probe: '你父亲怎么了');
      expect(matches, hasLength(1));
      expect(
        matches.single.activationReason,
        WorldInfoActivationReason.semantic,
      );
      expect(matches.single.matchedKey, '米雪儿的父亲');
      expect(matches.single.score, greaterThan(0));
    });

    test('recall runs without being asked for', () {
      // The point of removing the switch: a caller that says nothing about recall
      // still gets it, because the alternative is silently broken Chinese matching.
      final entries = <WorldInfoEntry>[
        entry(id: 'father', keys: <String>['米雪儿的父亲'], content: '父亲的记载'),
      ];
      final matches = const WorldInfoMatcher().findMatchingEntriesWithMetadata(
        context: const WorldInfoMatchContext(history: '你父亲怎么了'),
        entries: entries,
        characterId: 'card-a',
        characterTags: const <String>[],
        maxRecursionDepth: 0,
        // deliberately no `recall:` argument
      );
      expect(semanticIds(matches), <String>{'father'});
    });

    test('requireKeyOverlap rejects body-only relevance', () {
      // Without the gate this is the junk case: a function word in the prose is
      // enough to inject unrelated lore.
      final entries = <WorldInfoEntry>[
        entry(id: 'e', keys: <String>['乔治'], content: '晚饭吃什么都可以'),
      ];
      expect(semanticIds(match(entries, probe: '晚饭吃什么')), isEmpty);
      expect(
        semanticIds(
          match(
            entries,
            probe: '晚饭吃什么',
            recall: const WorldInfoRecallOptions(requireKeyOverlap: false),
          ),
        ),
        <String>{'e'},
      );
    });

    test('a keyword hit is not also reported as recall', () {
      final entries = <WorldInfoEntry>[
        entry(id: 'e', keys: <String>['父亲'], content: '父亲'),
      ];
      final matches = match(entries, probe: '父亲怎么了');
      expect(matches, hasLength(1));
      expect(
        matches.single.activationReason,
        WorldInfoActivationReason.keyword,
      );
    });

    test('maxCandidates caps how many entries recall may add', () {
      // minScore is lowered because a tiny synthetic corpus scores far below the
      // real-asset range; this test is about the cap, not the floor.
      final entries = <WorldInfoEntry>[
        for (var i = 0; i < 5; i++)
          entry(id: 'e$i', keys: <String>['米雪儿的父亲$i'], content: '父亲$i'),
      ];
      expect(
        semanticIds(
          match(
            entries,
            probe: '你父亲怎么了',
            recall: const WorldInfoRecallOptions(
              minScore: 0.05,
              maxCandidates: 2,
            ),
          ),
        ),
        hasLength(2),
      );
    });

    test('maxCandidates of zero admits nothing', () {
      // The same mechanism `keywordOnlyBaseline` is built on: a cap of zero is a
      // point on the reach scale, not a feature flag.
      final entries = <WorldInfoEntry>[
        entry(id: 'e', keys: <String>['米雪儿的父亲'], content: '父亲'),
      ];
      expect(
        semanticIds(
          match(
            entries,
            probe: '你父亲怎么了',
            recall: const WorldInfoRecallOptions(maxCandidates: 0),
          ),
        ),
        isEmpty,
      );
    });

    test('a high minScore drops weak recalls without erroring', () {
      final entries = <WorldInfoEntry>[
        entry(id: 'e', keys: <String>['米雪儿的父亲'], content: '父亲'),
      ];
      expect(
        semanticIds(
          match(
            entries,
            probe: '你父亲怎么了',
            recall: const WorldInfoRecallOptions(minScore: 999),
          ),
        ),
        isEmpty,
      );
    });

    group('recall respects every gate keyword matching respects', () {
      test('disabled entries never recall', () {
        expect(
          semanticIds(
            match(<WorldInfoEntry>[
              entry(
                id: 'e',
                keys: <String>['米雪儿的父亲'],
                content: '父亲',
                enabled: false,
              ),
            ], probe: '你父亲怎么了'),
          ),
          isEmpty,
        );
      });

      test('a character filter excluding this character blocks recall', () {
        expect(
          semanticIds(
            match(<WorldInfoEntry>[
              entry(
                id: 'e',
                keys: <String>['米雪儿的父亲'],
                content: '父亲',
                characterFilter: const <String, dynamic>{
                  'type': 'include',
                  'character_ids': <String>['someone-else'],
                },
              ),
            ], probe: '你父亲怎么了'),
          ),
          isEmpty,
        );
      });

      test('a generation trigger the entry does not support blocks recall', () {
        // Chosen over `probability` for determinism: `shouldTriggerByProbability`
        // treats 0 and >=100 as "no limit" and consults the wall clock in between,
        // so it cannot be asserted reliably. The gate itself is exercised in
        // `_recallMatches` alongside this one.
        final entries = <WorldInfoEntry>[
          entry(
            id: 'e',
            keys: <String>['米雪儿的父亲'],
            content: '父亲',
            generationTriggers: <String>['swipe'],
          ),
        ];
        final matches = const WorldInfoMatcher()
            .findMatchingEntriesWithMetadata(
              context: const WorldInfoMatchContext(history: '你父亲怎么了'),
              entries: entries,
              characterId: 'card-a',
              characterTags: const <String>[],
              maxRecursionDepth: 0,
              generationTrigger: 'continue',
              recall: const WorldInfoRecallOptions(minScore: 0.05),
            );
        expect(semanticIds(matches), isEmpty);
      });

      test('selectiveLogic NOT_ANY vetoes a recall hit', () {
        expect(
          semanticIds(
            match(<WorldInfoEntry>[
              entry(
                id: 'e',
                keys: <String>['米雪儿的父亲'],
                secondaryKeys: <String>['昏迷'],
                selective: true,
                selectiveLogic: 2, // NOT_ANY
                content: '父亲',
              ),
            ], probe: '你父亲昏迷了吗'),
          ),
          isEmpty,
          reason: 'the secondary key is present, so NOT_ANY must veto',
        );
      });

      test('selectiveLogic AND_ALL admits when secondary keys are present', () {
        expect(
          semanticIds(
            match(<WorldInfoEntry>[
              entry(
                id: 'e',
                keys: <String>['米雪儿的父亲'],
                secondaryKeys: <String>['昏迷'],
                selective: true,
                selectiveLogic: 3, // AND_ALL
                content: '父亲',
              ),
            ], probe: '你父亲昏迷了吗'),
          ),
          <String>{'e'},
        );
      });
    });

    test('recall candidates do not feed the cascade', () {
      // Recall must not seed recursion: cascading already over-expands on
      // cross-referencing books, and probabilistic hits would compound it.
      final entries = <WorldInfoEntry>[
        entry(id: 'a', keys: <String>['米雪儿的父亲'], content: '提到了昏迷'),
        entry(id: 'b', keys: <String>['昏迷'], content: '终点'),
      ];
      final matches = const WorldInfoMatcher().findMatchingEntriesWithMetadata(
        context: const WorldInfoMatchContext(history: '你父亲怎么了'),
        entries: entries,
        characterId: 'card-a',
        characterTags: const <String>[],
        maxRecursionDepth: 3, // cascading allowed
        recall: WorldInfoRecallOptions.standard,
      );
      expect(matches.map((item) => item.entry.id), <String>['a']);
    });

    test('constant entries are unaffected by recall', () {
      final entries = <WorldInfoEntry>[
        entry(id: 'c', keys: <String>['无关'], constant: true, content: '常驻'),
      ];
      final matches = match(entries, probe: '你父亲怎么了');
      expect(matches, hasLength(1));
      expect(
        matches.single.activationReason,
        WorldInfoActivationReason.constant,
      );
      expect(matches.single.score, isNull);
    });

    test('recall scores against the entry\'s own scan scope', () {
      // An entry that opted into scanning the scenario is scored on the same text
      // a keyword would have seen — not on the probe alone.
      final entries = <WorldInfoEntry>[
        entry(
          id: 'e',
          keys: <String>['狄拉克矿区'],
          content: '矿区资料',
          scanSources: <String>['scenario'],
        ),
      ];
      final matches = const WorldInfoMatcher().findMatchingEntriesWithMetadata(
        context: const WorldInfoMatchContext(
          history: '闲聊',
          scenario: '他们在矿区附近扎营',
        ),
        entries: entries,
        characterId: 'card-a',
        characterTags: const <String>[],
        maxRecursionDepth: 0,
        recall: WorldInfoRecallOptions.standard,
      );
      expect(semanticIds(matches), <String>{'e'});
    });

    test('results stay sorted by insertionOrder', () {
      final entries = <WorldInfoEntry>[
        entry(
          id: 'late',
          keys: <String>['米雪儿的父亲'],
          content: '父亲',
          insertionOrder: 10,
        ),
        entry(
          id: 'early',
          keys: <String>['父亲的病历'],
          content: '父亲',
          insertionOrder: -10,
        ),
      ];
      final matches = match(
        entries,
        probe: '你父亲怎么了',
        recall: const WorldInfoRecallOptions(minScore: 0.05),
      );
      expect(matches.map((item) => item.entry.id), <String>['early', 'late']);
    });

    group('recall and the recursion flags', () {
      test('a delayed entry is never recalled', () {
        // Recall fires straight off the user's text, which is exactly what
        // "delay until recursion" asks to avoid: the author wants this entry
        // reached only through another entry. Scoring it would route around the
        // requested gate, so recall skips it — the same entry recalls fine once
        // the delay is removed, which is what the second half proves.
        final delayed = <WorldInfoEntry>[
          entry(
            id: 'father',
            keys: <String>['米雪儿的父亲'],
            content: '父亲的记载',
            delayUntilRecursion: true,
          ),
        ];
        expect(semanticIds(match(delayed, probe: '你父亲怎么了')), isEmpty);

        final undelayed = <WorldInfoEntry>[
          entry(id: 'father', keys: <String>['米雪儿的父亲'], content: '父亲的记载'),
        ];
        expect(
          semanticIds(match(undelayed, probe: '你父亲怎么了')),
          <String>{'father'},
          reason: 'only the delay flag may suppress it',
        );
      });

      test('an explicit delay level is also excluded from recall', () {
        final entries = <WorldInfoEntry>[
          entry(
            id: 'father',
            keys: <String>['米雪儿的父亲'],
            content: '父亲的记载',
            delayUntilRecursion: true,
            delayUntilRecursionLevel: 2,
          ),
        ];
        expect(semanticIds(match(entries, probe: '你父亲怎么了')), isEmpty);
      });

      test('a stray level without the gate does not block recall', () {
        // The boolean is authoritative here too, so an entry that was never
        // delayed keeps its normal reach.
        final entries = <WorldInfoEntry>[
          entry(
            id: 'father',
            keys: <String>['米雪儿的父亲'],
            content: '父亲的记载',
            delayUntilRecursionLevel: 2,
          ),
        ];
        expect(semanticIds(match(entries, probe: '你父亲怎么了')), <String>{
          'father',
        });
      });

      test('excludeRecursion does not restrict recall', () {
        // It blocks activation by other *entries*; recall is not one of them.
        final entries = <WorldInfoEntry>[
          entry(
            id: 'father',
            keys: <String>['米雪儿的父亲'],
            content: '父亲的记载',
            excludeRecursion: true,
          ),
        ];
        expect(semanticIds(match(entries, probe: '你父亲怎么了')), <String>{
          'father',
        });
      });

      test('preventRecursion does not restrict recall', () {
        // It governs what the entry emits; recall never reads that.
        final entries = <WorldInfoEntry>[
          entry(
            id: 'father',
            keys: <String>['米雪儿的父亲'],
            content: '父亲的记载',
            preventRecursion: true,
          ),
        ];
        expect(semanticIds(match(entries, probe: '你父亲怎么了')), <String>{
          'father',
        });
      });
    });
  });

  group('RecallTokenizer seam', () {
    test('the default is the bigram tokenizer', () {
      expect(
        const BigramRecallTokenizer().tokenize('父亲怎么'),
        tokenizeForRecall('父亲怎么'),
      );
      // Both types stay const-constructible, so existing `const` call sites and
      // the characterization goldens are unaffected.
      const Bm25Ranker();
      const WorldInfoMatcher();
    });

    test('omitting a tokenizer scores exactly as before', () {
      const documents = <RecallDocument>[
        RecallDocument(id: 'a', text: '父亲昏迷了', keys: <String>['米雪儿的父亲']),
        RecallDocument(id: 'b', text: '无关内容', keys: <String>['别的']),
      ];
      final withDefault = const Bm25Ranker().rank(
        query: '父亲怎么了',
        documents: documents,
        requireKeyOverlap: true,
      );
      final explicit = const Bm25Ranker(
        tokenizer: BigramRecallTokenizer(),
      ).rank(query: '父亲怎么了', documents: documents, requireKeyOverlap: true);

      expect(
        withDefault.map((h) => h.documentId),
        explicit.map((h) => h.documentId),
      );
      expect(withDefault.map((h) => h.score), explicit.map((h) => h.score));
    });

    test('an injected tokenizer really drives scoring', () {
      // Whole-run tokens instead of bigrams: 「父亲」 no longer shares a token
      // with 「米雪儿的父亲」, so the default's substring-friendly hit disappears.
      // If the seam were decorative this would still match.
      const documents = <RecallDocument>[
        RecallDocument(id: 'a', text: '父亲昏迷了', keys: <String>['米雪儿的父亲']),
      ];
      const query = '父亲怎么了';

      expect(
        const Bm25Ranker()
            .rank(query: query, documents: documents, requireKeyOverlap: true)
            .map((h) => h.documentId),
        <String>['a'],
      );
      expect(
        const Bm25Ranker(
          tokenizer: _WholeRunTokenizer(),
        ).rank(query: query, documents: documents, requireKeyOverlap: true),
        isEmpty,
      );
    });

    test('a tokenizer that yields nothing produces no candidates', () {
      expect(
        const Bm25Ranker(tokenizer: _EmptyTokenizer()).rank(
          query: '父亲怎么了',
          documents: const <RecallDocument>[
            RecallDocument(id: 'a', text: '父亲', keys: <String>['父亲']),
          ],
        ),
        isEmpty,
      );
    });

    test('the matcher honors the injected tokenizer', () {
      final entries = <WorldInfoEntry>[
        entry(id: 'father', keys: <String>['米雪儿的父亲'], content: '父亲在崩溃症治疗中昏迷'),
      ];

      // Baseline: recall reaches the entry through the shared 父亲 bigram.
      expect(semanticIds(match(entries, probe: '你父亲怎么了')), <String>{'father'});
      // Same probe, different segmentation, no shared token.
      expect(
        semanticIds(
          match(
            entries,
            probe: '你父亲怎么了',
            tokenizer: const _WholeRunTokenizer(),
          ),
        ),
        isEmpty,
      );
    });

    test('repeated calls on one tokenizer are stable', () {
      const tokenizer = _WholeRunTokenizer();
      final first = tokenizer.tokenize('父亲怎么了 Hello');
      final second = tokenizer.tokenize('父亲怎么了 Hello');
      expect(first, second);
    });
  });
}

/// Splits on whitespace only, so a CJK run stays one token.
///
/// Deliberately coarser than the default: it makes an injected tokenizer's effect
/// observable rather than merely plausible.
class _WholeRunTokenizer implements RecallTokenizer {
  const _WholeRunTokenizer();

  @override
  List<String> tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[\s\p{P}]+', unicode: true))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

/// Yields no tokens at all, to pin the empty-corpus path.
class _EmptyTokenizer implements RecallTokenizer {
  const _EmptyTokenizer();

  @override
  List<String> tokenize(String text) => const <String>[];
}
