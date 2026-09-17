// Package-internal model: prompt profile (owner-scoped named preset).
//
// Provenance: verbatim copy of
//   lib/features/prompt_lab/data/models/prompt_profile.dart
// Import rewrite only:
//   package:starry/features/prompt_lab/data/models/prompt_manager.dart
//   -> 'prompt_manager.dart'
// Byte-identical class / enum / field names.
import 'prompt_manager.dart';

class PromptProfileResource {
  const PromptProfileResource({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.blocks = const <PromptBlock>[],
    this.isDefault = false,
    this.isBuiltIn = false,
  });

  factory PromptProfileResource.fromJson(Map<String, dynamic> json) {
    return PromptProfileResource(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      config: PromptManagerConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map<dynamic, dynamic>),
      ),
      blocks:
          (json['blocks'] as List?)
              ?.whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => PromptBlock.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false) ??
          const <PromptBlock>[],
      isDefault: json['isDefault'] == true,
      isBuiltIn: json['isBuiltIn'] == true,
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
  final PromptManagerConfig config;
  final List<PromptBlock> blocks;
  final bool isDefault;
  final bool isBuiltIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<PromptBlock> get resolvedBlocks =>
      blocks.isNotEmpty ? blocks : config.toPromptBlocks(promptProfileId: id);

  PromptProfileResource copyWith({
    String? id,
    String? name,
    String? description,
    PromptManagerConfig? config,
    List<PromptBlock>? blocks,
    bool? isDefault,
    bool? isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptProfileResource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      config: config ?? this.config,
      blocks: blocks ?? this.blocks,
      isDefault: isDefault ?? this.isDefault,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'config': config.toJson(),
    'blocks': resolvedBlocks.map((block) => block.toJson()).toList(),
    'isDefault': isDefault,
    'isBuiltIn': isBuiltIn,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
