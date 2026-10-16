## 0.1.1

* Honor `SchemaSerializedType` overrides before inferring Dart field types.
* Infer lists of JSON scalar values and string-keyed maps of scalar values;
  reject dynamic, object-valued, and nested collections.

## 0.1.0

* Initial build-runner/source-gen integration for schema_guard metadata.
* Added preferred combined `SchemaContract` annotation support with conflict
  validation against separate schema annotations.
