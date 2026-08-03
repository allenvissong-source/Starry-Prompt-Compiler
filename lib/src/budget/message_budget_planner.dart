// Byte-identity contract:
//   • All class / method / field names, sort-order rules, trace reason
//     strings, and priority precedence numbers match the source of truth.
//     Behavioral parity is enforced by the SUT=package run of the
//     behavior_v1 goldens and by the characterization tests targeting this
//     planner.
//
// Deliberate deltas from the source:
//   • Import paths rewritten to sibling models in the package:
//       starry:.../conversation_turns_models       -> ../models/conversation_turns_models
//       starry:.../message_budget_candidates       -> ../models/message_budget_candidates
//       starry:.../message_budget_models           -> ../models/message_budget_models
//
// Deliberately NOT changed:
//   • No Ports are injected — the planner is already pure: no DateTime.now,
//     no Random, no debugPrint, no locale-sensitive formatting, no File I/O,
//     no Flutter / Riverpod dependency in the source of truth. Verified by
//     grepping the source file for DateTime / Random / debugPrint / kDebugMode
//     / File / dart:io / package:flutter / flutter_riverpod — zero hits.

import '../models/conversation_turns_models.dart';
import '../models/message_budget_candidates.dart';
import '../models/message_budget_models.dart';

class MessageBudgetPlanner {
  const MessageBudgetPlanner();

  MessageBudgetResult retainWithinBudget({
    required MessageBudgetPlan budgetPlan,
    required List<BudgetCandidateEntry> preHistoryEntries,
    required List<BudgetCandidateEntry> historyStartEntries,
    required List<BudgetHistoryBundle> historyBundles,
    required List<BudgetCandidateEntry> tailSpliceEntries,
    required List<BudgetCandidateEntry> postHistoryEntries,
    required BudgetCandidateEntry submittedMessage,
  }) {
    final available = budgetPlan.resolvedAvailableInputTokens;
    var effectiveHistoryBundles = List<BudgetHistoryBundle>.from(
      historyBundles,
    );
    final trace = <CroppingTrace>[];
    final maxHistoryMessages = budgetPlan.maxHistoryMessages;
    if (maxHistoryMessages != null && maxHistoryMessages >= 0) {
      final keepCount = maxHistoryMessages.clamp(
        0,
        effectiveHistoryBundles.length,
      );
      if (keepCount < effectiveHistoryBundles.length) {
        final dropped = effectiveHistoryBundles.take(
          effectiveHistoryBundles.length - keepCount,
        );
        for (final bundle in dropped) {
          trace.add(
            CroppingTrace(
              unitId: bundle.historyEntry.unitId,
              stage: CroppingStage.finalRetainDrop,
              decision: RetainDecision.dropOverBudget,
              reason: 'l0_recent_raw_tail_cap',
            ),
          );
          for (final entry in bundle.spliceEntries) {
            trace.add(
              CroppingTrace(
                unitId: entry.unitId,
                stage: CroppingStage.finalRetainDrop,
                decision: RetainDecision.dropOverBudget,
                reason: 'l0_recent_raw_tail_cap_anchor_dropped',
              ),
            );
          }
        }
        effectiveHistoryBundles = effectiveHistoryBundles
            .skip(effectiveHistoryBundles.length - keepCount)
            .toList(growable: false);
      }
    }
    if (!budgetPlan.enableBudgetPass || available == null) {
      return MessageBudgetResult(
        messages: <TurnMessage>[
          ...preHistoryEntries.map((entry) => entry.message),
          ...historyStartEntries.map((entry) => entry.message),
          ...effectiveHistoryBundles.expand(
            (bundle) => <TurnMessage>[
              ...bundle.spliceEntries.map((entry) => entry.message),
              bundle.historyEntry.message,
            ],
          ),
          ...tailSpliceEntries.map((entry) => entry.message),
          ...postHistoryEntries.map((entry) => entry.message),
        ],
        trace: List<CroppingTrace>.unmodifiable(trace),
      );
    }
    final submittedTokens = _estimateMessageTokens(submittedMessage.message);
    var remaining = available - submittedTokens;
    if (remaining < 0) {
      final overflowTrace = <CroppingTrace>[
        CroppingTrace(
          unitId: submittedMessage.unitId,
          stage: CroppingStage.finalRetainDrop,
          decision: RetainDecision.dropMandatoryOverflow,
          reason: 'submitted_message_overflow',
        ),
      ];
      throw PromptBudgetOverflowException(
        code: 'character.prompt_budget_overflow:submitted_message',
        trace: overflowTrace,
      );
    }

    final mandatoryShellEntries = <BudgetCandidateEntry>[
      ...preHistoryEntries.where((entry) => entry.mandatory),
      ...historyStartEntries.where((entry) => entry.mandatory),
      ...tailSpliceEntries.where((entry) => entry.mandatory),
      ...postHistoryEntries.where((entry) => entry.mandatory),
    ];

    var mandatoryShellTokens = 0;
    for (final entry in mandatoryShellEntries) {
      final estimated = _estimateMessageTokens(entry.message);
      mandatoryShellTokens += estimated;
      trace.add(
        CroppingTrace(
          unitId: entry.unitId,
          stage: CroppingStage.finalRetainDrop,
          decision: RetainDecision.retain,
          reason: 'mandatory_shell',
        ),
      );
    }
    if (mandatoryShellTokens > remaining) {
      final overflowTrace = <CroppingTrace>[
        ...trace,
        ...mandatoryShellEntries.map(
          (entry) => CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.dropMandatoryOverflow,
            reason: 'mandatory_shell_overflow',
          ),
        ),
      ];
      throw PromptBudgetOverflowException(
        code: 'character.prompt_budget_overflow:mandatory_shell',
        trace: overflowTrace,
      );
    }
    remaining -= mandatoryShellTokens;

