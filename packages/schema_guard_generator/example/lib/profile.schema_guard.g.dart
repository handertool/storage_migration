// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: constant_identifier_names

part of 'profile.dart';

// **************************************************************************
// SchemaGuardGenerator
// **************************************************************************

const profileSchemaMetadata = <String, dynamic>{
  'version': 'v2',
  'product': 'consumer',
  'endpoint': '/profile',
  'fields': <String, dynamic>{
    'address': <String, dynamic>{
      'name': 'address',
      'type': 'Map',
      'required': false,
      'nullable': true,
      'nestedFields': <String, dynamic>{
        'city': <String, dynamic>{
          'name': 'city',
          'type': 'String',
          'required': true,
          'nullable': false,
        },
      },
    },
    'display_name': <String, dynamic>{
      'name': 'display_name',
      'type': 'String',
      'required': false,
      'nullable': true,
    },
    'id': <String, dynamic>{
      'name': 'id',
      'type': 'int',
      'required': true,
      'nullable': false,
    },
  },
};
