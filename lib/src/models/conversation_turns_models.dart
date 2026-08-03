// Package-internal model: conversation turn primitives (subset).
//
// Provenance: minimal subset of
//   lib/core/api/canonical/conversation_turns_models.dart
// Copied byte-for-byte (class / enum / field / wire-value names identical
// to the Starry source) so behavior_v1 goldens remain valid under
// SUT=package.
//
// Included symbols (only what the 5 in-scope services and
// character_assembly_models actually reference):
//   - enum TurnMessageRole
//   - class TurnMessage
//
// Deliberately excluded (Host-side / streaming / transport concerns; not
// reachable from Planner / Admission / WorldInfoMatcher / MacroService /
// RegexService / Assembler.pure):
//   - enum TurnPolicy
//   - class MemoryRequest
//   - class TurnInputSegments
//   - class TurnResource
//   - class ActiveExecutionRef
//   - class TurnSendEnvelope
//   - class TurnSendSerializer
//   - class ConversationTurnRequest
//   - class TurnStreamSession / Meta / Event / *Delta / *Reasoning /
//     *CharacterPayload / *Live2dCommand / *Done / *Error / *RawEvent
//
// These stay in the Starry host until Block D wiring; if a future service
// migration needs any of them we extend this file (or split it) at that
// time, with the same evidence-first discipline.
//
// Original imports (dart:math, package:flutter/foundation.dart,
// package:starry/core/utils/platform_utils.dart) are all dropped because
// none of the retained symbols require them.

enum TurnMessageRole {
  system,
  user,
  assistant;

  String get wireValue => switch (this) {
    TurnMessageRole.system => 'system',
    TurnMessageRole.user => 'user',
    TurnMessageRole.assistant => 'assistant',
  };
}

class TurnMessage {
  const TurnMessage({required this.role, required this.content});

  final TurnMessageRole role;
  final dynamic content;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role.wireValue,
    'content': content,
  };
}
