// Copied verbatim from Starry lib/features/chat/domain/models/message_budget_models.dart
// (Block C-3.1). No dependencies. Field / enum names are byte-identical to
// the source so goldens / adapters do not need translation.

enum RetainDecision {
  retain,
  dropDisabled,
  dropTriggerMismatch,
  dropOverSubBudget,
  dropOverBudget,
  dropWithMissingAnchor,
  dropMandatoryOverflow,
}

enum CroppingStage { preBudgetAdmission, finalRetainDrop }

class MessageBudgetPlan {
  const MessageBudgetPlan({
    this.modelContextWindow,
    this.reservedResponseTokens,
    this.protocolReserveTokens = 0,
    this.availableInputTokens,
    this.enableBudgetPass = false,
    this.maxHistoryMessages,
  });

  final int? modelContextWindow;
  final int? reservedResponseTokens;
  final int protocolReserveTokens;
  final int? availableInputTokens;
  final bool enableBudgetPass;
  final int? maxHistoryMessages;

  int? get resolvedAvailableInputTokens {
    final explicit = availableInputTokens;
    if (explicit != null) {
      return explicit < 0 ? 0 : explicit;
    }
    final contextWindow = modelContextWindow;
    if (contextWindow == null) {
      return null;
    }
    final resolved =
        contextWindow - (reservedResponseTokens ?? 0) - protocolReserveTokens;
    return resolved < 0 ? 0 : resolved;
  }
}

class CroppingTrace {
  const CroppingTrace({
    required this.unitId,
    required this.stage,
    required this.decision,
    required this.reason,
  });

  final String unitId;
  final CroppingStage stage;
  final RetainDecision decision;
  final String reason;
}

class PromptBudgetOverflowException implements Exception {
  PromptBudgetOverflowException({
    required this.code,
    required List<CroppingTrace> trace,
  }) : trace = List<CroppingTrace>.unmodifiable(trace);

  final String code;
  final List<CroppingTrace> trace;

  @override
  String toString() => 'PromptBudgetOverflowException($code)';
}
