// Pure-only subset of the on-device character message assembler. This class
// covers only the *pure* half of the pipeline —
// `buildFromExecutionPlan` and its private helpers — with no File I/O, no
// resolver, no Riverpod, no implicit DateTime.now / Random / locale sources.
//
// Byte-identity contract (enforced by the SUT=package run of behavior_v1
// goldens and the characterization tests):
//   • Class name (`CharacterMessageAssembler` in the source) is renamed to
//     `CharacterMessageAssemblerPure` on the package side to signal the pure
//     subset. All *method / helper / field* names inside the class match the
//     source verbatim (`buildFromExecutionPlan`, `_buildShellCandidateEntries`,
//     `_resolveVariableMacros`, `_applyRegexProfile`,
//     `_buildExecutionUnitMessages`, `_buildCandidateEntriesFromUnit`,
//     `_buildTransportMessage`, `_roleFromWireValue`, `_mapBudgetPriority`).
//   • Sort-order constants (2000/3000/4000/7000/9999), id suffixes
//     (`@overflow_history_start`, `@tail_splice`, `@outlet`, `@post_history`,
//     `history:...`, `submitted_message`), regex patterns for variable
//     macros, placement-enum mapping, priority mapping, and role mapping are
//     preserved bit-for-bit.
//
// Deliberate deltas from the source:
//   • Import paths rewritten to package-relative siblings.
//   • Ctor: no fields (`const CharacterMessageAssemblerPure()`). Dependencies
//     that the source wired via Riverpod (`RegexService`, `MessageBudgetPlanner`,
//     `MacroService`) are accepted as method-level optional args on
//     `buildFromExecutionPlan`. Defaults preserve the source behavior:
//       - `regexService`   → new `RegexService()` (default Ports → NoopLogger)
//       - `budgetPlanner`  → `const MessageBudgetPlanner()`
//       - `macroService`   → built from `MacroContext.fromData(..., clock:)`
//         with the package's default Ports. Callers who need deterministic
//         macros (goldens, characterization) MUST pass a pre-built
//         `MacroService` seeded with `FrozenClock` / `SeededRandomSource` /
//         `LocaleTag`. This matches the plan spec's Ports design.
//   • Return type changed from `Future<CharacterTurnAssemblyResult>` to
//     synchronous `CharacterTurnAssemblyResult`. Justification: the only
//     source of async in the source was `_buildPendingUserTransportMessage`
//     (File.readAsBytes for attachments). The pure subset explicitly drops
//     attachment handling per plan spec ("不搬 File 附件读盘"), so no async
//     surface remains.
//   • Regex service is passed as a method arg instead of a singleton (source
//     uses `RegexService.instance`; the package version dropped the
//     singleton). Behavior is unchanged when caller supplies a default
//     `RegexService()`.
//
// Deliberately NOT copied (documented for the host-side consumer):
//   • `buildTurnMessages` (source line 37) — uses `DateTime.now()`,
//     `resolver.getCharacter`, File I/O via
//     `_buildPendingUserTransportMessage`. Belongs to the Host.
//   • `_resolvePromptContext` (source line 353) — needs the resolver.
//     Belongs to the Host.
//   • `_buildPendingUserTransportMessage` (source line 490) — reads File
//     attachments from disk via `File(attachment.path).readAsBytes()`. Belongs
//     to the Host; the pure text-only variant is inlined below as
//     `_buildPendingUserTextMessage` (StateError on non-empty attachments).

import '../models/character_assembly_models.dart';
import '../models/character_entities.dart';
import '../models/conversation_turns_models.dart';
import '../models/message_budget_candidates.dart';
import '../models/message_budget_models.dart';
import '../models/prompt_execution_models.dart';
import '../models/regex_profile.dart';
import '../models/regex_script.dart';
import '../budget/message_budget_planner.dart';
import '../macros/macro_service.dart';
import '../regex/regex_service.dart';

class CharacterMessageAssemblerPure {
  const CharacterMessageAssemblerPure();

