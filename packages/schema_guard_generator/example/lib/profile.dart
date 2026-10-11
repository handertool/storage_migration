import 'package:json_annotation/json_annotation.dart';
import 'package:schema_guard/schema_guard.dart';

part 'profile.g.dart';
part 'profile.schema_guard.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
@SchemaContract(version: 'v2', product: 'consumer', endpoint: '/profile')
@SchemaVersion('v2')
@SchemaProduct('consumer')
@SchemaEndpoint('/profile')
class Profile {
  const Profile({required this.id, this.displayName, this.address});

  final int id;
  final String? displayName;
  final Address? address;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}

@JsonSerializable()
class Address {
  const Address(this.city);

  final String city;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
  Map<String, dynamic> toJson() => _$AddressToJson(this);
}
