// Package-internal model: variable set (macro-side variable resolution).
//
// Provenance: verbatim copy of
//   lib/features/prompt_lab/data/models/variable_set.dart
// Zero external imports; no rewrite required. Byte-identical class /
// enum / field names.
class VariableEntryResource {
  const VariableEntryResource({
    required this.id,
    required this.key,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
    this.valueType = 'string',
    this.enabled = true,
    this.sortOrder = 0,
  });

  final String id;
  final String key;
  final dynamic value;
  final String valueType;
  final bool enabled;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  VariableEntryResource copyWith({
    String? id,
    String? key,
    dynamic value,
    String? valueType,
    bool? enabled,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VariableEntryResource(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class VariableSetResource {
  const VariableSetResource({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isDefault = false,
    this.entries = const <VariableEntryResource>[],
  });

  final String id;
  final String name;
  final String? description;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VariableEntryResource> entries;

  VariableSetResource copyWith({
    String? id,
    String? name,
    String? description,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<VariableEntryResource>? entries,
  }) {
    return VariableSetResource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
    );
  }
}
