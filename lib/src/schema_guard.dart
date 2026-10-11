/// The outcome of a schema or fixture comparison.
enum CompatibilityStatus {
  /// The change can be consumed without migration.
  compatible,

  /// A default or migration is required before the data is consumed.
  needsMigration,

  /// Existing consumers or data are no longer safe.
  breaking,

  /// The available metadata is insufficient to determine safety.
  unknown,
}

/// Controls how enum changes are classified.
enum EnumCompatibilityPolicy {
  /// Preserve the conservative defaults (added values warn, removed break).
  conservative,

  /// Treat added enum values as compatible.
  allowAddedValues,

  /// Treat removed enum values as compatible.
  allowRemovedValues,

  /// Treat both added and removed enum values as compatible.
  allowAddedAndRemovedValues,
}

/// Explicit compatibility exceptions.
class SchemaCompatibilityRules {
  /// Creates compatibility rules.
  SchemaCompatibilityRules({
    this.enumPolicy = EnumCompatibilityPolicy.conservative,
    Set<String> safeCoercions = const {},
  }) : safeCoercions = Set.unmodifiable(safeCoercions);

  /// The enum change policy.
  final EnumCompatibilityPolicy enumPolicy;

  /// Directional coercions represented as `oldType->newType`.
  final Set<String> safeCoercions;

  /// Rules that preserve the package's original behavior.
  static final conservative = SchemaCompatibilityRules();

  /// Rules allowing the commonly safe `int` to `double` conversion.
  static final intToDouble = SchemaCompatibilityRules(
    safeCoercions: {'int->double'},
  );

  /// Returns whether a type conversion is explicitly allowed.
  bool allowsCoercion(String oldType, String newType) =>
      safeCoercions.contains('$oldType->$newType');

  /// Returns whether an enum addition is allowed.
  bool get allowsAddedEnumValues =>
      enumPolicy == EnumCompatibilityPolicy.allowAddedValues ||
      enumPolicy == EnumCompatibilityPolicy.allowAddedAndRemovedValues;

  /// Returns whether an enum removal is allowed.
  bool get allowsRemovedEnumValues =>
      enumPolicy == EnumCompatibilityPolicy.allowRemovedValues ||
      enumPolicy == EnumCompatibilityPolicy.allowAddedAndRemovedValues;
}

/// Metadata describing one field in a [SchemaContract].
class SchemaField {
  /// Creates a field contract.
  const SchemaField({
    required this.name,
    required this.type,
    this.required = false,
    this.nullable = false,
    @Deprecated('Use required: false instead.') this.isOptional = false,
    this.nestedFields,
    this.enumValues,
  });

  /// The serialized field name.
  final String name;

  /// The expected serialized type, such as `String`, `int`, or `Map`.
  final String type;

  /// Whether a value must be present.
  final bool required;

  /// Whether a present value may be null.
  final bool nullable;

  /// Legacy spelling for an optional field.
  @Deprecated('Use required: false instead.')
  final bool isOptional;

  /// Child fields when this field contains an object.
  final Map<String, SchemaField>? nestedFields;

  /// Allowed serialized values for an enum field.
  final List<String>? enumValues;

  /// Creates a copy with selected metadata replaced.
  SchemaField copyWith({
    String? name,
    String? type,
    bool? required,
    bool? nullable,
    bool? isOptional,
    Map<String, SchemaField>? nestedFields,
    List<String>? enumValues,
  }) {
    return SchemaField(
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      nullable: nullable ?? this.nullable,
      isOptional: isOptional ?? this.isOptional,
      nestedFields: nestedFields ?? this.nestedFields,
      enumValues: enumValues ?? this.enumValues,
    );
  }

  /// Serializes this field contract to JSON-compatible metadata.
  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'required': required,
    'nullable': nullable,
    'isOptional': isOptional,
    if (nestedFields != null)
      'nestedFields': nestedFields!.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    if (enumValues != null) 'enumValues': enumValues,
  };
}

/// A versioned contract for an API endpoint or persisted storage key.
class SchemaContract {
  /// Creates a schema contract.
  ///
  /// When used as an annotation, [fields] may be omitted and the
  /// version/product/endpoint values identify the annotated model.
  const SchemaContract({
    required this.version,
    required this.product,
    required this.endpoint,
    this.fields = const {},
  });

  /// The application or API schema version.
  final String version;

  /// The product owning the contract.
  final String product;

