import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

Future<void> main() async {
  final connection = await const SqliteAnySqlDriver().connect(
    AnySqlConfig.sqlite(database: ':memory:'),
  );
  final store = connection.store(dialect: AnySqlDialect.sqlite);

  try {
    await connection.query(
      'create table users ('
      'id integer primary key, email text not null, active integer not null)',
    );

    final users = store.collection('users');
    await users.add({'email': 'ada@example.com', 'active': 1});
    await users.add({'email': 'grace@example.com', 'active': 0});

    final activeUsers = await users
        .where('active', isEqualTo: 1)
        .orderBy('email')
        .limit(10)
        .get();
    print(activeUsers.rows);
  } finally {
    await store.close();
  }
}
