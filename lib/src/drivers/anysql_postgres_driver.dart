import 'package:postgres/postgres.dart' as pg;

import '../anysql_config.dart';
import '../anysql_connection.dart';
import '../anysql_driver.dart';
import '../anysql_exception.dart';
import '../anysql_result.dart';

/// Real PostgreSQL driver backed by `package:postgres`.
///
/// This driver uses [AnySqlConfig.host], [AnySqlConfig.port],
/// [AnySqlConfig.database], [AnySqlConfig.username], [AnySqlConfig.password],
/// and [AnySqlConfig.sslEnabled] to open a PostgreSQL connection.
final class PostgresAnySqlDriver extends AnySqlDriverBase {
  /// Creates a PostgreSQL driver.
  const PostgresAnySqlDriver() : super('postgres', AnySqlDialect.postgres);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    try {
      final connection = await pg.Connection.open(
        pg.Endpoint(
          host: config.host!,
          port: config.port ?? 5432,
          database: config.database!,
          username: config.username,
          password: config.password,
        ),
        settings: pg.ConnectionSettings(
          sslMode: config.sslEnabled ? pg.SslMode.require : pg.SslMode.disable,
        ),
      );

      return PostgresAnySqlConnection(connection);
    } on Object catch (error) {
      throw AnySqlException('Failed to connect to PostgreSQL.', error);
    }
  }
}

/// AnySQL connection backed by a PostgreSQL connection.
///
/// Queries with parameters use `package:postgres` named SQL syntax, such as
/// `select * from users where id = @id` with `parameters: {'id': 1}`.
final class PostgresAnySqlConnection implements AnySqlConnection {
  /// Wraps an existing PostgreSQL [connection].
  PostgresAnySqlConnection(this.connection);

  /// Underlying PostgreSQL connection.
  final pg.Connection connection;

  @override
  bool get isOpen => connection.isOpen;

  @override
  Future<void> close() {
    return connection.close();
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    _checkOpen();

    try {
      final result = await connection.execute(
        parameters.isEmpty ? pg.Sql(statement) : pg.Sql.named(statement),
        parameters: parameters.isEmpty ? null : parameters,
      );

      return _postgresResult(result);
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute PostgreSQL query: ${_statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) async {
    _checkOpen();
    await connection.execute(pg.Sql('BEGIN'));
    final transaction = _PostgresAnySqlTransaction(connection);

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
    if (!connection.isOpen) {
      throw const AnySqlConnectionException('PostgreSQL connection is closed.');
    }
  }
}

final class _PostgresAnySqlTransaction implements AnySqlTransaction {
  _PostgresAnySqlTransaction(this._connection);

  final pg.Connection _connection;
  var isCompleted = false;

  @override
  Future<void> commit() async {
    if (isCompleted) {
      throw const AnySqlException('Transaction is already completed.');
    }

    await _connection.execute(pg.Sql('COMMIT'));
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
      final result = await _connection.execute(
        parameters.isEmpty ? pg.Sql(statement) : pg.Sql.named(statement),
        parameters: parameters.isEmpty ? null : parameters,
      );

      return _postgresResult(result);
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute PostgreSQL transaction query: '
        '${_statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<void> rollback() async {
    if (isCompleted) {
      throw const AnySqlException('Transaction is already completed.');
    }

    await _connection.execute(pg.Sql('ROLLBACK'));
    isCompleted = true;
  }
}

String _statementPreview(String statement) {
  final compact = statement.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= 120) {
    return compact;
  }

  return '${compact.substring(0, 117)}...';
}

AnySqlResult _postgresResult(pg.Result result) {
  return AnySqlResult.rows(
    result.map((row) => Map<String, Object?>.from(row.toColumnMap())).toList(),
    affectedRows: result.affectedRows,
    metadata: {
      'columns': result.schema.columns
          .map((column) => column.columnName)
          .whereType<String>()
          .toList(),
    },
  );
}
