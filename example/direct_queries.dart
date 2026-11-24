import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

Future<void> main() async {
  final connection = await AnySql.connect(
    config: AnySqlConfig.sqlite(database: ':memory:'),
    driver: const SqliteAnySqlDriver(),
  );

  try {
    await connection.query(
      'create table users (id integer primary key, email text not null)',
    );

    final inserted = await connection.query(
      'insert into users (email) values (?) returning id',
      parameters: AnySqlParameters.positional(['ada@example.com']),
    );
    print('Inserted ${inserted.affectedRows} row: ${inserted.first}');

    final user = await connection.query(
      'select id, email from users where id = ?',
      parameters: AnySqlParameters.positional([inserted.first['id']]),
    );
    print(user.firstOrNull);
  } finally {
    await connection.close();
  }
}
