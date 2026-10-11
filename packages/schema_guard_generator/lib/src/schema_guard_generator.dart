import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

const _jsonSerializable = TypeChecker.fromUrl(
  'package:json_annotation/src/json_serializable.dart#JsonSerializable',
);
const _schemaVersion = TypeChecker.fromUrl(
  'package:schema_guard/schema_guard.dart#SchemaVersion',
);
const _schemaContract = TypeChecker.fromUrl(
  'package:schema_guard/src/schema_guard.dart#SchemaContract',
);
const _schemaProduct = TypeChecker.fromUrl(
  'package:schema_guard/schema_guard.dart#SchemaProduct',
);
const _schemaEndpoint = TypeChecker.fromUrl(
  'package:schema_guard/schema_guard.dart#SchemaEndpoint',
);
const _requiredField = TypeChecker.fromUrl(
  'package:schema_guard/schema_guard.dart#RequiredField',
);
const _optionalField = TypeChecker.fromUrl(
  'package:schema_guard/schema_guard.dart#OptionalField',
);
const _serializedType = TypeChecker.fromUrl(
  'package:schema_guard/schema_guard.dart#SchemaSerializedType',
);
const _jsonKey = TypeChecker.fromUrl(
  'package:json_annotation/src/json_key.dart#JsonKey',
);
const _jsonValue = TypeChecker.fromUrl(
  'package:json_annotation/src/json_value.dart#JsonValue',
);

/// Generates one contract-shaped metadata constant per annotated model.
class SchemaGuardGenerator extends Generator {
  /// Creates a schema metadata generator.
  const SchemaGuardGenerator();

  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final serializable = library.classes
        .where(
          (element) => _jsonSerializable.firstAnnotationOf(element) != null,
        )
        .toList();
    final nested = serializable
        .expand((element) => element.fields)
        .map((field) => field.type.element)
        .whereType<ClassElement>()
        .where(
          (element) => _jsonSerializable.firstAnnotationOf(element) != null,
        )
        .toSet();
    final models = <_Model>[];
    for (final element in serializable) {
      final isRoot =
          _schemaContract.firstAnnotationOf(element) != null ||
          _schemaVersion.firstAnnotationOf(element) != null ||
          _schemaProduct.firstAnnotationOf(element) != null ||
          _schemaEndpoint.firstAnnotationOf(element) != null ||
          !nested.contains(element);
      if (isRoot) models.add(_model(element));
    }
    models.sort((a, b) => a.name.compareTo(b.name));
    if (models.isEmpty) return '';

