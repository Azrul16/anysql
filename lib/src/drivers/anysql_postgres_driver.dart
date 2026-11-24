import 'dart:io';

import 'package:postgres/postgres.dart' as pg;

import '../anysql_config.dart';
import '../anysql_connection.dart';
import '../anysql_driver.dart';
import '../anysql_exception.dart';
import '../anysql_result.dart';
import 'driver_helpers.dart';

/// Real PostgreSQL driver backed by `package:postgres`.
///
/// This driver uses [AnySqlConfig.host], [AnySqlConfig.port],
/// [AnySqlConfig.database], [AnySqlConfig.username], [AnySqlConfig.password],
/// and [AnySqlConfig.sslEnabled] to open a PostgreSQL connection.
/// Set the `securityContext` driver option to trust a private certificate authority.
final class PostgresAnySqlDriver extends AnySqlDriverBase {
  /// Creates a PostgreSQL driver.
  const PostgresAnySqlDriver()
    : super(
        'postgres',
        AnySqlDialect.postgres,
        capabilities: const AnySqlCapabilities(
          transactions: true,
          returningRows: true,
          upsert: true,
        ),
      );

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);
    final securityContext = config.options['securityContext'];
    if (securityContext != null && securityContext is! SecurityContext) {
      throw const AnySqlConfigException(
        'PostgreSQL option "securityContext" must be a SecurityContext.',
      );
    }

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
          sslMode: config.sslEnabled
              ? pg.SslMode.verifyFull
              : pg.SslMode.disable,
          securityContext: securityContext as SecurityContext?,
        ),
      );

      return PostgresAnySqlConnection(connection);
    } on Object catch (error) {
      throw AnySqlConnectionException(
        'Failed to connect to PostgreSQL.',
        error,
      );
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

  final _guard = ConnectionOperationGuard();

  @override
  bool get isOpen => connection.isOpen;

  @override
  Future<void> close() async {
    _guard.checkIdle();
    await connection.close();
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    _checkOpen();
    _guard.startQuery();

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
        'Failed to execute PostgreSQL query: ${statementPreview(statement)}',
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
    } finally {
      _guard.endTransaction();
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
  (AnySqlQueryException, StackTrace)? _serverFailure;

  @override
  Future<void> commit() async {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    final failure = _serverFailure;
    if (failure != null) {
      // A failed statement can abort the whole transaction. Check it before
      // COMMIT, which would otherwise silently roll back the writes.
      try {
        await _connection.execute(pg.Sql('SELECT 1'));
      } on pg.ServerException catch (error) {
        if (error.code == '25P02') {
          Error.throwWithStackTrace(failure.$1, failure.$2);
        }
        rethrow;
      }
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
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    try {
      final result = await _connection.execute(
        parameters.isEmpty ? pg.Sql(statement) : pg.Sql.named(statement),
        parameters: parameters.isEmpty ? null : parameters,
      );

      return _postgresResult(result);
    } on AnySqlException {
      rethrow;
    } on Object catch (error, stack) {
      final wrapped = AnySqlQueryException(
        'Failed to execute PostgreSQL transaction query: '
        '${statementPreview(statement)}',
        error,
      );
      if (error is pg.ServerException) {
        _serverFailure ??= (wrapped, stack);
      }
      Error.throwWithStackTrace(wrapped, stack);
    }
  }

  @override
  Future<void> rollback() async {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }

    await _connection.execute(pg.Sql('ROLLBACK'));
    isCompleted = true;
  }
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
