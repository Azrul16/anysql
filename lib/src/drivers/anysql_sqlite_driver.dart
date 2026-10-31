import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../anysql_config.dart';
import '../anysql_connection.dart';
import '../anysql_driver.dart';
import '../anysql_exception.dart';
import '../anysql_parameters.dart';
import '../anysql_result.dart';
import 'driver_helpers.dart';

/// Real SQLite driver backed by `package:sqlite3`.
///
/// Use this driver for local Dart storage, command-line tools, tests, or
/// Flutter targets where `package:sqlite3` is supported. Pass `:memory:` as
/// the database path to create an in-memory database.
final class SqliteAnySqlDriver extends AnySqlDriverBase {
  /// Creates a SQLite driver.
  const SqliteAnySqlDriver()
    : super(
        'sqlite',
        AnySqlDialect.sqlite,
        capabilities: const AnySqlCapabilities(
          transactions: true,
          returningRows: true,
          upsert: true,
        ),
      );

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    try {
      final database = config.database == ':memory:'
          ? sqlite.sqlite3.openInMemory()
          : sqlite.sqlite3.open(config.database!);

      return SqliteAnySqlConnection(database);
    } on Object catch (error) {
      throw AnySqlConnectionException('Failed to open SQLite database.', error);
    }
  }
}

/// AnySQL connection backed by a SQLite database.
///
/// Positional SQL parameters are read from `parameters['values']` when that
/// value is an iterable. Otherwise, map values are passed to SQLite in insertion
/// order. Each query accepts one prepared statement. Read-only statements
/// report zero affected rows; writes include affected counts even with RETURNING.
/// Prefer RETURNING for identifiers: lastInsertId is set when SQLite's most
/// recent insert row ID changes.
final class SqliteAnySqlConnection implements AnySqlConnection {
  /// Wraps an existing SQLite [database].
  SqliteAnySqlConnection(this.database);

  /// Underlying SQLite database.
  final sqlite.Database database;
  var _isOpen = true;

  final _guard = ConnectionOperationGuard();

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _guard.checkIdle();
    if (_isOpen) {
      database.close();
      _isOpen = false;
    }
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    _checkOpen();
    _guard.startQuery();
    try {
      return _sqliteQuery(database, statement, _sqliteParameters(parameters));
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute SQLite query: ${statementPreview(statement)}',
        error,
      );
    } finally {
      _guard.endQuery();
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) async {
    _checkOpen();
    _guard.startTransaction();
    try {
      try {
        database.execute('BEGIN TRANSACTION');
      } on Object catch (error) {
        throw AnySqlQueryException(
          'Failed to start SQLite transaction.',
          error,
        );
      }
      final transaction = _SqliteAnySqlTransaction(database);

      try {
        final value = await action(transaction);
        if (!transaction.isCompleted) {
          await transaction.commit();
        }
        return value;
      } catch (_) {
        if (!transaction.isCompleted) {
          await transaction.rollback();
        }
        rethrow;
      }
    } finally {
      _guard.endTransaction();
    }
  }

  void _checkOpen() {
    if (!_isOpen) {
      throw const AnySqlConnectionException('SQLite connection is closed.');
    }
  }
}

final class _SqliteAnySqlTransaction implements AnySqlTransaction {
  _SqliteAnySqlTransaction(this._database);

  final sqlite.Database _database;
  var isCompleted = false;

  @override
  Future<void> commit() async {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    _database.execute('COMMIT');
    isCompleted = true;
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    try {
      return _sqliteQuery(_database, statement, _sqliteParameters(parameters));
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute SQLite transaction query: '
        '${statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<void> rollback() async {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    _database.execute('ROLLBACK');
    isCompleted = true;
  }
}

AnySqlResult _sqliteQuery(
  sqlite.Database database,
  String statement,
  List<Object?> parameters,
) {
  final prepared = database.prepare(statement, checkNoTail: true);
  try {
    final readOnly = prepared.isReadOnly;
    final changesBefore =
        database.select('select total_changes()').first.values.first as int;
    final insertIdBefore = database.lastInsertRowId;
    final result = prepared.select(parameters);
    final changesAfter =
        database.select('select total_changes()').first.values.first as int;
    final affectedRows = !readOnly && changesAfter > changesBefore
        ? database.updatedRows
        : 0;
    final insertId = database.lastInsertRowId;
    return AnySqlResult(
      rows: result.map((row) => Map<String, Object?>.from(row)).toList(),
      affectedRows: affectedRows,
      lastInsertId: !readOnly && insertId != insertIdBefore ? insertId : null,
      metadata: result.columnNames.isEmpty
          ? const {}
          : {'columns': result.columnNames},
    );
  } finally {
    prepared.close();
  }
}

List<Object?> _sqliteParameters(Map<String, Object?> parameters) {
  final values = parameters[AnySqlParameters.positionalValuesKey];
  if (values is Iterable<Object?>) {
    return values.toList();
  }

  return parameters.values.toList();
}