    final retainedHistoryBundles = <BudgetHistoryBundle>[];
    var suffixCutoffReached = false;
    for (final bundle in effectiveHistoryBundles.reversed) {
      if (suffixCutoffReached) {
        trace.add(
          CroppingTrace(
            unitId: bundle.historyEntry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.dropOverBudget,
            reason: 'drop_old_history_suffix',
          ),
        );
        for (final entry in bundle.spliceEntries) {
          trace.add(
            CroppingTrace(
              unitId: entry.unitId,
              stage: CroppingStage.finalRetainDrop,
              decision: RetainDecision.dropOverBudget,
              reason: 'anchor_history_bundle_dropped',
            ),
          );
        }
        continue;
      }
      final estimated = _estimateHistoryBundleTokens(bundle);
      if (estimated <= remaining) {
        retainedHistoryBundles.add(bundle);
        remaining -= estimated;
        trace.add(
          CroppingTrace(
            unitId: bundle.historyEntry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.retain,
            reason: 'history_suffix',
          ),
        );
        for (final entry in bundle.spliceEntries) {
          trace.add(
            CroppingTrace(
              unitId: entry.unitId,
              stage: CroppingStage.finalRetainDrop,
              decision: RetainDecision.retain,
              reason: 'retained_history_anchor',
            ),
          );
        }
        continue;
      }
      suffixCutoffReached = true;
      trace.add(
        CroppingTrace(
          unitId: bundle.historyEntry.unitId,
          stage: CroppingStage.finalRetainDrop,
          decision: RetainDecision.dropOverBudget,
          reason: 'drop_old_history_suffix',
        ),
      );
      for (final entry in bundle.spliceEntries) {
        trace.add(
          CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.dropOverBudget,
            reason: 'anchor_history_bundle_dropped',
          ),
        );
      }
    }
    final retainedBundles = retainedHistoryBundles.reversed.toList(
      growable: false,
    );
    final retainedOffsets = retainedBundles
        .map((bundle) => bundle.offsetFromEnd)
        .toSet();
    final fallbackEntries = _collectFallbackEntries(
      historyBundles: effectiveHistoryBundles,
      retainedOffsets: retainedOffsets,
      trace: trace,
    );
    final resolvedTailSplice = _resolveTailSpliceEntries(
      tailSpliceEntries: tailSpliceEntries,
      hasRetainedHistoryAnchor: retainedBundles.isNotEmpty,
      trace: trace,
    );
    final mandatoryResolvedTailEntries = <BudgetCandidateEntry>[
      ...resolvedTailSplice.historyStartEntries.where(
        (entry) => entry.mandatory,
      ),
      ...resolvedTailSplice.tailSpliceEntries.where((entry) => entry.mandatory),
    ];
    var mandatoryResolvedTailTokens = 0;
    for (final entry in mandatoryResolvedTailEntries) {
      final estimated = _estimateMessageTokens(entry.message);
      mandatoryResolvedTailTokens += estimated;
      trace.add(
        CroppingTrace(
          unitId: entry.unitId,
          stage: CroppingStage.finalRetainDrop,
          decision: RetainDecision.retain,
          reason: 'mandatory_tail_or_fallback',
        ),
      );
    }
    if (mandatoryResolvedTailTokens > remaining) {
      final overflowTrace = <CroppingTrace>[
        ...trace,
        ...mandatoryResolvedTailEntries.map(
          (entry) => CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.dropMandatoryOverflow,
            reason: 'mandatory_tail_or_fallback_overflow',
          ),
        ),
      ];
      throw PromptBudgetOverflowException(
        code: 'character.prompt_budget_overflow:mandatory_tail_or_fallback',
        trace: overflowTrace,
      );
    }
    remaining -= mandatoryResolvedTailTokens;

    final retainedOptionalShell = _retainShellEntries(
      entries: <BudgetCandidateEntry>[
        ...preHistoryEntries.where((entry) => !entry.mandatory),
        ...historyStartEntries.where((entry) => !entry.mandatory),
        ...fallbackEntries.where((entry) => !entry.mandatory),
        ...resolvedTailSplice.historyStartEntries.where(
          (entry) => !entry.mandatory,
        ),
        ...resolvedTailSplice.tailSpliceEntries.where(
          (entry) => !entry.mandatory,
        ),
        ...postHistoryEntries.where((entry) => !entry.mandatory),
      ],
      remainingBudget: remaining,
      trace: trace,
    );

    final finalPreHistory = <BudgetCandidateEntry>[
      ...preHistoryEntries.where((entry) => entry.mandatory),
      ...retainedOptionalShell.preHistoryEntries,
    ];
    final finalHistoryStart = <BudgetCandidateEntry>[
      ...historyStartEntries.where((entry) => entry.mandatory),
      ...fallbackEntries.where((entry) => entry.mandatory),
      ...resolvedTailSplice.historyStartEntries.where(
        (entry) => entry.mandatory,
      ),
      ...retainedOptionalShell.historyStartEntries,
    ];
    final finalTailSplice = <BudgetCandidateEntry>[
      ...resolvedTailSplice.tailSpliceEntries.where((entry) => entry.mandatory),
      ...retainedOptionalShell.tailSpliceEntries,
    ];
    final finalPostHistory = <BudgetCandidateEntry>[
      ...postHistoryEntries.where((entry) => entry.mandatory),
      ...retainedOptionalShell.postHistoryEntries,
    ];

    final messages = <TurnMessage>[
      ...finalPreHistory.map((entry) => entry.message),
      ...finalHistoryStart.map((entry) => entry.message),
      ...retainedBundles.expand(
        (bundle) => <TurnMessage>[
          ...bundle.spliceEntries.map((entry) => entry.message),
          bundle.historyEntry.message,
        ],
      ),
      ...finalTailSplice.map((entry) => entry.message),
      ...finalPostHistory.map((entry) => entry.message),
    ];

    return MessageBudgetResult(
      messages: List<TurnMessage>.unmodifiable(messages),
      trace: List<CroppingTrace>.unmodifiable(trace),
    );
  }

  ({
    List<BudgetCandidateEntry> preHistoryEntries,
    List<BudgetCandidateEntry> historyStartEntries,
    List<BudgetCandidateEntry> tailSpliceEntries,
    List<BudgetCandidateEntry> postHistoryEntries,
    int remainingBudget,
  })
  _retainShellEntries({
    required List<BudgetCandidateEntry> entries,
    required int remainingBudget,
    required List<CroppingTrace> trace,
  }) {
    final preHistoryEntries = <BudgetCandidateEntry>[];
    final historyStartEntries = <BudgetCandidateEntry>[];
    final tailSpliceEntries = <BudgetCandidateEntry>[];
    final postHistoryEntries = <BudgetCandidateEntry>[];
    final ordered = List<BudgetCandidateEntry>.from(entries)
      ..sort(_compareShellEntries);
    var remaining = remainingBudget;
    for (final entry in ordered) {
      final estimated = _estimateMessageTokens(entry.message);
      if (estimated <= remaining) {
        remaining -= estimated;
        if (entry.bucket == CandidatePlacementBucket.historyStart) {
          historyStartEntries.add(entry);
        } else if (entry.bucket == CandidatePlacementBucket.tailSplice) {
          tailSpliceEntries.add(entry);
        } else if (entry.bucket == CandidatePlacementBucket.postHistory) {
          postHistoryEntries.add(entry);
        } else {
          preHistoryEntries.add(entry);
        }
        trace.add(
          CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.retain,
            reason: 'shell_budget_retained',
          ),
        );
      } else {
        trace.add(
          CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.dropOverBudget,
            reason: 'shell_budget_exceeded',
          ),
        );
      }
    }
    return (
      preHistoryEntries: List<BudgetCandidateEntry>.unmodifiable(
        preHistoryEntries,
      ),
      historyStartEntries: List<BudgetCandidateEntry>.unmodifiable(
        historyStartEntries,
      ),
      tailSpliceEntries: List<BudgetCandidateEntry>.unmodifiable(
        tailSpliceEntries,
      ),
      postHistoryEntries: List<BudgetCandidateEntry>.unmodifiable(
        postHistoryEntries,
      ),
      remainingBudget: remaining,
    );
  }

  List<BudgetCandidateEntry> _collectFallbackEntries({
    required List<BudgetHistoryBundle> historyBundles,
    required Set<int> retainedOffsets,
    required List<CroppingTrace> trace,
  }) {
    final fallbackEntries = <BudgetCandidateEntry>[];
    for (final bundle in historyBundles) {
      if (retainedOffsets.contains(bundle.offsetFromEnd)) {
        continue;
      }
      for (final entry in bundle.spliceEntries) {
        if (entry.dropWithMissingAnchor) {
          trace.add(
            CroppingTrace(
              unitId: entry.unitId,
              stage: CroppingStage.finalRetainDrop,
              decision: RetainDecision.dropWithMissingAnchor,
              reason: 'drop_missing_anchor',
            ),
          );
          continue;
        }
        fallbackEntries.add(
          BudgetCandidateEntry(
            unitId: '${entry.unitId}@history_start',
            message: entry.message,
            sortOrder: entry.sortOrder,
            bucket: CandidatePlacementBucket.historyStart,
            priority: entry.priority,
            debugSourceKind: entry.debugSourceKind,
            mandatory: entry.mandatory,
          ),
        );
        trace.add(
          CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.retain,
            reason: 'fallback_to_history_start',
          ),
        );
      }
    }
    return fallbackEntries;
  }

  TailSpliceResolutionResult _resolveTailSpliceEntries({
    required List<BudgetCandidateEntry> tailSpliceEntries,
    required bool hasRetainedHistoryAnchor,
    required List<CroppingTrace> trace,
  }) {
    if (hasRetainedHistoryAnchor) {
      return TailSpliceResolutionResult(
        historyStartEntries: const <BudgetCandidateEntry>[],
        tailSpliceEntries: List<BudgetCandidateEntry>.unmodifiable(
          tailSpliceEntries,
        ),
      );
    }

    final historyStartEntries = <BudgetCandidateEntry>[];
    for (final entry in tailSpliceEntries) {
      if (entry.dropWithMissingAnchor) {
        trace.add(
          CroppingTrace(
            unitId: entry.unitId,
            stage: CroppingStage.finalRetainDrop,
            decision: RetainDecision.dropWithMissingAnchor,
            reason: 'drop_missing_tail_anchor',
          ),
        );
        continue;
      }
      historyStartEntries.add(
        BudgetCandidateEntry(
          unitId: '${entry.unitId}@history_start',
          message: entry.message,
          sortOrder: entry.sortOrder,
          bucket: CandidatePlacementBucket.historyStart,
          priority: entry.priority,
          debugSourceKind: entry.debugSourceKind,
          mandatory: entry.mandatory,
        ),
      );
      trace.add(
        CroppingTrace(
          unitId: entry.unitId,
          stage: CroppingStage.finalRetainDrop,
          decision: RetainDecision.retain,
          reason: 'fallback_tail_to_history_start',
        ),
      );
    }

    return TailSpliceResolutionResult(
      historyStartEntries: List<BudgetCandidateEntry>.unmodifiable(
        historyStartEntries,
      ),
      tailSpliceEntries: const <BudgetCandidateEntry>[],
    );
  }

  int _estimateHistoryBundleTokens(BudgetHistoryBundle bundle) {
    return _estimateMessageTokens(bundle.historyEntry.message) +
        bundle.spliceEntries.fold<int>(
          0,
          (sum, entry) => sum + _estimateMessageTokens(entry.message),
        );
  }

  int _compareShellEntries(BudgetCandidateEntry a, BudgetCandidateEntry b) {
    final tierCompare = _priorityPrecedence(
      a.priority,
    ).compareTo(_priorityPrecedence(b.priority));
    if (tierCompare != 0) {
      return tierCompare;
    }
    final sortCompare = a.sortOrder.compareTo(b.sortOrder);
    if (sortCompare != 0) {
      return sortCompare;
    }
    return a.unitId.compareTo(b.unitId);
  }

  int _priorityPrecedence(BudgetCandidatePriority priority) {
    return switch (priority) {
      BudgetCandidatePriority.mandatory => 0,
      BudgetCandidatePriority.high => 1,
      BudgetCandidatePriority.normal => 2,
      BudgetCandidatePriority.low => 3,
    };
  }

  int _estimateMessageTokens(TurnMessage message) {
    return _estimateTextTokens(_flattenContent(message.content));
  }

  int _estimateTextTokens(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return 0;
    }
    return (normalized.length / 4).ceil() + 4;
  }

  String _flattenContent(dynamic content) {
    if (content is String) {
      return content;
    }
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .map((part) => (part['text'] ?? '').toString())
          .where((text) => text.trim().isNotEmpty)
          .join('\n');
    }
    if (content is Map) {
      return (content['text'] ?? '').toString();
    }
    return content?.toString() ?? '';
  }
}
