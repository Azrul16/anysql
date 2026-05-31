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
