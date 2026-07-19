import 'package:anysql/anysql.dart';
import 'package:test/test.dart';

void main() {
  test('store compiles PostgreSQL keyword queries', () async {
    final connection = _RecordingConnection();
    final store = AnySqlStore(connection, dialect: AnySqlDialect.postgres);

    await store
        .collection('users')
        .where('active', isEqualTo: true)
        .where('score', isGreaterThanOrEqualTo: 10)
        .orderBy('created_at', descending: true)
        .limit(5)
        .offset(10)
        .get();

    expect(
      connection.lastStatement,
      'select * from "users" where "active" = @p0 and "score" >= @p1 '
      'order by "created_at" desc limit @p2 offset @p3',
    );
    expect(connection.lastParameters, {
      'p0': true,
      'p1': 10,
      'p2': 5,
      'p3': 10,
    });
  });

  test('store compiles MySQL document set as upsert', () async {
    final connection = _RecordingConnection();
    final store = AnySqlStore(connection, dialect: AnySqlDialect.mysql);

    await store.collection('users').doc(1).set({'name': 'Ada', 'active': true});

    expect(
      connection.lastStatement,
      'insert into `users` (`name`, `active`, `id`) '
      'values (:p0, :p1, :p2) '
      'on duplicate key update `name` = values(`name`), '
      '`active` = values(`active`)',
    );
    expect(connection.lastParameters, {'p0': 'Ada', 'p1': true, 'p2': 1});
  });

  test('store compiles offset without limit for each SQL dialect', () async {
    final cases = <AnySqlDialect, String>{
      AnySqlDialect.postgres: 'select * from "users" offset @p0',
      AnySqlDialect.mysql:
          'select * from `users` limit 18446744073709551615 offset :p0',
      AnySqlDialect.sqlite: 'select * from "users" limit -1 offset ?',
    };

    for (final entry in cases.entries) {
      final connection = _RecordingConnection();
      final store = AnySqlStore(connection, dialect: entry.key);

      await store.collection('users').offset(10).get();

      expect(connection.lastStatement, entry.value);
      expect(
        connection.lastParameters,
        entry.key == AnySqlDialect.sqlite
            ? {
                AnySqlParameters.positionalValuesKey: [10],
              }
            : {'p0': 10},
      );
    }
  });

  test('store compiles SQL projection and count queries', () async {
    final connection = _RecordingConnection();
    final store = AnySqlStore(connection, dialect: AnySqlDialect.postgres);

    await store.collection('users').select(['id', 'email', 'email']).get();
    expect(connection.lastStatement, 'select "id", "email" from "users"');

    connection.nextResult = AnySqlResult.rows([
      {'count': 2},
    ]);
    final count = await store
        .collection('users')
        .where('active', isEqualTo: true)
        .count();

    expect(count, 2);
    expect(
      connection.lastStatement,
      'select count(*) as "count" from "users" where "active" = @p0',
    );
  });

  test('store compiles bulk inserts and whereNotIn filters', () async {
    final connection = _RecordingConnection();
    final store = AnySqlStore(connection, dialect: AnySqlDialect.postgres);

    await store.collection('users').addAll([
      {'name': 'Ada', 'active': true},
      {'active': false, 'name': 'Grace'},
    ]);
    expect(
      connection.lastStatement,
      'insert into "users" ("name", "active") values '
      '(@p0, @p1), (@p2, @p3)',
    );
    expect(connection.lastParameters, {
      'p0': 'Ada',
      'p1': true,
      'p2': 'Grace',
      'p3': false,
    });

    await store.collection('users').where('id', whereNotIn: [1, 2]).get();
    expect(
      connection.lastStatement,
      'select * from "users" where "id" not in (@p0, @p1)',
    );
  });

  test(
    'store compiles SQLite document set as a non-destructive upsert',
    () async {
      final connection = _RecordingConnection();
      final store = AnySqlStore(connection, dialect: AnySqlDialect.sqlite);

      await store.collection('users').doc(1).set({'name': 'Ada'});

      expect(
        connection.lastStatement,
        'insert into "users" ("name", "id") values (?, ?) '
        'on conflict ("id") do update set "name" = excluded."name"',
      );
      expect(connection.lastParameters, {
        AnySqlParameters.positionalValuesKey: ['Ada', 1],
      });
    },
  );

  test('store compiles MongoDB aggregate and writes', () async {
    final connection = _RecordingConnection();
    final store = AnySqlStore(connection, dialect: AnySqlDialect.mongodb);

    await store
        .collection('users')
        .where('active', isEqualTo: true)
        .where('score', isLessThan: 50)
        .orderBy('score')
        .limit(2)
        .get();

    expect(connection.lastStatement, 'users.aggregate');
    expect(connection.lastParameters, {
      'pipeline': [
        {
          r'$match': {
            r'$and': [
              {'active': true},
              {
                'score': {r'$lt': 50},
              },
            ],
          },
        },
        {
          r'$sort': {'score': 1},
        },
        {r'$limit': 2},
      ],
    });

    await store.collection('users').doc('abc').update({'name': 'Ada'});

    expect(connection.lastStatement, 'users.updateOne');
    expect(connection.lastParameters, {
      'filter': {'id': 'abc'},
      'update': {
        r'$set': {'name': 'Ada'},
      },
    });
  });

  test('store validates identifiers before building commands', () async {
    final store = AnySqlStore(
      _RecordingConnection(),
      dialect: AnySqlDialect.postgres,
    );

    expect(
      () => store.collection('users; drop table users'),
      throwsA(isA<AnySqlException>()),
    );
    expect(
      () => store.collection('users').where('bad-field', isEqualTo: 1),
      throwsA(isA<AnySqlException>()),
    );
  });

  test('store reports custom dialect compilation as unsupported', () async {
    final store = AnySqlStore(
      _RecordingConnection(),
      dialect: AnySqlDialect.custom,
    );

    expect(
      () => store.collection('users').get(),
      throwsA(isA<AnySqlUnsupportedException>()),
    );
  });
}

final class _RecordingConnection implements AnySqlConnection {
  String? lastStatement;
  Map<String, Object?>? lastParameters;
  var _isOpen = true;
  AnySqlResult? nextResult;

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
    lastStatement = statement;
    lastParameters = parameters;
    return nextResult ?? AnySqlResult.command(affectedRows: 1);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw UnimplementedError();
  }
}