  /// The endpoint or storage key represented by the contract.
  final String endpoint;

  /// The top-level fields in the contract.
  final Map<String, SchemaField> fields;

  /// Whether this contract has no fields.
  bool get isEmpty => fields.isEmpty;

  /// Serializes this contract to JSON-compatible metadata.
  Map<String, dynamic> toJson() => {
    'version': version,
    'product': product,
    'endpoint': endpoint,
    'fields': fields.map((key, value) => MapEntry(key, value.toJson())),
  };
}

/// The result of comparing two contracts or validating one fixture.
class CompatibilityReport {
  /// Creates a compatibility report.
  const CompatibilityReport({
    required this.status,
    required this.addedFields,
    required this.removedFields,
    required this.typeChanges,
    required this.requirednessChanges,
    required this.warnings,
    required this.summary,
  });

  /// The overall result.
  final CompatibilityStatus status;

  /// Fields present only in the new contract.
  final List<String> addedFields;

  /// Fields present only in the old contract.
  final List<String> removedFields;

  /// Paths whose serialized type changed.
  final List<String> typeChanges;

  /// Paths whose requiredness changed or required data is missing.
  final List<String> requirednessChanges;

  /// Non-fatal observations, including nullable and unknown fixture fields.
  final List<String> warnings;

  /// A concise, human-readable explanation of the result.
  final String summary;

  /// Whether the result is compatible.
  bool get isCompatible => status == CompatibilityStatus.compatible;

  /// Whether migration or defaults are needed.
  bool get needsMigration => status == CompatibilityStatus.needsMigration;

  /// Whether the result is breaking.
  bool get isBreaking => status == CompatibilityStatus.breaking;
}

/// Compares explicit schema contracts and validates historical JSON data.
class SchemaGuard {
  /// Creates a schema guard.
  const SchemaGuard();

  /// Compares [oldSchema] with [newSchema].
  ///
  /// Contracts for different products or endpoints return [CompatibilityStatus.unknown]
  /// rather than being compared as if they described the same data.
  static CompatibilityReport compareSchemas({
    required SchemaContract oldSchema,
    required SchemaContract newSchema,
    SchemaCompatibilityRules? rules,
  }) {
    final compatibilityRules = rules ?? SchemaCompatibilityRules.conservative;
    if (oldSchema.product != newSchema.product ||
        oldSchema.endpoint != newSchema.endpoint) {
      return _report(
        status: CompatibilityStatus.unknown,
        warnings: [
          'Contracts have different product or endpoint context and were not compared.',
        ],
      );
    }

    final added = <String>[];
    final removed = <String>[];
    final typeChanges = <String>[];
    final requirednessChanges = <String>[];
    final warnings = <String>[];
    _compareFields(
      oldSchema.fields,
      newSchema.fields,
      path: '',
      added: added,
      removed: removed,
      typeChanges: typeChanges,
      requirednessChanges: requirednessChanges,
      warnings: warnings,
      rules: compatibilityRules,
    );

    final status = removed.isNotEmpty || typeChanges.isNotEmpty
        ? CompatibilityStatus.breaking
        : requirednessChanges.isNotEmpty
        ? CompatibilityStatus.needsMigration
        : warnings.any((warning) => warning.startsWith('Cannot determine'))
        ? CompatibilityStatus.unknown
        : CompatibilityStatus.compatible;
    return _report(
      status: status,
      added: added,
      removed: removed,
      typeChanges: typeChanges,
      requirednessChanges: requirednessChanges,
      warnings: warnings,
    );
  }

  /// Validates a JSON [fixture] against [contract].
  static CompatibilityReport validateFixture({
    required SchemaContract contract,
    required Map<String, dynamic> fixture,
    SchemaCompatibilityRules? rules,
  }) {
    final compatibilityRules = rules ?? SchemaCompatibilityRules.conservative;
    final typeChanges = <String>[];
    final requirednessChanges = <String>[];
    final warnings = <String>[];
    _validateFields(
      contract.fields,
      fixture,
      path: '',
      typeChanges: typeChanges,
      requirednessChanges: requirednessChanges,
      warnings: warnings,
      rules: compatibilityRules,
    );
    final status = typeChanges.isNotEmpty
        ? CompatibilityStatus.breaking
        : requirednessChanges.isNotEmpty
        ? CompatibilityStatus.needsMigration
        : CompatibilityStatus.compatible;
    return _report(
      status: status,
      typeChanges: typeChanges,
      requirednessChanges: requirednessChanges,
      warnings: warnings,
      fixture: true,
    );
  }

