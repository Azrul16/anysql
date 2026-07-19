import 'package:mysql_client/mysql_client.dart' as mysql;

import '../anysql_config.dart';
import '../anysql_connection.dart';
import '../anysql_driver.dart';
import '../anysql_exception.dart';
import '../anysql_result.dart';
import 'driver_helpers.dart';

/// Real MySQL driver backed by `package:mysql_client`.
///
/// Supported driver-specific [AnySqlConfig.options] keys are `collation` for a
/// MySQL collation string and `timeoutMs` for the connection timeout in
/// milliseconds.
final class MysqlAnySqlDriver extends AnySqlDriverBase {
  /// Creates a MySQL driver.
  const MysqlAnySqlDriver()
    : super(
        'mysql',
        AnySqlDialect.mysql,
        capabilities: const AnySqlCapabilities(
          transactions: true,
          upsert: true,
        ),
      );

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    final collation = _stringOption(
      config,
      'collation',
      defaultValue: 'utf8mb4_general_ci',
    );
    final timeoutMs = _intOption(config, 'timeoutMs', defaultValue: 10000);

    try {
      final connection = await mysql.MySQLConnection.createConnection(
        host: config.host!,
        port: config.port ?? 3306,
        userName: config.username ?? '',
        password: config.password ?? '',
        secure: config.sslEnabled,
        databaseName: config.database,
        collation: collation,
      );
      await connection.connect(timeoutMs: timeoutMs);

      return MysqlAnySqlConnection(connection);
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlConnectionException('Failed to connect to MySQL.', error);
    }
  }
}

String _stringOption(
  AnySqlConfig config,
  String key, {
  required String defaultValue,
}) {
  final value = config.options[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw AnySqlConfigException(
    'MySQL option "$key" must be a non-empty string.',
  );
}

int _intOption(AnySqlConfig config, String key, {required int defaultValue}) {
  final value = config.options[key];
  if (value == null) {
    return defaultValue;
  }
  if (value is int && value > 0) {
    return value;
  }

  throw AnySqlConfigException(
    'MySQL option "$key" must be a positive integer.',
  );
}

/// AnySQL connection backed by a MySQL connection.
///
/// Query parameter handling follows `package:mysql_client` behavior. Values are
/// forwarded as a `Map<String, dynamic>` when parameters are provided.
final class MysqlAnySqlConnection implements AnySqlConnection {
  /// Wraps an existing MySQL [connection].
  MysqlAnySqlConnection(this.connection);

  /// Underlying MySQL connection.
  final mysql.MySQLConnection connection;

  @override
  bool get isOpen => connection.connected;

  @override
  Future<void> close() async {
    if (connection.connected) {
      await connection.close();
    }
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    _checkOpen();

    try {
      final result = await connection.execute(
        statement,
        parameters.isEmpty ? null : Map<String, dynamic>.from(parameters),
      );

      return _mysqlResult(result);
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute MySQL query: ${statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) async {
    _checkOpen();
    await connection.execute('START TRANSACTION');
    final transaction = _MysqlAnySqlTransaction(connection);

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
    if (!connection.connected) {
      throw const AnySqlConnectionException('MySQL connection is closed.');
    }
  }
}

final class _MysqlAnySqlTransaction implements AnySqlTransaction {
  _MysqlAnySqlTransaction(this._connection);

  final mysql.MySQLConnection _connection;
  var isCompleted = false;

  @override
  Future<void> commit() async {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    await _connection.execute('COMMIT');
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
      final result = await _connection.execute(
        statement,
        parameters.isEmpty ? null : Map<String, dynamic>.from(parameters),
      );

      return _mysqlResult(result);
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute MySQL transaction query: '
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

    await _connection.execute('ROLLBACK');
    isCompleted = true;
  }
}

AnySqlResult _mysqlResult(mysql.IResultSet result) {
  final columns = result.cols.map((column) => column.name).toList();
  final rows = result.rows.map((row) {
    return {
      for (var index = 0; index < columns.length; index += 1)
        columns[index]: row.colAt(index),
    };
  }).toList();

  return AnySqlResult.rows(
    rows,
    affectedRows: result.affectedRows.toInt(),
    lastInsertId: result.lastInsertID == BigInt.zero
        ? null
        : result.lastInsertID.toInt(),
    metadata: {'columns': columns},
  );
}
