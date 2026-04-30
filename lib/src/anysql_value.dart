/// Sentinel used by copy helpers to distinguish "not provided" from `null`.
final class AnySqlValue<T> {
  const AnySqlValue(this.value);

  final T value;
}
