import 'package:anysql/anysql.dart';

Future<void> main() async {
  final config = AnySqlConfig.postgres(
    host: 'localhost',
    database: 'app',
    username: 'postgres',
    password: const String.fromEnvironment('ANYSQL_PASSWORD'),
  );

  final anySql = AnySql([ExamplePostgresDriver()]);
  final connection = await anySql.open(config);

  final result = await connection.query(
    'select * from users where id = @id',
    parameters: {'id': 1},
  );

  print(result.firstOrNull);
  await connection.close();
}

final class ExamplePostgresDriver extends AnySqlDriverBase {
  ExamplePostgresDriver() : super('example_postgres', AnySqlDialect.postgres);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);
    return _ExampleConnection();
  }
}

final class _ExampleConnection implements AnySqlConnection {
  var _isOpen = true;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    return AnySqlResult.rows([
      {'statement': statement, 'parameters': parameters},
    ]);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw UnsupportedError('Example driver does not implement transactions.');
  }
}
