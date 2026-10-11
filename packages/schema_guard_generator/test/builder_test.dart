import 'package:build/build.dart';
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
}
