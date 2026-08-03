// Hand-written pure-Dart Persona subset for the compiler package.
//
// The Starry-side `lib/features/persona/data/models/persona.dart` uses freezed
// + json_serializable so it can be persisted and diffed by the host. The
// compiler only *reads* five fields from Persona plus the full
// `PersonaDescriptionPosition` enum. This file mirrors exactly that subset
// with byte-identical class names, field names, enum literals, and defaults.
//
// Fields exposed here (empirically enumerated by scanning Planner, Assembler,
// MacroService, and WorldInfoMatcher):
//   * id
//   * name
//   * description
//   * descriptionSettings.position
//   * descriptionSettings.depth
//   * systemPromptOverride            (Planner)
//   * postHistoryInstructions         (Planner)
//   * PersonaDescriptionPosition (all 6 variants)
//
// The Starry-side Persona has additional fields (avatar, connections, tags,
// createdAt, isDefault, ...) that this package never consumes. The host will
// provide a tiny adapter mapping the Starry model to this subset.

enum PersonaDescriptionPosition {
  beforeChar,
  afterChar,
  atDepth,
  inSystemPrompt,
  topAN,
  bottomAN,
}

enum PersonaDescriptionRole { system, user, assistant }

class PersonaDescriptionSettings {
  const PersonaDescriptionSettings({
    this.position = PersonaDescriptionPosition.beforeChar,
    this.depth = 0,
    this.role = PersonaDescriptionRole.system,
  });

  final PersonaDescriptionPosition position;
  final int depth;
  final PersonaDescriptionRole role;

  PersonaDescriptionSettings copyWith({
    PersonaDescriptionPosition? position,
    int? depth,
    PersonaDescriptionRole? role,
  }) {
    return PersonaDescriptionSettings(
      position: position ?? this.position,
      depth: depth ?? this.depth,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersonaDescriptionSettings &&
          runtimeType == other.runtimeType &&
          position == other.position &&
          depth == other.depth &&
          role == other.role;

  @override
  int get hashCode => Object.hash(position, depth, role);
}

class Persona {
  const Persona({
    required this.id,
    required this.name,
    this.description = '',
    this.descriptionSettings = const PersonaDescriptionSettings(),
    this.systemPromptOverride,
    this.postHistoryInstructions,
  });

  final String id;
  final String name;
  final String description;
  final PersonaDescriptionSettings descriptionSettings;
  final String? systemPromptOverride;
  final String? postHistoryInstructions;

  Persona copyWith({
    String? id,
    String? name,
    String? description,
    PersonaDescriptionSettings? descriptionSettings,
    String? systemPromptOverride,
    String? postHistoryInstructions,
  }) {
    return Persona(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      descriptionSettings: descriptionSettings ?? this.descriptionSettings,
      systemPromptOverride: systemPromptOverride ?? this.systemPromptOverride,
      postHistoryInstructions:
          postHistoryInstructions ?? this.postHistoryInstructions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Persona &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          descriptionSettings == other.descriptionSettings &&
          systemPromptOverride == other.systemPromptOverride &&
          postHistoryInstructions == other.postHistoryInstructions;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    descriptionSettings,
    systemPromptOverride,
    postHistoryInstructions,
  );
}
