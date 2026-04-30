/// Sentinel used by copy helpers to distinguish "not provided" from `null`.
final class AnySqlValue<T> {
  /// Wraps a value that should be applied by a copy helper.
  const AnySqlValue(this.value);

  /// Wrapped value, including `null` when the target should be cleared.
  final T value;
}
