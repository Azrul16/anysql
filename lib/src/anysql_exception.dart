/// Exception thrown by AnySQL drivers and connection helpers.
final class AnySqlException implements Exception {
  const AnySqlException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'AnySqlException: $message';
    }

    return 'AnySqlException: $message ($cause)';
  }
}
