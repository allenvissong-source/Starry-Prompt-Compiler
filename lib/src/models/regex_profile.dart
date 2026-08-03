// Package-internal model: regex profile (grouped regex script collection).
//
// Provenance: verbatim copy of
//   lib/features/prompt_lab/data/models/regex_profile.dart
// Import rewrite only:
//   package:starry/features/prompt_lab/data/models/regex_script.dart
//   -> 'regex_script.dart'
// Byte-identical class / enum / field names.
import 'regex_script.dart';

class RegexProfileSettingsResource {
  const RegexProfileSettingsResource({
    this.enabled = true,
    this.applyToUserInput = true,
    this.applyToAiOutput = true,
    this.applyToSlashCommands = false,
    this.applyToWorldInfo = false,
    this.applyToReasoning = false,
  });

  factory RegexProfileSettingsResource.fromJson(Map<String, dynamic> json) {
    return RegexProfileSettingsResource(
      enabled: json['enabled'] as bool? ?? true,
      applyToUserInput: json['applyToUserInput'] as bool? ?? true,
      applyToAiOutput: json['applyToAiOutput'] as bool? ?? true,
      applyToSlashCommands: json['applyToSlashCommands'] as bool? ?? false,
      applyToWorldInfo: json['applyToWorldInfo'] as bool? ?? false,
      applyToReasoning: json['applyToReasoning'] as bool? ?? false,
    );
  }

  final bool enabled;
  final bool applyToUserInput;
  final bool applyToAiOutput;
  final bool applyToSlashCommands;
  final bool applyToWorldInfo;
  final bool applyToReasoning;

  RegexProfileSettingsResource copyWith({
    bool? enabled,
    bool? applyToUserInput,
    bool? applyToAiOutput,
    bool? applyToSlashCommands,
    bool? applyToWorldInfo,
    bool? applyToReasoning,
  }) {
    return RegexProfileSettingsResource(
      enabled: enabled ?? this.enabled,
      applyToUserInput: applyToUserInput ?? this.applyToUserInput,
      applyToAiOutput: applyToAiOutput ?? this.applyToAiOutput,
      applyToSlashCommands: applyToSlashCommands ?? this.applyToSlashCommands,
      applyToWorldInfo: applyToWorldInfo ?? this.applyToWorldInfo,
      applyToReasoning: applyToReasoning ?? this.applyToReasoning,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'applyToUserInput': applyToUserInput,
    'applyToAiOutput': applyToAiOutput,
    'applyToSlashCommands': applyToSlashCommands,
    'applyToWorldInfo': applyToWorldInfo,
    'applyToReasoning': applyToReasoning,
  };
}

class RegexProfileResource {
  const RegexProfileResource({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.settings = const RegexProfileSettingsResource(),
    this.isDefault = false,
  });

  factory RegexProfileResource.fromJson(Map<String, dynamic> json) {
    return RegexProfileResource(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      settings: RegexProfileSettingsResource.fromJson(
        Map<String, dynamic>.from(
          (json['settings'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
      isDefault: json['isDefault'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String name;
  final String? description;
  final RegexProfileSettingsResource settings;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  RegexProfileResource copyWith({
    String? id,
    String? name,
    String? description,
    RegexProfileSettingsResource? settings,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RegexProfileResource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      settings: settings ?? this.settings,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'settings': settings.toJson(),
    'isDefault': isDefault,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class RegexProfileBundle {
  const RegexProfileBundle({required this.profile, required this.scripts});

  final RegexProfileResource profile;
  final List<RegexScript> scripts;
}
