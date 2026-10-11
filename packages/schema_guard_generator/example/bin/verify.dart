import 'package:schema_guard/schema_guard.dart';
import 'package:schema_guard_generator_example/profile.dart';

void main() {
  final contract = SchemaContractAdapter.fromMetadata(profileSchemaMetadata);
  if (contract.version != 'v2' ||
      contract.product != 'consumer' ||
      contract.endpoint != '/profile' ||
      contract.fields['display_name']?.nullable != true ||
      contract.fields['address']?.nestedFields?['city']?.type != 'String') {
    throw StateError('Generated schema metadata does not match Profile.');
  }
}
