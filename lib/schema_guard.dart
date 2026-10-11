export 'src/schema_guard.dart';
export 'src/schema_snapshot.dart';

/// Declares the version represented by an annotated model.
class SchemaVersion {
  /// Creates a version annotation.
  final String value;

  const SchemaVersion(this.value);
}

/// Declares the product owning an annotated model.
class SchemaProduct {
  /// Creates a product annotation.
  final String value;

  const SchemaProduct(this.value);
}

/// Declares the endpoint or storage key of an annotated model.
class SchemaEndpoint {
  /// Creates an endpoint annotation.
  final String value;

  const SchemaEndpoint(this.value);
}

/// Marks a field as optional in generated metadata.
class OptionalField {
  /// Creates an optional-field annotation.
  const OptionalField();
}

/// Marks a field as required in generated metadata.
class RequiredField {
  /// Creates a required-field annotation.
  const RequiredField();
}

/// Overrides the serialized type used by generated schema metadata.
class SchemaSerializedType {
  /// Creates a serialized-type override.
  const SchemaSerializedType(this.value);

  /// The JSON type name emitted for the annotated field.
  final String value;
}
