## 0.1.1

* Reject malformed schema snapshots with non-string map keys using
  `FormatException`.
* Support inferred scalar lists and string-keyed maps of scalar values in the
  optional generator, with explicit serialized-type overrides taking
  precedence over Dart type inference.

## 0.1.0

* Initial release of `schema_guard`.
* Added version-aware schema comparison, fixture validation, and storage
  migration helpers.
* Added recursive field, nullability, requiredness, and enum checks.
* Added runnable API, fixture, and storage workflows.
* Added versioned schema snapshot import/export and a generator adapter
  boundary suitable for `json_serializable` metadata.
* Added configurable enum compatibility and explicit safe coercion rules.
* Added the publishable `schema_guard_generator` build-runner package for
  deterministic `json_serializable` schema metadata.
* Added the combined `SchemaContract` annotation, with conflict validation
  when separate schema annotations are also present.
