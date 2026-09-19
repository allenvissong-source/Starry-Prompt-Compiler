// Package-internal model: character + depth prompt + authorship entities.
//
// Provenance: verbatim copy of
//   lib/features/starry/domain/models/character_entities.dart
// The source file had zero external imports (pure Dart data classes). The
// single import below is package-internal, added when the persisted-instant
// conversion was extracted to one helper. Class / enum / field names remain
// byte-identical to the Starry source.
import 'instant_storage.dart';

class CharacterDepthPrompt {
  const CharacterDepthPrompt({
    required this.text,
    this.depth = 4,
    this.role = 'system',
  });

  factory CharacterDepthPrompt.fromJson(Map<String, dynamic> json) {
    return CharacterDepthPrompt(
      text: (json['text'] ?? json['prompt'] ?? '').toString(),
      depth: json['depth'] is int
          ? json['depth'] as int
          : int.tryParse((json['depth'] ?? '').toString()) ?? 4,
      role:
          ((json['role'] ?? 'system').toString().trim().isEmpty
                  ? 'system'
                  : (json['role'] ?? 'system').toString().trim())
              .toLowerCase(),
    );
  }

  final String text;
  final int depth;
  final String role;

  CharacterDepthPrompt copyWith({String? text, int? depth, String? role}) {
    return CharacterDepthPrompt(
      text: text ?? this.text,
      depth: depth ?? this.depth,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text,
    'depth': depth,
    'role': role,
  };
}

class Character {
  const Character({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.nickname,
    required this.description,
    required this.personality,
    required this.scenario,
    required this.firstMessage,
    required this.alternateGreetings,
    required this.exampleMessages,
    required this.systemPrompt,
    required this.postHistoryInstructions,
    required this.tags,
    required this.isSystem,
    required this.visibilityScope,
    required this.createdAt,
    required this.updatedAt,
    this.depthPrompt,
    this.talkativeness = 0.5,
    this.creatorNotes = '',
    this.characterVersion = '1.0',
    this.syncState = 'synced',
    this.localUpdatedAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String nickname;
  final String description;
  final String personality;
  final String scenario;
  final String firstMessage;
  final List<String> alternateGreetings;
  final String exampleMessages;
  final String systemPrompt;
  final String postHistoryInstructions;
  final CharacterDepthPrompt? depthPrompt;

  /// Group-chat speaking eagerness, 0.0 - 1.0. First-class character field
  /// (Starry internal wording); only the v3 import/export codec maps it to
  /// `data.extensions.talkativeness`.
  final double talkativeness;

  /// Author-facing notes shipped with the character card body.
  final String creatorNotes;

  /// Card body version string (v3 `character_version`).
  final String characterVersion;
  final List<String> tags;
  final bool isSystem;
  final String visibilityScope;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  final DateTime? localUpdatedAt;

  Character copyWith({
    String? id,
    String? ownerUserId,
    String? name,
    String? nickname,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    List<String>? alternateGreetings,
    String? exampleMessages,
    String? systemPrompt,
    String? postHistoryInstructions,
    CharacterDepthPrompt? depthPrompt,
    double? talkativeness,
    String? creatorNotes,
    String? characterVersion,
    List<String>? tags,
    bool? isSystem,
    String? visibilityScope,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
    DateTime? localUpdatedAt,
  }) {
    return Character(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      description: description ?? this.description,
      personality: personality ?? this.personality,
      scenario: scenario ?? this.scenario,
      firstMessage: firstMessage ?? this.firstMessage,
      alternateGreetings: alternateGreetings ?? this.alternateGreetings,
      exampleMessages: exampleMessages ?? this.exampleMessages,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      postHistoryInstructions:
          postHistoryInstructions ?? this.postHistoryInstructions,
      depthPrompt: depthPrompt ?? this.depthPrompt,
      talkativeness: talkativeness ?? this.talkativeness,
      creatorNotes: creatorNotes ?? this.creatorNotes,
      characterVersion: characterVersion ?? this.characterVersion,
      tags: tags ?? this.tags,
      isSystem: isSystem ?? this.isSystem,
      visibilityScope: visibilityScope ?? this.visibilityScope,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'owner_user_id': ownerUserId,
      'name': name,
      'nickname': nickname,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'first_message': firstMessage,
      'alternate_greetings': alternateGreetings,
      'example_messages': exampleMessages,
      'system_prompt': systemPrompt,
      'post_history_instructions': postHistoryInstructions,
      if (depthPrompt != null) 'depth_prompt': depthPrompt!.toJson(),
      'talkativeness': talkativeness,
      'creator_notes': creatorNotes,
      'character_version': characterVersion,
      'tags': tags,
      'is_system': isSystem,
      'visibility_scope': visibilityScope,
      'created_at': instantToStorageString(createdAt),
      'updated_at': instantToStorageString(updatedAt),
    };
  }
}

class CharacterAuthorship {
  const CharacterAuthorship({
    required this.id,
    required this.characterId,
    required this.creatorUserId,
    required this.createdAt,
    required this.updatedAt,
    this.syncState = 'synced',
    this.localUpdatedAt,
  });

  final String id;
  final String characterId;
  final String creatorUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncState;
  final DateTime? localUpdatedAt;

  CharacterAuthorship copyWith({
    String? id,
    String? characterId,
    String? creatorUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
    DateTime? localUpdatedAt,
  }) {
    return CharacterAuthorship(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'character_id': characterId,
      'creator_user_id': creatorUserId,
      'created_at': instantToStorageString(createdAt),
      'updated_at': instantToStorageString(updatedAt),
    };
  }
}
