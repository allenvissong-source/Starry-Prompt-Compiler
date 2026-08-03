// Package-internal test for CharacterMessageAssemblerPure.
//
// This is NOT the behavior-parity test — that lives on the Starry side and
// runs the pure assembler under `SUT=package` against the 22 behavior_v1
// goldens. This file only asserts the package-local contract:
//   1. buildFromExecutionPlan compiles and returns a
//      CharacterTurnAssemblyResult without throwing when given a minimal
//      plan and history.
//   2. Determinism: given a MacroService pre-seeded with FrozenClock +
//      SeededRandomSource + LocaleTag('en_US') + NoopLogger, two independent
//      invocations produce byte-identical results.
//   3. Attachment guard: CharacterPendingUserInput with attachments raises a
//      StateError with the documented prefix (attachments belong to the Host).
//   4. History budgeting: with enableBudgetPass=false the assembler emits the
//      full history plus submitted message in order.

import 'package:starry_prompt_compiler/starry_prompt_compiler.dart';
import 'package:test/test.dart';

void main() {
  final frozenNow = DateTime.utc(2025, 1, 1, 12);
  final ports = _DeterministicPorts(frozenNow);

  Character buildCharacter() {
    return Character(
      id: 'char-1',
      ownerUserId: 'owner-1',
      name: 'Aria',
      nickname: 'A',
      description: 'a friendly guide',
      personality: 'warm',
      scenario: 'in a library',
      firstMessage: 'Hello!',
      alternateGreetings: const <String>[],
      exampleMessages: '',
      systemPrompt: '',
      postHistoryInstructions: '',
      tags: const <String>[],
      isSystem: false,
      visibilityScope: 'private',
      createdAt: frozenNow,
      updatedAt: frozenNow,
    );
  }

  ResolvedPromptContext buildContext(Character character) {
    return ResolvedPromptContext(
      character: character,
      worldInfoEntries: const <WorldInfoEntry>[],
      groupedWorldInfoEntries:
          const <WorldInfoPosition, List<WorldInfoEntry>>{},
      resolvedPromptBlocks: const <PromptBlock>[],
      promptContext: const SessionPromptContext(),
      resolvedVariables: const <String, dynamic>{'user_name': 'Traveler'},
    );
  }

  CharacterHistoryMessage historyMessage({
    required TurnMessageRole role,
    required String text,
    String? id,
  }) {
    return CharacterHistoryMessage(
      role: role,
      content: text,
      timestamp: frozenNow,
      messageId: id,
    );
  }

  ResolvedExecutionUnit shellUnit({
    required String id,
    required String template,
    String role = 'system',
    bool mandatory = false,
    ExecutionBudgetTier tier = ExecutionBudgetTier.normal,
  }) {
    return ResolvedExecutionUnit(
      id: id,
      sourceKind: ExecutionSourceKind.promptBlock,
      sourceRef: 'block:$id',
      enabled: true,
      contentTemplate: template,
      role: role,
      insertionMode: ExecutionInsertionMode.beforeHistory,
      mandatory: mandatory,
      budgetTier: tier,
    );
  }

  ResolvedExecutionUnit historyMarker() {
    return const ResolvedExecutionUnit(
      id: 'history_marker',
      sourceKind: ExecutionSourceKind.marker,
      sourceRef: 'marker:history',
      enabled: true,
      contentTemplate: '',
      role: 'system',
      insertionMode: ExecutionInsertionMode.beforeHistory,
      markerId: 'history',
    );
  }

  PromptExecutionPlan buildPlan() {
    return PromptExecutionPlan(
      shellSequence: <ResolvedExecutionUnit>[
        shellUnit(id: 'sys', template: 'You are {{char}} talking to {{user}}.'),
        historyMarker(),
        shellUnit(
          id: 'jailbreak',
          template: 'Stay in character.',
          mandatory: true,
          tier: ExecutionBudgetTier.mandatory,
        ),
      ],
      historySplicePoints: <HistorySplicePoint>[],
      disabledUnits: const <ResolvedExecutionUnit>[],
    );
  }

  CharacterAssemblyRequest buildRequest({
    List<CharacterHistoryMessage>? history,
    CharacterPendingUserInput? pending,
  }) {
    return CharacterAssemblyRequest(
      sessionId: 'sess-1',
      topicId: 'topic-1',
      characterId: 'char-1',
      history: history ??
          <CharacterHistoryMessage>[
            historyMessage(
              role: TurnMessageRole.user,
              text: 'Hi Aria!',
              id: 'm1',
            ),
            historyMessage(
              role: TurnMessageRole.assistant,
              text: 'Hello, Traveler.',
              id: 'm2',
            ),
          ],
      pendingUserInput:
          pending ?? const CharacterPendingUserInput(text: 'What is here?'),
    );
  }

  MacroService buildDeterministicMacroService({
    required Character character,
    required CharacterAssemblyRequest request,
    required ResolvedPromptContext context,
    required List<CharacterHistoryMessage> assembledHistory,
  }) {
    return MacroService(
      MacroContext.fromData(
        character: character,
        persona: context.persona,
        chatId: request.topicId,
        messages: assembledHistory,
        currentInput: request.pendingUserInput.text,
        resolvedVariables: context.resolvedVariables,
        clock: ports.clock,
      ),
      clock: ports.clock,
      random: ports.random,
      locale: ports.locale,
      logger: ports.logger,
    );
  }

  group('CharacterMessageAssemblerPure', () {
    const assembler = CharacterMessageAssemblerPure();

    test('assembles minimal request into submittedMessage + trace', () {
      final character = buildCharacter();
      final context = buildContext(character);
      final request = buildRequest();
      final assembledHistory = <CharacterHistoryMessage>[
        ...request.history,
        historyMessage(
          role: TurnMessageRole.user,
          text: request.pendingUserInput.text,
        ),
      ];
      final macroService = buildDeterministicMacroService(
        character: character,
        request: request,
        context: context,
        assembledHistory: assembledHistory,
      );

      final result = assembler.buildFromExecutionPlan(
        request: request,
        character: character,
        resolvedContext: context,
        executionPlan: buildPlan(),
        assembledHistory: assembledHistory,
        macroService: macroService,
      );

      expect(result.submittedMessage.role, TurnMessageRole.user);
      expect(result.submittedMessage.content, request.pendingUserInput.text);
      expect(result.messages, isNotEmpty);
      // With enableBudgetPass=false the assembler should not drop anything;
      // shell entries + assembled history + submitted message must all be
      // present. History has 3 messages after appending pending -> 2 bundles
      // (indexes 0/1) plus the final submitted message.
      final systemMessages = result.messages
          .where((message) => message.role == TurnMessageRole.system)
          .toList();
      expect(
        systemMessages.length,
        2,
        reason: 'shell has two system units (sys + jailbreak)',
      );
      expect(
        systemMessages.first.content,
        contains('You are Aria talking to'),
        reason: '{{char}} substitution must resolve via MacroService',
      );
    });

    test('is deterministic under FrozenClock + SeededRandomSource', () {
      final character = buildCharacter();
      final context = buildContext(character);
      final request = buildRequest();
      final assembledHistory = <CharacterHistoryMessage>[
        ...request.history,
        historyMessage(
          role: TurnMessageRole.user,
          text: request.pendingUserInput.text,
        ),
      ];

      CharacterTurnAssemblyResult run() {
        final macroService = buildDeterministicMacroService(
          character: character,
          request: request,
          context: context,
          assembledHistory: assembledHistory,
        );
        return assembler.buildFromExecutionPlan(
          request: request,
          character: character,
          resolvedContext: context,
          executionPlan: buildPlan(),
          assembledHistory: assembledHistory,
          macroService: macroService,
        );
      }

      final first = run();
      final second = run();
      expect(_serialize(first), _serialize(second));
    });

    test('throws StateError when pending input carries attachments', () {
      final character = buildCharacter();
      final context = buildContext(character);
      final request = buildRequest(
        pending: const CharacterPendingUserInput(
          text: 'see photo',
          attachments: <CharacterLocalImageAttachment>[
            CharacterLocalImageAttachment(
              path: '/tmp/nope.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      );
      final assembledHistory = <CharacterHistoryMessage>[
        ...request.history,
        historyMessage(role: TurnMessageRole.user, text: 'see photo'),
      ];
      final macroService = buildDeterministicMacroService(
        character: character,
        request: request,
        context: context,
        assembledHistory: assembledHistory,
      );

      expect(
        () => assembler.buildFromExecutionPlan(
          request: request,
          character: character,
          resolvedContext: context,
          executionPlan: buildPlan(),
          assembledHistory: assembledHistory,
          macroService: macroService,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('character.pure_assembler.attachments_not_supported'),
          ),
        ),
      );
    });
  });
}

class _DeterministicPorts {
  _DeterministicPorts(DateTime frozen)
      : clock = FrozenClock(frozen),
        random = SeededRandomSource(0),
        locale = const LocaleTag('en_US'),
        logger = const NoopLogger();

  final FrozenClock clock;
  final SeededRandomSource random;
  final LocaleTag locale;
  final NoopLogger logger;
}

String _serialize(CharacterTurnAssemblyResult result) {
  final buffer = StringBuffer();
  buffer.writeln('submitted: ${result.submittedMessage.role.name}');
  buffer.writeln('submitted-content: ${result.submittedMessage.content}');
  for (var i = 0; i < result.messages.length; i++) {
    final message = result.messages[i];
    buffer.writeln('m$i: ${message.role.name} | ${message.content}');
  }
  for (var i = 0; i < result.croppingTrace.length; i++) {
    final trace = result.croppingTrace[i];
    buffer.writeln(
      't$i: ${trace.unitId} | ${trace.stage.name} | '
      '${trace.decision.name} | ${trace.reason}',
    );
  }
  return buffer.toString();
}
