import 'package:anysql/anysql.dart';
import 'package:test/test.dart';

void main() {
  test('connect opens a connection with the supplied driver', () async {
    final config = AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      username: 'user',
      password: 'test-password',
    );
    final driver = _FakeDriver(AnySqlDialect.postgres);

    final connection = await AnySql.connect(config: config, driver: driver);

    expect(connection.isOpen, isTrue);
    expect(driver.lastConfig, same(config));
  });

  test('registered client opens connections with a supported driver', () async {
    final anySql = AnySql([_FakeDriver(AnySqlDialect.mysql)]);
    final config = AnySqlConfig.mysql(host: 'localhost', database: 'app');

    final connection = await anySql.open(config);

    expect(connection.isOpen, isTrue);
  });

  test('registered client rejects duplicate driver names', () {
    final anySql = AnySql([_FakeDriver(AnySqlDialect.mysql)]);

    expect(
      () => anySql.register(_FakeDriver(AnySqlDialect.postgres)),
      throwsA(isA<AnySqlException>()),
    );
  });

  test('registered client rejects unsupported configs', () {
    final anySql = AnySql([_FakeDriver(AnySqlDialect.mysql)]);
    final config = AnySqlConfig.postgres(host: 'localhost', database: 'app');

    expect(() => anySql.driverFor(config), throwsA(isA<AnySqlException>()));
  });

  test('driver base rejects unsupported dialects', () {
    final driver = _FakeDriver(AnySqlDialect.mysql);
    final config = AnySqlConfig.postgres(host: 'localhost', database: 'app');

    expect(
      () => driver.checkSupported(config),
      throwsA(isA<AnySqlException>()),
    );
  });

  test('result helpers expose row state', () {
    final result = AnySqlResult.rows([
      {'id': 1, 'name': 'Ada'},
    ]);

    expect(result.isNotEmpty, isTrue);
    expect(result.rowCount, 1);
    expect(result.first, {'id': 1, 'name': 'Ada'});
    expect(result.firstOrNull, {'id': 1, 'name': 'Ada'});
  });

  test('config validates required fields and port range', () {
    expect(
      () => AnySqlConfig.postgres(host: '', database: 'app'),
      throwsA(isA<AnySqlException>()),
    );
    expect(
      () => AnySqlConfig.mysql(host: 'localhost', port: 70000, database: 'app'),
      throwsA(isA<AnySqlException>()),
    );
  });

  test('config hides password in string output', () {
    final config = AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      password: 'test-password',
    );

    expect(config.toString(), contains('password: ***'));
    expect(config.toString(), isNot(contains('test-password')));
  });

  test('config equality and hash code ignore option insertion order', () {
    final first = AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      options: {'a': 1, 'b': 2},
    );
    final second = AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      options: {'b': 2, 'a': 1},
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('config and result make defensive collection copies', () {
    final options = {'schema': 'public'};
    final config = AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      options: options,
    );
    options['schema'] = 'changed';

    final rows = [
      {'id': 1},
    ];
    final result = AnySqlResult.rows(rows);
    rows.first['id'] = 2;

    expect(config.options, {'schema': 'public'});
    expect(result.first, {'id': 1});
    expect(() => config.options['x'] = true, throwsUnsupportedError);
    expect(() => result.rows.first['id'] = 3, throwsUnsupportedError);
  });

  test('copyWith can clear nullable fields', () {
    final config = AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
      username: 'user',
    );

    final updated = config.copyWith(
      username: const AnySqlValue<String?>(null),
      sslEnabled: true,
    );

    expect(updated.username, isNull);
    expect(updated.sslEnabled, isTrue);
  });
}

final class _FakeDriver extends AnySqlDriverBase {
  _FakeDriver(AnySqlDialect dialect) : super('fake', dialect);

  AnySqlConfig? lastConfig;

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);
    lastConfig = config;
    return _FakeConnection();
  }
}

final class _FakeConnection implements AnySqlConnection {
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
  ) async {
    final transaction = _FakeTransaction();

    try {
      final value = await action(transaction);
      await transaction.commit();
      return value;
    } catch (_) {
      await transaction.rollback();
      rethrow;
    }
  }
}

final class _FakeTransaction implements AnySqlTransaction {
  var completed = false;

  @override
  Future<void> commit() async {
    completed = true;
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    return AnySqlResult.command(affectedRows: 1);
  }

  @override
  Future<void> rollback() async {
    completed = true;
  }
}
