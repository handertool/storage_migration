import 'package:schema_guard/schema_guard.dart';
import 'package:test/test.dart';

SchemaContract contract({
  String version = 'v1',
  Map<String, SchemaField>? fields,
}) => SchemaContract(
  version: version,
  product: 'consumer',
  endpoint: '/profile',
  fields:
      fields ??
      {
        'id': const SchemaField(name: 'id', type: 'int', required: true),
        'name': const SchemaField(name: 'name', type: 'String', required: true),
      },
);

void main() {
  test('Given an optional addition, when schemas are compared, then it is compatible', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(),
      newSchema: contract(
        version: 'v2',
        fields: {
          ...contract().fields,
          'nickname': const SchemaField(name: 'nickname', type: 'String'),
        },
      ),
    );

    expect(report.status, CompatibilityStatus.compatible);
    expect(report.addedFields, ['nickname']);
  });

  test(
    'Given null snapshot booleans, when imported, then it fails strictly',
    () {
      for (final key in ['required', 'nullable', 'isOptional']) {
        expect(
          () => SchemaSnapshot.fromJson({
            'formatVersion': 1,
            'contract': {
              'version': 'v1',
              'product': 'consumer',
              'endpoint': '/profile',
              'fields': {
                'id': {'name': 'id', 'type': 'int', key: null},
              },
            },
          }),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );

  test('Given a missing required fixture field, when validated, then migration is needed', () {
    final report = SchemaGuard.validateFixture(
      contract: contract(),
      fixture: {'id': 42},
    );

    expect(report.status, CompatibilityStatus.needsMigration);
    expect(report.requirednessChanges, contains(contains('name')));
  });

  test('Given an optional fixture field is missing, when validated, then a warning is emitted', () {
    final report = SchemaGuard.validateFixture(
      contract: contract(
        fields: {
          ...contract().fields,
          'nickname': const SchemaField(name: 'nickname', type: 'String'),
        },
      ),
      fixture: {'id': 42, 'name': 'Alice'},
    );

    expect(report.status, CompatibilityStatus.compatible);
    expect(report.warnings, contains(contains('nickname')));
  });

  test('Given a required addition, when schemas are compared, then migration is needed', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(),
      newSchema: contract(
        version: 'v2',
        fields: {
          ...contract().fields,
          'active': const SchemaField(
            name: 'active',
            type: 'bool',
            required: true,
          ),
        },
      ),
    );

    expect(report.status, CompatibilityStatus.needsMigration);
  });

  test('Given a removal or type change, when schemas are compared, then it is breaking', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(
        fields: {
          ...contract().fields,
          'age': const SchemaField(name: 'age', type: 'int'),
        },
      ),
      newSchema: contract(
        version: 'v2',
        fields: {
          'id': const SchemaField(name: 'id', type: 'String', required: true),
        },
      ),
    );

    expect(report.status, CompatibilityStatus.breaking);
    expect(report.removedFields, contains('name'));
    expect(report.typeChanges, contains('id: int -> String'));
  });

  test('Given different context, when schemas are compared, then status is unknown', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(),
      newSchema: SchemaContract(
        version: 'v2',
        product: 'other',
        endpoint: '/profile',
        fields: contract().fields,
      ),
    );

    expect(report.status, CompatibilityStatus.unknown);
  });

  test('Given nested and enum changes, when schemas are compared, then paths are reported', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(
        fields: {
          ...contract().fields,
          'role': const SchemaField(
            name: 'role',
            type: 'String',
            enumValues: ['user', 'admin'],
          ),
          'address': const SchemaField(
            name: 'address',
            type: 'Map',
            nestedFields: {'city': SchemaField(name: 'city', type: 'String')},
          ),
        },
      ),
      newSchema: contract(
        version: 'v2',
        fields: {
          ...contract().fields,
          'role': const SchemaField(
            name: 'role',
            type: 'String',
            enumValues: ['user'],
          ),
          'address': const SchemaField(
            name: 'address',
            type: 'Map',
            nestedFields: {
              'city': SchemaField(name: 'city', type: 'String'),
              'country': SchemaField(name: 'country', type: 'String'),
            },
          ),
        },
      ),
    );

    expect(report.status, CompatibilityStatus.breaking);
    expect(report.typeChanges, contains('role removed enum values: admin'));
    expect(report.addedFields, contains('address.country'));
  });

  test('Given nested field metadata, when schemas are compared, then map keys define paths', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(
        fields: {
          ...contract().fields,
          'address': const SchemaField(
            name: 'address',
            type: 'Map',
            nestedFields: {},
          ),
        },
      ),
      newSchema: contract(
        version: 'v2',
        fields: {
          ...contract().fields,
          'address': const SchemaField(
            name: 'address',
            type: 'Map',
            nestedFields: {
              'postalCode': SchemaField(
                name: 'zip',
                type: 'String',
                required: true,
              ),
            },
          ),
        },
      ),
    );

    expect(
      report.requirednessChanges,
      contains('address.postalCode was added as required'),
    );
  });

  test('Given a new enum restriction, when schemas are compared, then it is breaking', () {
    final report = SchemaGuard.compareSchemas(
      oldSchema: contract(
        fields: {
          ...contract().fields,
          'role': const SchemaField(name: 'role', type: 'String'),
        },
      ),
      newSchema: contract(
        version: 'v2',
        fields: {
          ...contract().fields,
          'role': const SchemaField(
            name: 'role',
            type: 'String',
            enumValues: ['user'],
          ),
        },
      ),
    );

    expect(report.status, CompatibilityStatus.breaking);
  });

  test(
    'Given invalid fixture data, when validated, then mismatches are reported',
    () {
      final report = SchemaGuard.validateFixture(
        contract: contract(
          fields: {
            'id': const SchemaField(name: 'id', type: 'int', required: true),
            'email': const SchemaField(
              name: 'email',
              type: 'String',
              nullable: true,
            ),
            'role': const SchemaField(
              name: 'role',
              type: 'String',
              enumValues: ['user'],
            ),
          },
        ),
        fixture: {'id': '42', 'email': null, 'role': 'admin', 'extra': true},
      );

      expect(report.status, CompatibilityStatus.breaking);
      expect(report.typeChanges, contains(startsWith('id has type String')));
      expect(
        report.typeChanges,
        contains(startsWith('role has unknown enum value')),
      );
      expect(report.warnings, contains(contains('extra')));
    },
  );

  test('Given nested data, when migration mutates its input, then source is unchanged', () {
    final source = {
      'profile': {'name': 'Alice'},
      'tags': ['old'],
    };
    final result = SchemaGuard.migrateStorage(
      data: source,
      migration: (data) {
        (data['profile'] as Map<String, dynamic>)['name'] = 'Bob';
        (data['tags'] as List<dynamic>).add('new');
        return data;
      },
    );

    expect(result['profile'], {'name': 'Bob'});
    expect(source['profile'], {'name': 'Alice'});
    expect(source['tags'], ['old']);
  });

  test(
    'Given a migration that throws, when run, then its error propagates',
    () {
      expect(
        () => SchemaGuard.migrateStorage(
          data: {'id': 1},
          migration: (_) => throw StateError('invalid data'),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('Given a contract, when snapshotted, then metadata round-trips', () {
    final original = contract(
      fields: {
        'role': const SchemaField(
          name: 'role',
          type: 'String',
          required: true,
          enumValues: ['user', 'admin'],
        ),
        'profile': const SchemaField(
          name: 'profile',
          type: 'Map',
          nestedFields: {
            'age': SchemaField(name: 'age', type: 'int', nullable: true),
          },
        ),
      },
    );

    final restored = SchemaSnapshot.decode(SchemaSnapshot.encode(original));

    expect(restored.toJson(), original.toJson());
  });

  test(
    'Given an unsupported snapshot, when imported, then it fails clearly',
    () {
      expect(
        () => SchemaSnapshot.fromJson({'formatVersion': 2, 'contract': {}}),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('Given non-string snapshot map keys, when imported, then it throws FormatException', () {
    final invalidSnapshots = <Map<String, dynamic>>[
      {
        'formatVersion': 1,
        'contract': {
          'version': 'v1',
          'product': 'consumer',
          'endpoint': '/profile',
          'fields': <dynamic, dynamic>{
            1: {'name': 'id', 'type': 'int'},
          },
        },
      },
      {
        'formatVersion': 1,
        'contract': {
          'version': 'v1',
          'product': 'consumer',
          'endpoint': '/profile',
          'fields': {
            'profile': {
              'name': 'profile',
              'type': 'Map',
              'nestedFields': <dynamic, dynamic>{
                1: {'name': 'id', 'type': 'int'},
              },
            },
          },
        },
      },
      {
        'formatVersion': 1,
        'contract': <dynamic, dynamic>{
          1: 'invalid',
          'version': 'v1',
          'product': 'consumer',
          'endpoint': '/profile',
          'fields': <String, dynamic>{},
        },
      },
    ];

    for (final snapshot in invalidSnapshots) {
      expect(
        () => SchemaSnapshot.fromJson(snapshot),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'Given generated contract metadata, when adapted, then it is imported',
    () {
      final original = contract();

      expect(
        SchemaContractAdapter.fromMetadata(original.toJson()).toJson(),
        original.toJson(),
      );
    },
  );

  test('Given an allowed coercion, when compared, then it is compatible', () {
    final oldSchema = contract(
      fields: {'score': const SchemaField(name: 'score', type: 'int')},
    );
    final newSchema = contract(
      version: 'v2',
      fields: {'score': const SchemaField(name: 'score', type: 'double')},
    );

    final report = SchemaGuard.compareSchemas(
      oldSchema: oldSchema,
      newSchema: newSchema,
      rules: SchemaCompatibilityRules.intToDouble,
    );

    expect(report.status, CompatibilityStatus.compatible);
    expect(report.warnings, contains(contains('safe coercion')));
  });

  test(
    'Given enum additions are allowed, when compared, then they do not break',
    () {
      final oldSchema = contract(
        fields: {
          'role': const SchemaField(
            name: 'role',
            type: 'String',
            enumValues: ['user'],
          ),
        },
      );
      final newSchema = contract(
        version: 'v2',
        fields: {
          'role': const SchemaField(
            name: 'role',
            type: 'String',
            enumValues: ['user', 'admin'],
          ),
        },
      );

      final report = SchemaGuard.compareSchemas(
        oldSchema: oldSchema,
        newSchema: newSchema,
        rules: SchemaCompatibilityRules(
          enumPolicy: EnumCompatibilityPolicy.allowAddedValues,
        ),
      );

      expect(report.status, CompatibilityStatus.compatible);
    },
  );

  test(
    'Given mutable rule input, when changed later, then rules stay stable',
    () {
      final coercions = {'int->double'};
      final rules = SchemaCompatibilityRules(safeCoercions: coercions);
      coercions.clear();

      expect(rules.allowsCoercion('int', 'double'), isTrue);
      expect(
        () => rules.safeCoercions.add('String->int'),
        throwsUnsupportedError,
      );
    },
  );
}
