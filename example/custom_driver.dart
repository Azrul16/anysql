import 'package:anysql/anysql.dart';

Future<void> main() async {
  final client = AnySql([const ExamplePostgresDriver()]);
  final connection = await client.open(
    AnySqlConfig.postgres(host: 'localhost', database: 'app'),
  );

  try {
    final result = await connection.query(
      'select id, email from users where id = @id',
      parameters: AnySqlParameters.named({'id': 1}),
    );
    print(result.firstOrNull);
  } finally {
    await connection.close();
  }
}

final class ExamplePostgresDriver extends AnySqlDriverBase {
  const ExamplePostgresDriver()
    : super('example_postgres', AnySqlDialect.postgres);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);
    return _ExampleConnection();
  }
}

final class _ExampleConnection implements AnySqlConnection {
  @override
  bool isOpen = true;

  @override
  Future<void> close() async {
    isOpen = false;
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    if (!isOpen) {
      throw const AnySqlConnectionException('Connection is closed.');
    }

    // A real adapter would pass the statement and parameters to its driver.
    return AnySqlResult.rows([
      {'statement': statement, 'parameters': parameters},
    ]);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) async {
    throw const AnySqlUnsupportedException(
      'The example driver does not support transactions.',
    );
  }
}
