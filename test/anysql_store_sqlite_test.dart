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
}
