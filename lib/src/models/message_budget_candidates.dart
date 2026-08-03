// Copied verbatim from Starry
// lib/features/chat/domain/models/message_budget_candidates.dart (Block C-8).
// Field / enum names are byte-identical to the source so goldens / adapters
// do not need translation. Only the import paths are rewritten to sibling
// package paths (starry:.../conversation_turns_models -> ./conversation_turns_models,
// starry:.../message_budget_models -> ./message_budget_models).

import 'conversation_turns_models.dart';
import 'message_budget_models.dart';

enum CandidatePlacementBucket {
  preHistory,
  historyStart,
  historyBundle,
  tailSplice,
  postHistory,
}

enum BudgetCandidatePriority { mandatory, high, normal, low }

class BudgetCandidateEntry {
  const BudgetCandidateEntry({
    required this.unitId,
    required this.message,
    required this.sortOrder,
    required this.bucket,
    required this.priority,
    this.debugSourceKind,
    this.mandatory = false,
    this.dropWithMissingAnchor = false,
  });

  final String unitId;
  final TurnMessage message;
  final int sortOrder;
  final CandidatePlacementBucket bucket;
  final BudgetCandidatePriority priority;
  final String? debugSourceKind;
  final bool mandatory;
  final bool dropWithMissingAnchor;
}

class BudgetHistoryBundle {
  const BudgetHistoryBundle({
    required this.offsetFromEnd,
    required this.historyEntry,
    required this.spliceEntries,
  });

  final int offsetFromEnd;
  final BudgetCandidateEntry historyEntry;
  final List<BudgetCandidateEntry> spliceEntries;
}

class MessageBudgetResult {
  const MessageBudgetResult({required this.messages, required this.trace});

  final List<TurnMessage> messages;
  final List<CroppingTrace> trace;
}

class TailSpliceResolutionResult {
  const TailSpliceResolutionResult({
    required this.historyStartEntries,
    required this.tailSpliceEntries,
  });

  final List<BudgetCandidateEntry> historyStartEntries;
  final List<BudgetCandidateEntry> tailSpliceEntries;
}