  CharacterTurnAssemblyResult buildFromExecutionPlan({
    required CharacterAssemblyRequest request,
    required Character character,
    required ResolvedPromptContext resolvedContext,
    required PromptExecutionPlan executionPlan,
    required List<CharacterHistoryMessage> assembledHistory,
    MacroService? macroService,
    RegexService? regexService,
    MessageBudgetPlanner? budgetPlanner,
  }) {
    final effectiveHistory = assembledHistory;
    final persona = resolvedContext.persona;
    final effectiveBudgetPlanner =
        budgetPlanner ?? const MessageBudgetPlanner();
    final effectiveRegexService = regexService ?? RegexService();

    final effectiveMacroService = macroService ??
        MacroService(
          MacroContext.fromData(
            character: character,
            persona: persona,
            chatId: request.topicId.isNotEmpty
                ? request.topicId
                : request.sessionId,
            messages: effectiveHistory,
            currentInput: request.pendingUserInput.text,
            resolvedVariables: resolvedContext.resolvedVariables,
          ),
        );
    String processContent(
      String text, {
      RegexPlacement? placement,
      int? depth,
      bool isPrompt = true,
    }) {
      final macroProcessed = effectiveMacroService.process(text);
      final variableProcessed = _resolveVariableMacros(
        macroProcessed,
        resolvedContext.resolvedVariables,
      );
      return _applyRegexProfile(
        variableProcessed,
        resolvedContext.regexProfile,
        placement: placement,
        depth: depth,
        isPrompt: isPrompt,
        characterName: character.name,
        userName: persona?.name,
        regexService: effectiveRegexService,
      );
    }

    final assembled = <TurnMessage>[];
    final submittedMessage = _buildPendingUserTextMessage(
      request.pendingUserInput,
      regexProfile: resolvedContext.regexProfile,
      characterName: character.name,
      userName: persona?.name,
      regexService: effectiveRegexService,
    );
    final shellEntries = _buildShellCandidateEntries(
      executionPlan,
      processContent,
    );
    final preHistoryEntries = shellEntries.preHistoryEntries;
    final postHistoryEntries = shellEntries.postHistoryEntries;
    final spliceMap = <int, List<ResolvedExecutionUnit>>{
      for (final point in executionPlan.historySplicePoints)
        point.offsetFromEnd: point.units,
    };
    final historyStartEntries = executionPlan.historySplicePoints
        .where((point) => point.offsetFromEnd >= effectiveHistory.length)
        .expand(
          (point) => point.units.expand(
            (unit) => _buildCandidateEntriesFromUnit(
              unit,
              processContent,
              bucket: CandidatePlacementBucket.historyStart,
              depthFromEnd: unit.depth,
              sortOrder:
                  2000 + point.offsetFromEnd * 10 + point.units.indexOf(unit),
              idSuffix: '@overflow_history_start',
            ),
          ),
        )
        .toList(growable: false);
    final tailSpliceEntries = (spliceMap[0] ?? const <ResolvedExecutionUnit>[])
        .expand(
          (unit) => _buildCandidateEntriesFromUnit(
            unit,
            processContent,
            bucket: CandidatePlacementBucket.tailSplice,
            depthFromEnd: 0,
            sortOrder:
                7000 +
                (spliceMap[0] ?? const <ResolvedExecutionUnit>[]).indexOf(unit),
            idSuffix: '@tail_splice',
          ),
        )
        .toList(growable: false);
    final historyBundles = <BudgetHistoryBundle>[];
    for (var i = 0; i < effectiveHistory.length - 1; i++) {
      final message = effectiveHistory[i];
      final depthFromEnd = effectiveHistory.length - 1 - i;
      if (depthFromEnd == 0) {
        continue;
      }
      final spliceEntries =
          (spliceMap[depthFromEnd] ?? const <ResolvedExecutionUnit>[])
              .expand(
                (unit) => _buildCandidateEntriesFromUnit(
                  unit,
                  processContent,
                  bucket: CandidatePlacementBucket.historyBundle,
                  depthFromEnd: depthFromEnd,
                  sortOrder:
                      3000 +
                      depthFromEnd * 10 +
                      (spliceMap[depthFromEnd] ??
                              const <ResolvedExecutionUnit>[])
                          .indexOf(unit),
                ),
              )
              .toList(growable: false);
      historyBundles.add(
        BudgetHistoryBundle(
          offsetFromEnd: depthFromEnd,
          historyEntry: BudgetCandidateEntry(
            unitId: 'history:${message.messageId ?? i}',
            message: _buildTransportMessage(message),
            sortOrder: 4000 + i,
            bucket: CandidatePlacementBucket.historyBundle,
            priority: BudgetCandidatePriority.normal,
          ),
          spliceEntries: spliceEntries,
        ),
      );
    }
    final budgetedResult = effectiveBudgetPlanner.retainWithinBudget(
      budgetPlan: executionPlan.budgetPlan,
      preHistoryEntries: preHistoryEntries,
      historyStartEntries: historyStartEntries,
      historyBundles: historyBundles,
      tailSpliceEntries: tailSpliceEntries,
      postHistoryEntries: postHistoryEntries,
      submittedMessage: BudgetCandidateEntry(
        unitId: 'submitted_message',
        message: submittedMessage,
        sortOrder: 9999,
        bucket: CandidatePlacementBucket.postHistory,
        priority: BudgetCandidatePriority.mandatory,
        mandatory: true,
      ),
    );
    assembled.addAll(budgetedResult.messages);

    return CharacterTurnAssemblyResult(
      messages: assembled,
      submittedMessage: submittedMessage,
      croppingTrace: <CroppingTrace>[
        ...executionPlan.croppingTrace,
        ...budgetedResult.trace,
      ],
      executionTrace: <ExecutionTraceEntry>[
        ...executionPlan.trace,
        ...executionPlan.croppingTrace.map(
          (trace) => ExecutionTraceEntry(
            unitId: trace.unitId,
            stage: ExecutionTraceStage.budget,
            reason: trace.reason,
            retentionDecision: trace.decision,
          ),
        ),
        ...budgetedResult.trace.map(
          (trace) => ExecutionTraceEntry(
            unitId: trace.unitId,
            stage: ExecutionTraceStage.budget,
            reason: trace.reason,
            retentionDecision: trace.decision,
          ),
        ),
      ],
    );
  }

