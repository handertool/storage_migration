# schema_guard

Find breaking API and local-storage JSON changes before they reach users.

`schema_guard` compares a previous data contract with the current contract,
checks real JSON fixtures from older versions, and verifies that storage
migrations produce data the current app can read.

It does not run an old application. Instead, it keeps the important parts of
the old application reproducible:

- versioned schema contracts
- anonymized API and storage fixtures
- explicit migration functions

## Packages

### `schema_guard`

The lightweight runtime and test API:

- compare schema versions
- detect added, removed, and type-changed fields
- check nullability, requiredness, nested fields, and enums
- validate historical JSON fixtures
- test storage migration functions
- import and export schema snapshots

### `schema_guard_generator`

The optional `build_runner` integration for applications using
`json_serializable`. It generates contract metadata from annotated Dart models,
so users do not have to manually describe every field.

## Installation

For manual contracts or fixture tests:

```yaml
dev_dependencies:
  schema_guard: ^0.1.1
```

For `json_serializable` model generation:

```yaml
dependencies:
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.16.0
  json_serializable: ^6.14.0
  schema_guard: ^0.1.1
  schema_guard_generator: ^0.1.1
```

## How compatibility checking works

1. Keep a contract or snapshot for each supported older version.
2. Define or generate the contract for the current version.
3. Compare only versions that are still active in production.
4. Validate representative old JSON fixtures against the current contract.
5. Run storage migrations against old persisted JSON.
6. Fail CI when a change is breaking or requires an untested migration.

Retired versions do not need to remain in the compatibility matrix.
Contracts are scoped by `version`, `product`, and `endpoint` or storage key, so
different products can safely use different shapes for the same endpoint.

## Manual contracts

When you do not use `json_serializable`, create contracts directly:

```dart
import 'package:schema_guard/schema_guard.dart';

final userV1 = SchemaContract(
  version: 'v1',
  product: 'consumer',
  endpoint: '/user',
  fields: {
    'id': SchemaField(
      name: 'id',
      type: 'int',
      required: true,
    ),
    'name': SchemaField(
      name: 'name',
      type: 'String',
      required: true,
    ),
  },
);

final userV2 = SchemaContract(
  version: 'v2',
  product: 'consumer',
  endpoint: '/user',
  fields: {
    'id': SchemaField(
      name: 'id',
      type: 'int',
      required: true,
    ),
    'name': SchemaField(
      name: 'name',
      type: 'String',
      required: true,
    ),
    'isActive': SchemaField(
      name: 'isActive',
      type: 'bool',
    ),
  },
);

final report = SchemaGuard.compareSchemas(
  oldSchema: userV1,
  newSchema: userV2,
);

print(report.status); // CompatibilityStatus.compatible
print(report.summary);
```

Adding an optional field is compatible. Removing a field or changing its type
is breaking. Requiredness changes generally require a migration or default.
When the available metadata is insufficient, the result is `unknown` rather
than an unsafe success.

## `json_serializable` integration

Annotate the root model with one combined contract annotation:

```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:schema_guard/schema_guard.dart';

part 'profile.g.dart';
part 'profile.schema_guard.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
@SchemaContract(
  version: 'v2',
  product: 'consumer',
  endpoint: '/profile',
)
class Profile {
  const Profile({
    required this.id,
    this.displayName,
  });

  final int id;
  final String? displayName;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}
```

Generate both serialization and schema metadata:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generator creates a deterministic `profileSchemaMetadata` constant in
`profile.schema_guard.g.dart`. Convert it into a runtime contract:

```dart
final currentContract = SchemaContractAdapter.fromMetadata(
  profileSchemaMetadata,
);
```

The generated field names follow the JSON names, including `fieldRename` and
`@JsonKey(name: ...)`. Direct nested objects, scalar JSON lists, and
string-keyed maps of scalar values are supported. Nested objects inside lists
or maps must currently be handled manually unless their serialized type is
declared explicitly.

For custom JSON converters, declare the serialized type explicitly:

```dart
@SchemaSerializedType('String')
@JsonKey(fromJson: parseDate, toJson: formatDate)
final DateTime createdAt;
```

## Validate historical JSON

Keep anonymized payloads from supported versions in your repository:

```text
test/fixtures/
  api/consumer/profile/v1.json
  api/consumer/profile/v2.json
  storage/user/v1.json
  storage/user/v1_to_v2.json
```

Validate a fixture before releasing:

```dart
final report = SchemaGuard.validateFixture(
  contract: currentContract,
  fixture: {
    'id': 42,
    'display_name': 'Alice',
  },
);

if (report.isBreaking) {
  throw StateError(report.summary);
}
```

## Test a storage migration

```dart
final migrated = SchemaGuard.migrateStorage(
  data: {
    'id': 42,
    'name': 'Alice',
  },
  migration: (data) {
    return {
      ...data,
      'isActive': true,
    };
  },
);
```

The helper passes a defensive copy to the migration and propagates errors.
Validate the migrated result against the current storage contract.

## Compatibility results

- `compatible`: the change can be consumed without migration
- `needsMigration`: a default, transform, or fallback is required
- `breaking`: existing consumers or data are no longer safe
- `unknown`: the available contract information is inconclusive

## Schema snapshots

Contracts can be stored as versioned JSON:

```dart
final snapshot = SchemaSnapshot.encode(currentContract);
final restored = SchemaSnapshot.decode(snapshot);
```

This allows compatibility checks without keeping old application source code.

## Run the example

The repository includes a complete API comparison, fixture validation, and
storage migration example:

```bash
dart run example/main.dart
```

## License

MIT
