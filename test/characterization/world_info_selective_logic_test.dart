// Tests for world-info multi-key activation logic (`selectiveLogic`) and the
// budget-tier resolution added alongside it.
//
// Before this, `_matchesEntry` hard-coded AND_ANY semantics: any secondary key
// match confirmed the entry and there was no way to express exclusion. The
// matcher also applied `matchWholeWords` to primary keys only, so secondary keys
// silently fell back to substring matching.
import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

WorldInfoEntry _entry({
  String id = 'e1',
  String? uid,
  List<String> keys = const <String>['alpha'],
  List<String> secondaryKeys = const <String>[],
  bool selective = true,
  bool caseSensitive = false,
  bool matchWholeWords = false,
  bool constant = false,
  int insertionOrder = 0,
  bool ignoreBudget = false,
  WorldInfoRuntimePolicy? runtimePolicy,
}) {
  return WorldInfoEntry(
    id: uid ?? id,
    worldbookId: 'wb_1',
    keys: keys,
    secondaryKeys: secondaryKeys,
    content: 'content',
    comment: '',
    enabled: true,
    constant: constant,
    selective: selective,
    insertionOrder: insertionOrder,
    caseSensitive: caseSensitive,
    matchWholeWords: matchWholeWords,
    useGroupScoring: false,
    probability: 100,
    useProbability: false,
    position: WorldInfoPosition.before,
    depth: 0,
    group: null,
    groupWeight: 100,
    preventRecursion: false,
    delayUntilRecursion: false,
    scanDepth: 0,
    role: 0,
    sticky: 0,
    cooldown: 0,
    delay: 0,
    characterFilter: const <String, dynamic>{},
    ignoreBudget: ignoreBudget,
    runtimePolicy: runtimePolicy,
  );
}

void main() {
  group('planner budget tier projection', () {
    Character character() => Character(
      id: 'char_1',
      ownerUserId: 'owner',
      name: 'Tester',
      nickname: '',
      description: '',
      personality: '',
      scenario: '',
      firstMessage: '',
      alternateGreetings: const <String>[],
      exampleMessages: '',
      systemPrompt: '',
      postHistoryInstructions: '',
      tags: const <String>[],
      isSystem: false,
      visibilityScope: 'private',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

    ResolvedExecutionUnit project({String? tier, bool ignoreBudget = false}) {
      final entry = _entry(
        ignoreBudget: ignoreBudget,
        runtimePolicy: WorldInfoRuntimePolicy.fromEntryExtensions(
          <String, dynamic>{
            if (tier != null) 'budgetPolicy': <String, dynamic>{'tier': tier},
            if (ignoreBudget) 'ignoreBudget': true,
          },
        ),
      );
      final char = character();
      final request = CharacterAssemblyRequest(
        sessionId: 'session',
        topicId: 'topic',
        characterId: char.id,
        history: const <CharacterHistoryMessage>[],
        pendingUserInput: const CharacterPendingUserInput(text: 'alpha'),
      );
      final context = ResolvedPromptContext(
        character: char,
        worldInfoEntries: <WorldInfoEntry>[entry],
        groupedWorldInfoEntries: <WorldInfoPosition, List<WorldInfoEntry>>{
          WorldInfoPosition.before: <WorldInfoEntry>[entry],
        },
        resolvedPromptBlocks: const <PromptBlock>[],
        promptContext: const SessionPromptContext(),
        resolvedVariables: const <String, dynamic>{},
      );
      final plan = const PromptExecutionPlanner().buildPlan(
        request: request,
        resolvedContext: context,
      );
      return <ResolvedExecutionUnit>[
        ...plan.shellSequence,
        ...plan.historySplicePoints.expand((point) => point.units),
        ...plan.outletMap.values.expand((units) => units),
      ].singleWhere(
        (unit) => unit.sourceKind == ExecutionSourceKind.worldInfoEntry,
      );
    }

    test('projects all explicit tiers', () {
      expect(project(tier: 'low').budgetTier, ExecutionBudgetTier.low);
      expect(project(tier: 'normal').budgetTier, ExecutionBudgetTier.normal);
      expect(project(tier: 'high').budgetTier, ExecutionBudgetTier.high);
      expect(
        project(tier: 'mandatory').budgetTier,
        ExecutionBudgetTier.mandatory,
      );
    });

    test('missing and unknown tiers fall back to ignoreBudget', () {
      expect(project().budgetTier, ExecutionBudgetTier.normal);
      expect(project(ignoreBudget: true).budgetTier, ExecutionBudgetTier.high);
      expect(project(tier: 'unknown').budgetTier, ExecutionBudgetTier.normal);
      expect(
        project(tier: 'unknown', ignoreBudget: true).budgetTier,
        ExecutionBudgetTier.high,
      );
    });

    test('explicit low tier coexists independently with ignoreBudget', () {
      final unit = project(tier: 'low', ignoreBudget: true);
      expect(unit.budgetTier, ExecutionBudgetTier.low);
      expect(unit.ignoreBudget, isTrue);
    });
  });
}