  /// Runs a caller-owned migration against a deep copy of [data].
  ///
  /// Nested maps and lists are copied, and exceptions from [migration] are
  /// deliberately allowed to propagate unchanged.
  static Map<String, dynamic> migrateStorage({
    required Map<String, dynamic> data,
    required Map<String, dynamic> Function(Map<String, dynamic>) migration,
  }) => migration(_copyMap(data));

  static void _compareFields(
    Map<String, SchemaField> oldFields,
    Map<String, SchemaField> newFields, {
    required String path,
    required List<String> added,
    required List<String> removed,
    required List<String> typeChanges,
    required List<String> requirednessChanges,
    required List<String> warnings,
    required SchemaCompatibilityRules rules,
  }) {
    for (final entry in newFields.entries) {
      final fieldPath = _path(path, entry.key);
      final oldField = oldFields[entry.key];
      if (oldField == null) {
        added.add(fieldPath);
        if (entry.value.required) {
          requirednessChanges.add('$fieldPath was added as required');
        }
        continue;
      }
      final newField = entry.value;
      if (oldField.type != newField.type) {
        if (rules.allowsCoercion(oldField.type, newField.type)) {
          warnings.add(
            '$fieldPath allows safe coercion ${oldField.type} -> ${newField.type}',
          );
        } else {
          typeChanges.add('$fieldPath: ${oldField.type} -> ${newField.type}');
        }
      }
      if (oldField.required != newField.required) {
        requirednessChanges.add(
          '$fieldPath: ${oldField.required ? 'required' : 'optional'} -> '
          '${newField.required ? 'required' : 'optional'}',
        );
      }
      if (oldField.nullable != newField.nullable) {
        if (oldField.nullable && !newField.nullable) {
          typeChanges.add('$fieldPath became non-nullable');
        } else {
          warnings.add('$fieldPath became nullable');
        }
      }
      _compareEnums(
        fieldPath,
        oldField,
        newField,
        warnings,
        typeChanges,
        rules,
      );
      if (oldField.enumValues == null && newField.enumValues != null) {
        typeChanges.add('$fieldPath added an enum restriction');
      }
      if (oldField.nestedFields == null && newField.nestedFields != null) {
        for (final entry in newField.nestedFields!.entries) {
          final nested = entry.value;
          if (nested.required) {
            requirednessChanges.add(
              '$fieldPath.${entry.key} was added as required',
            );
          }
        }
      } else if (oldField.nestedFields != null &&
          newField.nestedFields == null) {
        warnings.add(
          'Cannot determine whether nested fields were removed at $fieldPath.',
        );
      } else if (oldField.nestedFields != null &&
          newField.nestedFields != null) {
        _compareFields(
          oldField.nestedFields!,
          newField.nestedFields!,
          path: fieldPath,
          added: added,
          removed: removed,
          typeChanges: typeChanges,
          requirednessChanges: requirednessChanges,
          warnings: warnings,
          rules: rules,
        );
      }
    }
    for (final name in oldFields.keys) {
      if (!newFields.containsKey(name)) {
        removed.add(_path(path, name));
      }
    }
  }

  static void _compareEnums(
    String path,
    SchemaField oldField,
    SchemaField newField,
    List<String> warnings,
    List<String> typeChanges,
    SchemaCompatibilityRules rules,
  ) {
    final oldValues = oldField.enumValues;
    final newValues = newField.enumValues;
    if (oldValues == null || newValues == null) return;
    final removed = oldValues.where((value) => !newValues.contains(value));
    final added = newValues.where((value) => !oldValues.contains(value));
    if (removed.isNotEmpty) {
      final message = '$path removed enum values: ${removed.join(', ')}';
      if (rules.allowsRemovedEnumValues) {
        warnings.add('$message (allowed by compatibility rules)');
      } else {
        typeChanges.add(message);
      }
    }
    if (added.isNotEmpty) {
      final message = '$path added enum values: ${added.join(', ')}';
      if (rules.allowsAddedEnumValues) {
        warnings.add('$message (allowed by compatibility rules)');
      } else {
        warnings.add(message);
      }
    }
  }

