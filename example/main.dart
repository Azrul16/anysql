import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

Future<void> main() async {
  print('anysql example');
  print('-------------');

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

  await runDirectAnySqlExample(options);
  await runBackendAnySqlExample(options);
  await runKeywordStoreExample();
}

Future<void> runDirectAnySqlExample(AnySqlOptions options) async {
  print('\n1. Direct driver pattern for trusted Dart code');

  final connection = await options.connect(driver: ExamplePostgresDriver());

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

Future<void> runBackendAnySqlExample(AnySqlOptions options) async {
  print('\n2. Backend/proxy pattern for Flutter mobile apps');

  final connection = await options.connectBackend(
    client: ExampleBackendClient(),
  );

  try {
    final result = await connection.query(
      'users.findById',
      parameters: AnySqlParameters.document({'id': 1}),
    );

    print(result.firstOrNull);
  } finally {
    await connection.close();
  }
}

Future<void> runKeywordStoreExample() async {
  print('\n3. Keyword store pattern over real in-memory SQLite');

  final connection = await AnySql.connect(
    config: AnySqlConfig.sqlite(database: ':memory:'),
    driver: const SqliteAnySqlDriver(),
  );

  try {
    final db = connection.store(dialect: AnySqlDialect.sqlite);
    await connection.query(
      'create table users ('
      'id integer primary key, '
      'email text not null, '
      'active integer not null'
      ')',
    );
    await db.collection('users').add({'email': 'ada@example.com', 'active': 1});

    final result = await db
        .collection('users')
        .where('active', isEqualTo: 1)
        .limit(10)
        .get();
    print(result.firstOrNull);
  } finally {
    await connection.close();
  }
}

final class ExamplePostgresDriver extends AnySqlDriverBase {
  ExamplePostgresDriver() : super('example_postgres', AnySqlDialect.postgres);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    return _ExampleConnection(source: 'direct ${config.dialect.name} driver');
  }
}

final class ExampleBackendClient implements AnySqlBackendClient {
  @override
  Future<AnySqlConnection> connect(AnySqlOptions options) async {
    if (!options.hasBackend) {
      throw const AnySqlConfigException('Backend URL is required.');
    }

    return _ExampleConnection(source: 'backend proxy at ${options.backendUri}');
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
    if (!_isOpen) {
      throw const AnySqlConnectionException('Connection is closed.');
    }

    return AnySqlResult.rows([
      {'source': source, 'statement': statement, 'parameters': parameters},
    ]);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) async {
    if (!_isOpen) {
      throw const AnySqlConnectionException('Connection is closed.');
    }

    final transaction = _ExampleTransaction(this);

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
}

final class _ExampleTransaction implements AnySqlTransaction {
  _ExampleTransaction(this._connection);

  final _ExampleConnection _connection;
  var isCompleted = false;

  @override
  Future<void> commit() async {
    _checkActive();
    isCompleted = true;
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) {
    _checkActive();
    return _connection.query(statement, parameters: parameters);
  }

  @override
  Future<void> rollback() async {
    _checkActive();
    isCompleted = true;
  }

  void _checkActive() {
    if (isCompleted) {
      throw const AnySqlConnectionException(
        'Transaction is already completed.',
      );
    }
  }
}