  ({
    List<BudgetCandidateEntry> preHistoryEntries,
    List<BudgetCandidateEntry> postHistoryEntries,
  })
  _buildShellCandidateEntries(
    PromptExecutionPlan executionPlan,
    String Function(
      String, {
      RegexPlacement? placement,
      int? depth,
      bool isPrompt,
    })
    processContent,
  ) {
    final preHistoryEntries = <BudgetCandidateEntry>[];
    final postHistoryEntries = <BudgetCandidateEntry>[];
    var afterHistory = false;
    var sortOrder = 0;

    void addUnit(
      ResolvedExecutionUnit unit, {
      required CandidatePlacementBucket bucket,
      String idSuffix = '',
    }) {
      final target = bucket == CandidatePlacementBucket.postHistory
          ? postHistoryEntries
          : preHistoryEntries;
      final generatedEntries = _buildCandidateEntriesFromUnit(
        unit,
        processContent,
        bucket: bucket,
        depthFromEnd: unit.depth,
        sortOrder: sortOrder++,
        idSuffix: idSuffix,
      );
      target.addAll(generatedEntries);
    }

    for (final unit in executionPlan.shellSequence) {
      if (unit.sourceKind == ExecutionSourceKind.marker) {
        final markerId = (unit.markerId ?? '').trim();
        if (markerId == 'history') {
          afterHistory = true;
        }
        final outletUnits =
            executionPlan.outletMap[markerId] ??
            const <ResolvedExecutionUnit>[];
        for (final outletUnit in outletUnits) {
          addUnit(
            outletUnit,
            bucket: afterHistory
                ? CandidatePlacementBucket.postHistory
                : CandidatePlacementBucket.preHistory,
            idSuffix: '@outlet',
          );
        }
        continue;
      }

      final bucket =
          afterHistory ||
              unit.insertionMode == ExecutionInsertionMode.afterHistory
          ? CandidatePlacementBucket.postHistory
          : CandidatePlacementBucket.preHistory;
      addUnit(
        unit,
        bucket: bucket,
        idSuffix: bucket == CandidatePlacementBucket.postHistory
            ? '@post_history'
            : '',
      );
    }

    return (
      preHistoryEntries: List<BudgetCandidateEntry>.unmodifiable(
        preHistoryEntries,
      ),
      postHistoryEntries: List<BudgetCandidateEntry>.unmodifiable(
        postHistoryEntries,
      ),
    );
  }

  String _resolveVariableMacros(
    String text,
    Map<String, dynamic> resolvedVariables,
  ) {
    String stringify(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      return value.toString();
    }

    var result = text;
    result = result.replaceAllMapped(
      RegExp(r'\{\{getvar::([^}]+)\}\}', caseSensitive: false),
      (match) => stringify(resolvedVariables[match.group(1)!.trim()]),
    );
    result = result.replaceAllMapped(
      RegExp(r'\{\{getglobalvar::([^}]+)\}\}', caseSensitive: false),
      (match) => stringify(resolvedVariables[match.group(1)!.trim()]),
    );
    return result;
  }

