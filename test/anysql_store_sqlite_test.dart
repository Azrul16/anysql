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

  test(
    'SQLite document set updates without deleting the existing row',
    () async {
      final connection = await AnySql.connect(
        config: AnySqlConfig.sqlite(database: ':memory:'),
        driver: const SqliteAnySqlDriver(),
      );
      final store = connection.store(dialect: AnySqlDialect.sqlite);

      try {
        await connection.query(
          'create table users (id integer primary key, name text not null)',
        );
        await connection.query(
          'create table delete_audit (user_id integer not null)',
        );
        await connection.query(
          'create trigger audit_user_delete after delete on users '
          'begin insert into delete_audit (user_id) values (old.id); end',
        );
        await store.collection('users').doc(1).set({'name': 'Ada'});

        await store.collection('users').doc(1).set({'name': 'Grace'});

        expect(await store.collection('users').doc(1).first(), {
          'id': 1,
          'name': 'Grace',
        });
        expect(
          (await connection.query('select * from delete_audit')).rows,
          isEmpty,
        );
      } finally {
        await connection.close();
      }
    },
  );

  test('store transactions commit and roll back keyword operations', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );
    final store = connection.store(dialect: AnySqlDialect.sqlite);

    try {
      await connection.query(
        'create table users (id integer primary key, name text not null)',
      );

      await store.transaction((transaction) async {
        await transaction.collection('users').add({'name': 'Ada'});
      });
      await expectLater(
        store.transaction((transaction) async {
          await transaction.collection('users').add({'name': 'Grace'});
          throw StateError('roll back');
        }),
        throwsStateError,
      );

      expect((await store.collection('users').get()).rows, [
        {'id': 1, 'name': 'Ada'},
      ]);
      expect(await store.collection('users').count(), 1);
      expect(
        await store
            .collection('users')
            .where('name', isEqualTo: 'Ada')
            .exists(),
        isTrue,
      );
      expect(await store.collection('users').select(['name']).first(), {
        'name': 'Ada',
      });
    } finally {
      await connection.close();
    }
  });
}
