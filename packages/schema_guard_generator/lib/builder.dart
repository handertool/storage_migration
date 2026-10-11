import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/schema_guard_generator.dart';

/// Creates the schema metadata builder.
Builder schemaGuardBuilder(BuilderOptions options) => PartBuilder(
  [SchemaGuardGenerator()],
  '.schema_guard.g.dart',
  header:
      '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
      '// ignore_for_file: constant_identifier_names\n',
);
