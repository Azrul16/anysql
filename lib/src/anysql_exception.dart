/// Exception thrown by AnySQL drivers and connection helpers.
base class AnySqlException implements Exception {
  /// Creates an exception with a human-readable [message] and optional [cause].
  const AnySqlException(this.message, [this.cause]);

  /// Human-readable description of what failed.
  final String message;

  /// Original error or context from the underlying driver, when available.
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return '$runtimeType: $message';
    }

    return '$runtimeType: $message ($cause)';
  }
}

/// Exception thrown when database configuration is invalid or incomplete.
final class AnySqlConfigException extends AnySqlException {
  /// Creates a config exception.
  const AnySqlConfigException(super.message, [super.cause]);
}

/// Exception thrown when a driver cannot be selected or opened.
final class AnySqlDriverException extends AnySqlException {
  /// Creates a driver exception.
  const AnySqlDriverException(super.message, [super.cause]);
}

/// Exception thrown when an operation is attempted on an unusable connection.
final class AnySqlConnectionException extends AnySqlException {
  /// Creates a connection exception.
  const AnySqlConnectionException(super.message, [super.cause]);
}

/// Exception thrown when a query or command cannot be executed.
final class AnySqlQueryException extends AnySqlException {
  /// Creates a query exception.
  const AnySqlQueryException(super.message, [super.cause]);
}