    return [
      for (final model in models) ...[
        'const ${model.constantName} = <String, dynamic>{',
        "  'version': '${_quote(model.version)}',",
        "  'product': '${_quote(model.product)}',",
        "  'endpoint': '${_quote(model.endpoint)}',",
        "  'fields': <String, dynamic>{",
        for (final field in model.fields) ...[
          "    '${_quote(field.name)}': <String, dynamic>{",
          "      'name': '${_quote(field.name)}',",
          "      'type': '${_quote(field.type)}',",
          "      'required': ${field.required},",
          "      'nullable': ${field.nullable},",
          if (field.nested != null) ...[
            "      'nestedFields': <String, dynamic>{",
            for (final child in field.nested!) ...[
              "        '${_quote(child.name)}': ${_fieldCode(child)},",
            ],
            '      },',
          ],
          if (field.enumValues != null)
            "      'enumValues': <String>[${field.enumValues!.map((value) => "'${_quote(value)}'").join(', ')}],",
          '    },',
        ],
        '  },',
        '};',
        '',
      ],
    ].join('\n');
  }

  _Model _model(ClassElement element) {
    final combined = _schemaContract.annotationsOf(element);
    final version = _contextValue(
      element,
      combined,
      'version',
      _schemaVersion,
      'value',
    );
    final product = _contextValue(
      element,
      combined,
      'product',
      _schemaProduct,
      'value',
    );
    final endpoint = _contextValue(
      element,
      combined,
      'endpoint',
      _schemaEndpoint,
      'value',
    );
    if (version == null || product == null || endpoint == null) {
      throw InvalidGenerationSourceError(
        '${element.name} must declare @SchemaContract or '
        '@SchemaVersion, @SchemaProduct, and @SchemaEndpoint.',
        element: element,
      );
    }

    final serializable = _jsonSerializable.firstAnnotationOf(element)!;
    final rename =
        serializable.getField('fieldRename')?.getField('index')?.toIntValue() ??
        0;
    final fields =
        element.fields
            .where((field) => !field.isStatic && field.isPublic)
            .map((field) => _field(field, rename))
            .whereType<_Field>()
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return _Model(element.name ?? '', version, product, endpoint, fields);
  }

  _Field? _field(FieldElement field, int rename) {
    final key = _jsonKey.firstAnnotationOf(field);
    final keyValue = key;
    final ignored =
        keyValue?.getField('ignore')?.toBoolValue() == true ||
        (keyValue?.getField('includeFromJson')?.toBoolValue() == false &&
            keyValue?.getField('includeToJson')?.toBoolValue() == false);
    if (ignored) return null;
    if (keyValue?.getField('includeFromJson')?.toBoolValue() == false ||
        keyValue?.getField('includeToJson')?.toBoolValue() == false) {
      throw InvalidGenerationSourceError(
        'Field ${field.name} is serialized in only one direction; '
        'schema_guard metadata is bidirectional.',
        element: field,
      );
    }

    final name =
        keyValue?.getField('name')?.toStringValue() ??
        _rename(field.name ?? '', rename);
    final explicitRequired = _requiredField.firstAnnotationOf(field) != null;
    final explicitOptional = _optionalField.firstAnnotationOf(field) != null;
    if (explicitRequired && explicitOptional) {
      throw InvalidGenerationSourceError(
        'Field ${field.name} cannot use both @RequiredField and @OptionalField.',
        element: field,
      );
    }
    final defaultValue = keyValue?.getField('defaultValue');
    final hasDefault =
        defaultValue != null && !defaultValue.isNull ||
        _hasConstructorDefault(field);
    final required = explicitRequired
        ? true
        : explicitOptional
        ? false
        : keyValue?.getField('required')?.toBoolValue() == true ||
              (!hasDefault &&
                  field.type.nullabilitySuffix != NullabilitySuffix.question);
    final nullable =
        keyValue?.getField('disallowNullValue')?.toBoolValue() == true
        ? false
        : field.type.nullabilitySuffix == NullabilitySuffix.question;
    final override = _serializedType.firstAnnotationOf(field);
    final type = override?.getField('value')?.toStringValue();
    final hasCustomReader =
        keyValue?.getField('fromJson')?.isNull == false ||
        keyValue?.getField('toJson')?.isNull == false ||
        keyValue?.getField('readValue')?.isNull == false;
    if (hasCustomReader && type == null) {
      throw InvalidGenerationSourceError(
        'Field ${field.name} uses custom JSON conversion. Add '
        '@SchemaSerializedType to describe its wire type.',
        element: field,
      );
    }
    final description = _describe(field.type, field);
    if (type != null) {
      return _Field(name, type, required, nullable);
    }
    return _Field(
      name,
      description.type,
      required,
      nullable,
      description.nested,
      description.enums,
    );
  }

  _Description _describe(DartType type, FieldElement field) {
    final element = type.element;
    if (element is EnumElement) {
      final values = <String>[];
      for (final constant in element.fields.where(
        (item) => item.isEnumConstant,
      )) {
        final annotation = _jsonValue.firstAnnotationOf(constant);
        final value = annotation?.getField('value');
        if (value == null || value.isNull) {
          values.add(_rename(constant.name ?? '', _enumRename(element)));
        } else if (value.toStringValue() case final string?) {
          values.add(string);
        } else {
          throw InvalidGenerationSourceError(
            'Enum ${element.name} has a non-string @JsonValue; '
            'schema_guard supports string enum values only.',
            element: constant,
          );
        }
      }
      return _Description('String', enums: values);
    }
    if (element is ClassElement &&
        _jsonSerializable.firstAnnotationOf(element) != null) {
      final annotation = _jsonSerializable.firstAnnotationOf(element);
      final rename =
          annotation
              ?.getField('fieldRename')
              ?.getField('index')
              ?.toIntValue() ??
          0;
      final nested =
          element.fields
              .where((field) => !field.isStatic && field.isPublic)
              .map((field) => _field(field, rename))
              .whereType<_Field>()
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return _Description('Map', nested: nested);
    }
    final name = type.element?.name ?? type.getDisplayString();
    if (name == 'DateTime') return const _Description('String');
    if (const {
      'String',
      'int',
      'double',
      'bool',
      'List',
      'Map',
    }.contains(name)) {
      if (name == 'List' || name == 'Map') {
        final arguments = (type as InterfaceType).typeArguments;
        if (arguments.any((argument) => argument.element is ClassElement)) {
          throw InvalidGenerationSourceError(
            'Field ${field.name} uses a collection of objects; direct nested '
            'objects are supported, but nested collections are not.',
            element: field,
          );
        }
      }
      return _Description(name);
    }
    throw InvalidGenerationSourceError(
      'Field ${field.name} has unsupported serialized type $name. '
      'Add @SchemaSerializedType with the JSON type.',
      element: field,
    );
  }

  int _enumRename(EnumElement element) {
    final annotation = _jsonSerializable.firstAnnotationOf(element);
    return annotation
            ?.getField('fieldRename')
            ?.getField('index')
            ?.toIntValue() ??
        0;
  }

  bool _hasConstructorDefault(FieldElement field) {
    final owner = field.enclosingElement;
    if (owner is! ClassElement) return false;
    final constructor = owner.constructors
        .where((item) => item.name?.isEmpty ?? false)
        .firstOrNull;
    final parameter = constructor?.formalParameters
        .where((item) => item.name == field.name)
        .firstOrNull;
    return parameter?.defaultValueCode != null;
  }

  String? _contextValue(
    ClassElement element,
    Iterable<DartObject> combined,
    String combinedName,
    TypeChecker separateChecker,
    String separateName,
  ) {
    final combinedValues = combined
        .map((annotation) => annotation.getField(combinedName)?.toStringValue())
        .whereType<String>()
        .toSet();
    final separateValues = separateChecker
        .annotationsOf(element)
        .map((annotation) => annotation.getField(separateName)?.toStringValue())
        .whereType<String>()
        .toSet();
    if (combinedValues.length > 1 || separateValues.length > 1) {
      throw InvalidGenerationSourceError(
        '${element.name} declares conflicting $combinedName annotations.',
        element: element,
      );
    }
    final combinedValue = combinedValues.firstOrNull;
    final separateValue = separateValues.firstOrNull;
    if (combinedValue != null &&
        separateValue != null &&
        combinedValue != separateValue) {
      throw InvalidGenerationSourceError(
        '${element.name} has conflicting $combinedName values between '
        '@SchemaContract and the separate schema annotation.',
        element: element,
      );
    }
    return combinedValue ?? separateValue;
  }

  String _rename(String name, int rename) => switch (rename) {
    1 => name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '-${match[1]!.toLowerCase()}',
    ),
    2 => name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => '_${match[1]!.toLowerCase()}',
    ),
    3 => name[0].toUpperCase() + name.substring(1),
    4 =>
      name
          .replaceAllMapped(
            RegExp(r'([A-Z])'),
            (match) => '_${match[1]!.toUpperCase()}',
          )
          .toUpperCase(),
    _ => name,
  };

  String _quote(String value) => _quoteDart(value);
}