  String _applyRegexProfile(
    String text,
    RegexProfileBundle? regexProfile, {
    required RegexPlacement? placement,
    required String? characterName,
    required String? userName,
    required bool isPrompt,
    required RegexService regexService,
    int? depth,
  }) {
    if (text.isEmpty || placement == null || regexProfile == null) {
      return text;
    }
    final settings = regexProfile.profile.settings;
    if (!settings.enabled) return text;

    final enabledForPlacement = switch (placement) {
      RegexPlacement.userInput => settings.applyToUserInput,
      RegexPlacement.aiOutput => settings.applyToAiOutput,
      RegexPlacement.slashCommand => settings.applyToSlashCommands,
      RegexPlacement.worldInfo => settings.applyToWorldInfo,
      RegexPlacement.reasoning => settings.applyToReasoning,
    };
    if (!enabledForPlacement) return text;

    return regexService.getRegexedString(
      text,
      placement,
      regexProfile.scripts,
      characterName: characterName,
      userName: userName,
      isPrompt: isPrompt,
      depth: depth,
    );
  }

  List<TurnMessage> _buildExecutionUnitMessages(
    ResolvedExecutionUnit unit,
    String Function(
      String, {
      RegexPlacement? placement,
      int? depth,
      bool isPrompt,
    })
    processContent, {
    int? depthFromEnd,
  }) {
    final template = unit.contentTemplate.trim();
    if (template.isEmpty) {
      return const <TurnMessage>[];
    }
    final placement = unit.sourceKind == ExecutionSourceKind.worldInfoEntry
        ? RegexPlacement.worldInfo
        : null;
    return <TurnMessage>[
      TurnMessage(
        role: _roleFromWireValue(unit.role),
        content: processContent(
          template,
          placement: placement,
          depth: depthFromEnd ?? unit.depth,
        ),
      ),
    ];
  }

  List<BudgetCandidateEntry> _buildCandidateEntriesFromUnit(
    ResolvedExecutionUnit unit,
    String Function(
      String, {
      RegexPlacement? placement,
      int? depth,
      bool isPrompt,
    })
    processContent, {
    required CandidatePlacementBucket bucket,
    required int sortOrder,
    int? depthFromEnd,
    String idSuffix = '',
  }) {
    return _buildExecutionUnitMessages(
          unit,
          processContent,
          depthFromEnd: depthFromEnd,
        )
        .map(
          (message) => BudgetCandidateEntry(
            unitId: '${unit.id}$idSuffix',
            message: message,
            sortOrder: sortOrder,
            bucket: bucket,
            priority: _mapBudgetPriority(unit.budgetTier),
            debugSourceKind: unit.sourceKind.name,
            mandatory: unit.mandatory,
            dropWithMissingAnchor: unit.dropWithMissingAnchor,
          ),
        )
        .toList(growable: false);
  }

  TurnMessage _buildTransportMessage(CharacterHistoryMessage message) {
    return TurnMessage(role: message.role, content: message.content);
  }

  /// Pure text-only variant of the source's
  /// `_buildPendingUserTransportMessage`. The source reads File attachments
  /// from disk via `File(...).readAsBytes()`; the pure package explicitly
  /// drops that path (see file header). Callers that need attachment support
  /// belong on the host side (host-side re-wiring) and must build the
  /// transport message themselves before invoking the pure assembler in a
  /// custom code path — the goldens exercised by this class never include
  /// attachments.
  TurnMessage _buildPendingUserTextMessage(
    CharacterPendingUserInput input, {
    required RegexProfileBundle? regexProfile,
    required String? characterName,
    required String? userName,
    required RegexService regexService,
  }) {
    if (input.attachments.isNotEmpty) {
      throw StateError(
        'character.pure_assembler.attachments_not_supported:'
        '${input.attachments.length}_attachment(s). Attachments require File '
        "I/O and are handled by the Host; call the Host's assembler.",
      );
    }
    final transformedText = _applyRegexProfile(
      input.text,
      regexProfile,
      placement: RegexPlacement.userInput,
      characterName: characterName,
      userName: userName,
      isPrompt: true,
      regexService: regexService,
    );
    return TurnMessage(role: TurnMessageRole.user, content: transformedText);
  }

  TurnMessageRole _roleFromWireValue(String role) {
    switch (role.trim().toLowerCase()) {
      case 'system':
        return TurnMessageRole.system;
      case 'assistant':
        return TurnMessageRole.assistant;
      case 'user':
      default:
        return TurnMessageRole.user;
    }
  }

  BudgetCandidatePriority _mapBudgetPriority(ExecutionBudgetTier tier) {
    return switch (tier) {
      ExecutionBudgetTier.mandatory => BudgetCandidatePriority.mandatory,
      ExecutionBudgetTier.high => BudgetCandidatePriority.high,
      ExecutionBudgetTier.normal => BudgetCandidatePriority.normal,
      ExecutionBudgetTier.low => BudgetCandidatePriority.low,
    };
  }
}
