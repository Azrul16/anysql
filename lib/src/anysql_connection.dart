import 'anysql_result.dart';

/// An open database connection created by an [AnySqlDriver].
abstract interface class AnySqlConnection {
  /// Whether this connection can still accept queries.
  bool get isOpen;

  /// Runs a statement or command and returns a normalized result.
  ///
  /// SQL drivers generally treat [statement] as SQL. Document database drivers
  /// can define their own command naming convention, such as
  /// `collection.operation`.
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  });

  /// Runs work inside a database transaction.
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  );

  /// Closes the underlying database resources.
  Future<void> close();
}

/// A transaction scoped to one [AnySqlConnection].
abstract interface class AnySqlTransaction {
  /// Runs a statement or command within this transaction.
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  });

  /// Commits this transaction.
  Future<void> commit();

  /// Rolls this transaction back.
  Future<void> rollback();
}