  static void _validateFields(
    Map<String, SchemaField> fields,
    Map<String, dynamic> values, {
    required String path,
    required List<String> typeChanges,
    required List<String> requirednessChanges,
    required List<String> warnings,
    required SchemaCompatibilityRules rules,
  }) {
    for (final entry in fields.entries) {
      final fieldPath = _path(path, entry.key);
      final field = entry.value;
      if (!values.containsKey(entry.key)) {
        if (field.required) {
          requirednessChanges.add(
            '$fieldPath is required but missing from fixture',
          );
        } else {
          warnings.add(
            '$fieldPath is optional and missing; default behavior will be used',
          );
        }
        continue;
      }
      final value = values[entry.key];
      if (value == null) {
        if (!field.nullable) {
          typeChanges.add('$fieldPath has type null but is not nullable');
        }
        continue;
      }
      if (_typeName(value) != field.type &&
          !rules.allowsCoercion(_typeName(value), field.type)) {
        typeChanges.add(
          '$fieldPath has type ${_typeName(value)} but schema expects ${field.type}',
        );
        continue;
      }
      if (field.enumValues != null &&
          value is String &&
          !field.enumValues!.contains(value)) {
        typeChanges.add('$fieldPath has unknown enum value $value');
      }
      if (field.nestedFields != null && value is Map) {
        _validateFields(
          field.nestedFields!,
          value.cast<String, dynamic>(),
          path: fieldPath,
          typeChanges: typeChanges,
          requirednessChanges: requirednessChanges,
          warnings: warnings,
          rules: rules,
        );
      }
    }
    for (final key in values.keys) {
      if (!fields.containsKey(key)) {
        warnings.add('${_path(path, key)} is not defined by the contract');
      }
    }
  }

  static String _path(String parent, String child) =>
      parent.isEmpty ? child : '$parent.$child';

  static Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
      value.map((key, item) => MapEntry(key, _copyValue(item)));

  static dynamic _copyValue(dynamic value) {
    if (value is Map<String, dynamic>) return _copyMap(value);
    if (value is Map) {
      return value.map<String, dynamic>(
        (key, item) => MapEntry(key.toString(), _copyValue(item)),
      );
    }
    if (value is List) return value.map(_copyValue).toList();
    return value;
  }

  static String _typeName(Object? value) {
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is String) return 'String';
    if (value is bool) return 'bool';
    if (value is List) return 'List';
    if (value is Map) return 'Map';
    return value.runtimeType.toString();
  }

  static CompatibilityReport _report({
    required CompatibilityStatus status,
    List<String> added = const [],
    List<String> removed = const [],
    List<String> typeChanges = const [],
    List<String> requirednessChanges = const [],
    List<String> warnings = const [],
    bool fixture = false,
  }) {
    final messages = <String>[
      if (added.isNotEmpty) 'Added fields: ${added.join(', ')}.',
      if (removed.isNotEmpty) 'Removed fields: ${removed.join(', ')}.',
      if (typeChanges.isNotEmpty) 'Type changes: ${typeChanges.join('; ')}.',
      if (requirednessChanges.isNotEmpty)
        'Requiredness changes: ${requirednessChanges.join('; ')}.',
      if (warnings.isNotEmpty) 'Warnings: ${warnings.join('; ')}.',
    ];
    final base = fixture
        ? switch (status) {
            CompatibilityStatus.compatible =>
              'Fixture matches the current schema.',
            CompatibilityStatus.needsMigration =>
              'Fixture needs migration or fallback handling.',
            CompatibilityStatus.breaking =>
              'Fixture is incompatible with the current schema.',
            CompatibilityStatus.unknown => 'Fixture compatibility is unknown.',
          }
        : switch (status) {
            CompatibilityStatus.compatible => 'Schema is backward compatible.',
            CompatibilityStatus.needsMigration =>
              'Schema requires migration or defaults before safe use.',
            CompatibilityStatus.breaking =>
              'Schema change is breaking for existing consumers.',
            CompatibilityStatus.unknown =>
              'Compatibility could not be determined confidently.',
          };
    return CompatibilityReport(
      status: status,
      addedFields: List.unmodifiable(added),
      removedFields: List.unmodifiable(removed),
      typeChanges: List.unmodifiable(typeChanges),
      requirednessChanges: List.unmodifiable(requirednessChanges),
      warnings: List.unmodifiable(warnings),
      summary: messages.isEmpty ? base : '$base ${messages.join(' ')}',
    );
  }
}
