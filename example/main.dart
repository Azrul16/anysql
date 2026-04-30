import 'package:anysql/anysql.dart';

Future<void> main() async {
  final options = AnySqlOptions(
    config: AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      username: 'postgres',
      password: const String.fromEnvironment('ANYSQL_PASSWORD'),
    ),
    backendUri: Uri.parse('https://api.example.com/anysql'),
    backendHeaders: const {'x-client': 'anysql-example'},
  );

  final directConnection = await options.connect(
    driver: ExamplePostgresDriver(),
  );
  final directResult = await directConnection.query(
    'select * from users where id = @id',
    parameters: {'id': 1},
  );

  print('Direct result: ${directResult.firstOrNull}');
  await directConnection.close();

  final backendConnection = await options.connectBackend(
    client: ExampleBackendClient(),
  );
  final backendResult = await backendConnection.query(
    'users.findById',
    parameters: {'id': 1},
  );

  print('Backend result: ${backendResult.firstOrNull}');
  await backendConnection.close();
}

final class ExamplePostgresDriver extends AnySqlDriverBase {
  ExamplePostgresDriver() : super('example_postgres', AnySqlDialect.postgres);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);
    return _ExampleConnection(source: 'direct');
  }
}

final class ExampleBackendClient implements AnySqlBackendClient {
  @override
  Future<AnySqlConnection> connect(AnySqlOptions options) async {
    if (!options.hasBackend) {
      throw const AnySqlException('Backend URL is required.');
    }

    return _ExampleConnection(source: options.backendUri.toString());
  }
}

final class _ExampleConnection implements AnySqlConnection {
  _ExampleConnection({required this.source});

  final String source;
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
      {'source': source, 'statement': statement, 'parameters': parameters},
    ]);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw UnsupportedError('Example connection does not support transactions.');
  }
}
