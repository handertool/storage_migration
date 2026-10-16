import 'dart:io' show Directory;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:package_config/package_config.dart' show findPackageConfig;
import 'package:schema_guard/schema_guard.dart';
import 'package:schema_guard_generator/builder.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given the default builder, when configured, then it writes schema parts',
    () {
      final builder = schemaGuardBuilder(BuilderOptions.empty);

      expect(builder.buildExtensions, {
        '.dart': ['.schema_guard.g.dart'],
      });
    },
  );

  test('Given a combined contract annotation, when constructed, then all context is retained', () {
    const annotation = SchemaContract(
      version: 'v2',
      product: 'consumer',
      endpoint: '/profile',
    );

    expect(annotation.version, 'v2');
    expect(annotation.product, 'consumer');
    expect(annotation.endpoint, '/profile');
  });

  test(
    'Given combined-only context, when generated, then metadata is emitted',
    () async {
      await _expectGenerated(
        _source(
          "@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')",
        ),
        contains("'version': 'v2'"),
      );
    },
  );

  test(
    'Given legacy-only context, when generated, then metadata is emitted',
    () async {
      await _expectGenerated(
        _source(
          "@SchemaVersion('v2')\n"
          "@SchemaProduct('consumer')\n"
          "@SchemaEndpoint('/profile')",
        ),
        contains("'endpoint': '/profile'"),
      );
    },
  );

  test(
    'Given matching context forms, when generated, then metadata is emitted',
    () async {
      await _expectGenerated(
        _source(
          "@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')\n"
          "@SchemaVersion('v2')\n"
          "@SchemaProduct('consumer')\n"
          "@SchemaEndpoint('/profile')",
        ),
        contains("'product': 'consumer'"),
      );
    },
  );

  for (final conflict in {
    'version': "@SchemaVersion('v3')",
    'product': "@SchemaProduct('other')",
    'endpoint': "@SchemaEndpoint('/other')",
  }.entries) {
    test(
      'Given conflicting ${conflict.key}, when generated, then it fails',
      () async {
        final result = await _generate(
          _source(
            "@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')\n"
            '${conflict.value}',
          ),
        );
        expect(result.succeeded, isFalse);
        expect(
          result.errors.join('\n'),
          contains('conflicting ${conflict.key}'),
        );
      },
    );
  }

  test('Given scalar collections and an explicit override, when generated, then metadata is preserved', () async {
    await _expectGenerated(
      _source(
        "@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')",
        fields: '''
  const Model({this.names = const [], this.scores = const {}, this.payload = const CustomPayload()});

  final List<String> names;
  final Map<String, int> scores;
  @SchemaSerializedType('Map')
  final CustomPayload payload;
''',
        extraTypes: 'class CustomPayload { const CustomPayload(); }',
      ),
      allOf(
        contains("'names': <String, dynamic>{"),
        contains("'type': 'List'"),
        contains("'scores': <String, dynamic>{"),
        contains("'type': 'Map'"),
        contains("'payload': <String, dynamic>{"),
      ),
    );
  });

  for (final collectionType in [
    'List<CustomPayload>',
    'Map<String, CustomPayload>',
    'List<List<int>>',
    'List<dynamic>',
    'Map<String, dynamic>',
    'Map<int, String>',
  ]) {
    test(
      'Given $collectionType, when generated, then inference fails clearly',
      () async {
        final result = await _generate(
          _source(
            "@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')",
            fields:
                '''
  const Model({required this.value});

  final $collectionType value;
''',
            extraTypes: 'class CustomPayload { const CustomPayload(); }',
          ),
        );
        expect(result.succeeded, isFalse);
        expect(
          result.errors.join('\n'),
          contains('not a scalar list or a string-keyed scalar map'),
        );
      },
    );
  }
}

Future<void> _expectGenerated(String source, Matcher output) async {
  final readerWriter = TestReaderWriter(rootPackage: 'schema_guard_generator');
  await readerWriter.testing.loadIsolateSources();
  await testBuilder(
    schemaGuardBuilder(BuilderOptions.empty),
    {'schema_guard_generator|lib/model.dart': source},
    outputs: {
      'schema_guard_generator|lib/model.schema_guard.g.dart': decodedMatches(
        output,
      ),
    },
    packageConfig: await findPackageConfig(Directory.current),
    readerWriter: readerWriter,
  );
}

Future<TestBuilderResult> _generate(String source) async {
  final readerWriter = TestReaderWriter(rootPackage: 'schema_guard_generator');
  await readerWriter.testing.loadIsolateSources();
  return testBuilder(
    schemaGuardBuilder(BuilderOptions.empty),
    {'schema_guard_generator|lib/model.dart': source},
    packageConfig: await findPackageConfig(Directory.current),
    readerWriter: readerWriter,
  );
}

String _source(
  String annotations, {
  String fields = '  const Model();',
  String extraTypes = '',
}) =>
    '''
import 'package:json_annotation/json_annotation.dart';
import 'package:schema_guard/schema_guard.dart';

part 'model.schema_guard.g.dart';

$annotations
@JsonSerializable()
class Model {
$fields
}

$extraTypes
''';
