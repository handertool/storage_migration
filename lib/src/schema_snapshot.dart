import 'dart:convert';

import 'schema_guard.dart';

/// Converts stable metadata emitted by model generators into a contract.
///
/// The metadata shape is the same as [SchemaContract.toJson]. This boundary
/// lets `json_serializable` projects expose a generated constant without
/// coupling this package to `build_runner` or `source_gen`.
class SchemaContractAdapter {
  /// Creates a contract from generated JSON-compatible metadata.
  static SchemaContract fromMetadata(Map<String, dynamic> metadata) =>
      SchemaSnapshot.fromContractJson(metadata);
}

/// Versioned JSON persistence for [SchemaContract] metadata.
class SchemaSnapshot {
  /// The current snapshot envelope version.
  static const formatVersion = 1;

  /// Exports a contract as a deterministic JSON-compatible map.
  static Map<String, dynamic> toJson(SchemaContract contract) => {
    'formatVersion': formatVersion,
    'contract': contract.toJson(),
  };

  /// Exports a contract as JSON text.
  static String encode(SchemaContract contract) => jsonEncode(toJson(contract));

  /// Imports a contract from a snapshot map.
  static SchemaContract fromJson(Map<String, dynamic> snapshot) {
    if (snapshot['formatVersion'] != formatVersion) {
      throw FormatException(
        'Unsupported schema snapshot format: ${snapshot['formatVersion']}',
      );
    }
    final contract = snapshot['contract'];
    if (contract is! Map) {
      throw const FormatException('Snapshot contract must be an object.');
    }
    return _contract(contract.cast<String, dynamic>());
  }

  /// Imports the contract-shaped map returned by [SchemaContract.toJson].
  static SchemaContract fromContractJson(Map<String, dynamic> value) =>
      _contract(value);

  /// Imports a contract from JSON text.
  static SchemaContract decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map) {
      throw const FormatException('Schema snapshot must be a JSON object.');
    }
    return fromJson(value.cast<String, dynamic>());
  }

  static SchemaContract _contract(Map<String, dynamic> value) {
    final version = value['version'];
    final product = value['product'];
    final endpoint = value['endpoint'];
    final fields = value['fields'];
    if (version is! String ||
        product is! String ||
        endpoint is! String ||
        fields is! Map) {
      throw const FormatException('Snapshot contract has invalid metadata.');
    }
    return SchemaContract(
      version: version,
      product: product,
      endpoint: endpoint,
      fields: _fields(fields.cast<String, dynamic>()),
    );
  }

  static Map<String, SchemaField> _fields(Map<String, dynamic> values) =>
      values.map((key, value) => MapEntry(key, _field(value, key)));

  static SchemaField _field(dynamic value, String key) {
    if (value is! Map) {
      throw FormatException('Snapshot field "$key" must be an object.');
    }
    final data = value.cast<String, dynamic>();
    final name = data['name'];
    final type = data['type'];
    if (name is! String || type is! String) {
      throw FormatException('Snapshot field "$key" has invalid name/type.');
    }
    final nested = data['nestedFields'];
    final enums = data['enumValues'];
    if (nested != null && nested is! Map) {
      throw FormatException('Snapshot field "$key" has invalid nestedFields.');
    }
    if (enums != null ||
        data['enumValues'] == null && data.containsKey('enumValues')) {
      if (enums is! List || enums.any((item) => item is! String)) {
        throw FormatException('Snapshot field "$key" has invalid enumValues.');
      }
    }
    return SchemaField(
      name: name,
      type: type,
      required: _bool(data, 'required', false),
      nullable: _bool(data, 'nullable', false),
      isOptional: _bool(data, 'isOptional', false),
      nestedFields: nested == null
          ? null
          : _fields(nested.cast<String, dynamic>()),
      enumValues: enums?.cast<String>(),
    );
  }

  static bool _bool(Map<String, dynamic> value, String key, bool fallback) {
    if (value.containsKey(key) && value[key] == null) {
      throw FormatException('Snapshot "$key" must be bool.');
    }
    final item = value[key];
    if (item == null) return fallback;
    if (item is! bool) throw FormatException('Snapshot "$key" must be bool.');
    return item;
  }
}
