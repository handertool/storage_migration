# schema_guard_generator

`schema_guard_generator` is the optional `build_runner` integration for
[`schema_guard`](https://pub.dev/packages/schema_guard). It reads
`json_serializable` models annotated with the preferred combined
`SchemaContract(version: ..., product: ..., endpoint: ...)`, then emits one
deterministic `<lowerCamelCaseModelName>SchemaMetadata` constant per model. For
example, `Profile` produces `profileSchemaMetadata`.

The separate `SchemaVersion`, `SchemaProduct`, and `SchemaEndpoint` annotations
are also supported. Models may use both forms, but conflicting values fail
generation; matching values are accepted.

Direct nested objects are supported. Nested collections and maps, custom
converters, and one-directional fields require an explicit
`SchemaSerializedType` override or are rejected to avoid unsafe inference.

## Install

```yaml
dependencies:
  json_annotation: ^4.12.0
  schema_guard: ^0.1.0

dev_dependencies:
  build_runner: ^2.16.0
  json_serializable: ^6.14.0
  schema_guard_generator: ^0.1.0
```

Add the generated part to an annotated `json_serializable` model:

```dart
part 'profile.schema_guard.g.dart';

@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')
class Profile {
  // ...
}
```

Then generate the metadata and adapt it into a runtime contract:

```bash
dart run build_runner build
```

```dart
final contract = SchemaContractAdapter.fromMetadata(profileSchemaMetadata);
```
