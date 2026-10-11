// ignore_for_file: avoid_print

import 'package:schema_guard/schema_guard.dart';

void main() {
  final oldSchema = SchemaContract(
    version: 'v1',
    product: 'consumer',
    endpoint: '/profile',
    fields: {
      'id': const SchemaField(name: 'id', type: 'int', required: true),
      'name': const SchemaField(name: 'name', type: 'String', required: true),
      'email': const SchemaField(
        name: 'email',
        type: 'String',
        required: false,
        nullable: true,
      ),
    },
  );

  final newSchema = SchemaContract(
    version: 'v2',
    product: 'consumer',
    endpoint: '/profile',
    fields: {
      'id': const SchemaField(name: 'id', type: 'int', required: true),
      'name': const SchemaField(name: 'name', type: 'String', required: true),
      'email': const SchemaField(
        name: 'email',
        type: 'String',
        required: false,
        nullable: true,
      ),
      'isActive': const SchemaField(
        name: 'isActive',
        type: 'bool',
        required: false,
      ),
    },
  );

  final report = SchemaGuard.compareSchemas(
    oldSchema: oldSchema,
    newSchema: newSchema,
  );
  print('API: ${report.status.name} - ${report.summary}');

  final breakingReport = SchemaGuard.compareSchemas(
    oldSchema: newSchema,
    newSchema: SchemaContract(
      version: 'v3',
      product: 'consumer',
      endpoint: '/profile',
      fields: {
        'id': const SchemaField(name: 'id', type: 'String', required: true),
        'name': const SchemaField(name: 'name', type: 'String', required: true),
      },
    ),
  );
  print('Breaking change: ${breakingReport.status.name}');

  final fixtureReport = SchemaGuard.validateFixture(
    contract: newSchema,
    fixture: {'id': 42, 'name': 'Alice', 'email': null},
  );
  print('Fixture: ${fixtureReport.status.name}');

  final oldData = {
    'id': 42,
    'profile': {'name': 'Alice'},
  };
  final migrated = SchemaGuard.migrateStorage(
    data: oldData,
    migration: (data) {
      final profile = (data['profile'] as Map<String, dynamic>)
        ..['verified'] = true;
      return {...data, 'profile': profile, 'version': 2};
    },
  );
  print('Storage: $migrated');
}
