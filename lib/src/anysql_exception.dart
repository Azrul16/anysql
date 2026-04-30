/// Exception thrown by AnySQL drivers and connection helpers.
final class AnySqlException implements Exception {
  /// Creates an exception with a human-readable [message] and optional [cause].
  const AnySqlException(this.message, [this.cause]);

  /// Human-readable description of what failed.
  final String message;

  /// Original error or context from the underlying driver, when available.
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return 'AnySqlException: $message';
    }

    return 'AnySqlException: $message ($cause)';
  }
}
