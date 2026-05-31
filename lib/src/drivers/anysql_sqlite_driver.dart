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
  const SqliteAnySqlDriver() : super('sqlite', AnySqlDialect.sqlite);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    try {
      final database = config.database == ':memory:'
          ? sqlite.sqlite3.openInMemory()
          : sqlite.sqlite3.open(config.database!);

      return SqliteAnySqlConnection(database);
    } on Object catch (error) {
      throw AnySqlException('Failed to open SQLite database.', error);
    }
  }
}

/// AnySQL connection backed by a SQLite database.
///
/// Positional SQL parameters are read from `parameters['values']` when that
/// value is an iterable. Otherwise, map values are passed to SQLite in insertion
/// order.
final class SqliteAnySqlConnection implements AnySqlConnection {
  /// Wraps an existing SQLite [database].
  SqliteAnySqlConnection(this.database);

  /// Underlying SQLite database.
  final sqlite.Database database;
  var _isOpen = true;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
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
    try {
      return _sqliteQuery(database, statement, _sqliteParameters(parameters));
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute SQLite query: ${statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) async {
    _checkOpen();
    try {
      database.execute('BEGIN TRANSACTION');
    } on Object catch (error) {
      throw AnySqlQueryException('Failed to start SQLite transaction.', error);
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
  }

  void _checkOpen() {
    if (!_isOpen) {
      throw const AnySqlException('SQLite connection is closed.');
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
      throw const AnySqlException('Transaction is already completed.');
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
      throw const AnySqlException('Transaction is already completed.');
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
      throw const AnySqlException('Transaction is already completed.');
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
  final trimmed = statement.trimLeft().toLowerCase();
  if (trimmed.startsWith('select') ||
      trimmed.startsWith('with') ||
      trimmed.startsWith('pragma') ||
      _hasTopLevelReturningClause(trimmed)) {
    final result = database.select(statement, parameters);
    return AnySqlResult.rows(
      result.map((row) => Map<String, Object?>.from(row)).toList(),
      metadata: {'columns': result.columnNames},
    );
  }

  database.execute(statement, parameters);
  return AnySqlResult.command(
    affectedRows: database.updatedRows,
    lastInsertId: database.lastInsertRowId == 0
        ? null
        : database.lastInsertRowId,
  );
}

bool _hasTopLevelReturningClause(String statement) {
  var depth = 0;
  for (var index = 0; index < statement.length; index += 1) {
    final codeUnit = statement.codeUnitAt(index);

    if (codeUnit == 0x27) {
      index = _skipQuoted(statement, index, 0x27);
      continue;
    }
    if (codeUnit == 0x22) {
      index = _skipQuoted(statement, index, 0x22);
      continue;
    }
    if (codeUnit == 0x60) {
      index = _skipQuoted(statement, index, 0x60);
      continue;
    }
    if (_startsWith(statement, index, '--')) {
      index = _skipLineComment(statement, index);
      continue;
    }
    if (_startsWith(statement, index, '/*')) {
      index = _skipBlockComment(statement, index);
      continue;
    }
    if (codeUnit == 0x28) {
      depth += 1;
      continue;
    }
    if (codeUnit == 0x29 && depth > 0) {
      depth -= 1;
      continue;
    }
    if (depth == 0 && _startsWithWord(statement, index, 'returning')) {
      return true;
    }
  }

  return false;
}

int _skipQuoted(String statement, int start, int quote) {
  for (var index = start + 1; index < statement.length; index += 1) {
    if (statement.codeUnitAt(index) != quote) {
      continue;
    }
    if (index + 1 < statement.length &&
        statement.codeUnitAt(index + 1) == quote) {
      index += 1;
      continue;
    }
    return index;
  }

  return statement.length - 1;
}

int _skipLineComment(String statement, int start) {
  final newline = statement.indexOf('\n', start + 2);
  return newline == -1 ? statement.length - 1 : newline;
}

int _skipBlockComment(String statement, int start) {
  final end = statement.indexOf('*/', start + 2);
  return end == -1 ? statement.length - 1 : end + 1;
}

bool _startsWith(String statement, int index, String value) {
  return index + value.length <= statement.length &&
      statement.substring(index, index + value.length) == value;
}

bool _startsWithWord(String statement, int index, String word) {
  if (!_startsWith(statement, index, word)) {
    return false;
  }

  final before = index == 0 ? null : statement.codeUnitAt(index - 1);
  final afterIndex = index + word.length;
  final after = afterIndex >= statement.length
      ? null
      : statement.codeUnitAt(afterIndex);

  return !_isIdentifierCodeUnit(before) && !_isIdentifierCodeUnit(after);
}

bool _isIdentifierCodeUnit(int? codeUnit) {
  if (codeUnit == null) {
    return false;
  }

  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F;
}

List<Object?> _sqliteParameters(Map<String, Object?> parameters) {
  final values = parameters[AnySqlParameters.positionalValuesKey];
  if (values is Iterable<Object?>) {
    return values.toList();
  }

  return parameters.values.toList();
}
