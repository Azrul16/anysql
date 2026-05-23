/// Helpers for building query parameter maps for different driver styles.
final class AnySqlParameters {
  const AnySqlParameters._();

  /// Reserved key used by the SQLite driver for positional parameters.
  static const positionalValuesKey = 'values';

  /// Creates a named parameter map for drivers such as PostgreSQL and MySQL.
  static Map<String, Object?> named(Map<String, Object?> values) {
    return Map.unmodifiable(values);
  }

  /// Creates positional parameters for SQLite statements with `?` placeholders.
  static Map<String, Object?> positional(Iterable<Object?> values) {
    return {positionalValuesKey: List<Object?>.unmodifiable(values)};
  }

  /// Creates document-style parameters for MongoDB operations.
  static Map<String, Object?> document(Map<String, Object?> values) {
    return Map.unmodifiable(values);
  }
}