String _fieldCode(_Field field) {
  final nested = field.nested == null
      ? ''
      : ", 'nestedFields': <String, dynamic>{${field.nested!.map((child) => "'${_quoteDart(child.name)}': ${_fieldCode(child)}").join(', ')}}";
  final enums = field.enumValues == null
      ? ''
      : ", 'enumValues': <String>[${field.enumValues!.map((value) => "'${_quoteDart(value)}'").join(', ')}]";
  return "<String, dynamic>{'name': '${_quoteDart(field.name)}', 'type': '${_quoteDart(field.type)}', 'required': ${field.required}, 'nullable': ${field.nullable}$nested$enums}";
}

String _quoteDart(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');

class _Model {
  const _Model(
    this.name,
    this.version,
    this.product,
    this.endpoint,
    this.fields,
  );
  final String name;
  String get constantName =>
      '${name[0].toLowerCase()}${name.substring(1)}SchemaMetadata';
  final String version;
  final String product;
  final String endpoint;
  final List<_Field> fields;
}

class _Field {
  const _Field(
    this.name,
    this.type,
    this.required,
    this.nullable, [
    this.nested,
    this.enumValues,
  ]);
  final String name;
  final String type;
  final bool required;
  final bool nullable;
  final List<_Field>? nested;
  final List<String>? enumValues;
}

class _Description {
  const _Description(this.type, {this.nested, this.enums});
  final String type;
  final List<_Field>? nested;
  final List<String>? enums;
}
