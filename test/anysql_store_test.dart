import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';
import 'package:test/test.dart';

void main() {
  test('store runs Firebase-style CRUD against SQLite', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );
    final store = connection.store(dialect: AnySqlDialect.sqlite);

    try {
      await connection.query(
        'create table users ('
        'id integer primary key, '
        'name text not null, '
        'active integer not null, '
        'score integer not null'
        ')',
      );

      final insert = await store.collection('users').add({
        'name': 'Ada',
        'active': 1,
        'score': 42,
      });
      expect(insert.affectedRows, 1);

      final activeUsers = await store
          .collection('users')
          .where('active', isEqualTo: 1)
          .orderBy('score', descending: true)
          .limit(10)
          .get();
      expect(activeUsers.rows, [
        {'id': 1, 'name': 'Ada', 'active': 1, 'score': 42},
      ]);

      await store.collection('users').doc(1).update({'score': 100});
      expect(await store.collection('users').doc(1).first(), contains('score'));
      expect((await store.collection('users').doc(1).first())?['score'], 100);

      await store.collection('users').doc(1).set({
        'name': 'Ada Lovelace',
        'active': 0,
        'score': 99,
      });
      expect((await store.collection('users').doc(1).get()).first, {
        'id': 1,
        'name': 'Ada Lovelace',
        'active': 0,
        'score': 99,
      });

      await store.collection('users').doc(1).delete();
      expect(await store.collection('users').get(), isA<AnySqlResult>());
      expect((await store.collection('users').get()).rows, isEmpty);
    } finally {
      await connection.close();
    }
  });

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
}

final class _RecordingConnection implements AnySqlConnection {
  String? lastStatement;
  Map<String, Object?>? lastParameters;
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
    lastStatement = statement;
    lastParameters = parameters;
    return AnySqlResult.command(affectedRows: 1);
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw UnimplementedError();
  }
}
