import 'package:anysql/anysql.dart';
import 'package:anysql/src/setup_file_generator.dart';
import 'package:test/test.dart';

void main() {
  test('options helper connects with a direct driver', () async {
    final options = AnySqlOptions(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      backendUri: Uri.parse('https://api.example.com/anysql'),
    );
    final driver = _FakeDriver(AnySqlDialect.sqlite);

    final connection = await options.connect(driver: driver);

    expect(connection.isOpen, isTrue);
    expect(options.hasBackend, isTrue);
  });

  test('options helper connects through a backend client', () async {
    final options = AnySqlOptions(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      backendUri: Uri.parse('https://api.example.com/anysql'),
    );
    final client = _FakeBackendClient();

    final connection = await options.connectBackend(client: client);

    expect(connection.isOpen, isTrue);
    expect(client.lastOptions, same(options));
  });

  test('generator creates firebase-style options file', () {
    final contents = generateAnySqlOptionsFile(
      const AnySqlSetupInput(
        dialect: AnySqlDialect.postgres,
        host: 'localhost',
        database: 'app',
        username: 'admin',
        passwordEnvironmentKey: 'ANYSQL_PASSWORD',
        backendUrl: 'https://api.example.com/anysql',
        backendHeaders: {'x-client': 'anysql-test'},
      ),
    );

    expect(contents, contains('final class DefaultAnySqlOptions'));
    expect(contents, contains('AnySqlConfig.postgres'));
    expect(contents, contains("host: 'localhost'"));
    expect(contents, contains("database: 'app'"));
    expect(contents, contains("username: 'admin'"));
    expect(
      contents,
      contains("password: const String.fromEnvironment('ANYSQL_PASSWORD')"),
    );
    expect(contents, contains("Uri.parse('https://api.example.com/anysql')"));
    expect(contents, contains("'x-client': 'anysql-test'"));
    expect(contents, contains('connectBackend'));
    expect(contents, isNot(contains('password: null')));
  });

  test('generator escapes dart string literal content', () {
    final contents = generateAnySqlOptionsFile(
      const AnySqlSetupInput(
        dialect: AnySqlDialect.sqlite,
        database: r"data/$tenant's-app.db",
        backendUrl: 'https://api.example.com/tenant/\$tenant',
        backendHeaders: {'x-note': "owner's\nworkspace"},
      ),
    );

    expect(contents, contains(r"database: 'data/\$tenant\'s-app.db'"));
    expect(
      contents,
      contains(r"Uri.parse('https://api.example.com/tenant/\$tenant')"),
    );
    expect(contents, contains(r"'x-note': 'owner\'s\nworkspace'"));
  });
}

final class _FakeDriver extends AnySqlDriverBase {
  _FakeDriver(AnySqlDialect dialect) : super('fake', dialect);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);
    return _FakeConnection();
  }
}

final class _FakeConnection implements AnySqlConnection {
  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    return AnySqlResult.command();
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw UnimplementedError();
  }
}

final class _FakeBackendClient implements AnySqlBackendClient {
  AnySqlOptions? lastOptions;

  @override
  Future<AnySqlConnection> connect(AnySqlOptions options) async {
    lastOptions = options;
    return _FakeConnection();
  }
}
