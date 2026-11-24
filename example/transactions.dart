import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

Future<void> main() async {
  final connection = await const SqliteAnySqlDriver().connect(
    AnySqlConfig.sqlite(database: ':memory:'),
  );
  final store = connection.store(dialect: AnySqlDialect.sqlite);

  try {
    await connection.query(
      'create table accounts (id integer primary key, balance integer not null)',
    );

    final accounts = store.collection('accounts');
    await accounts.addAll([
      {'id': 1, 'balance': 100},
      {'id': 2, 'balance': 100},
    ]);

    await store.transaction((tx) async {
      final accounts = tx.collection('accounts');
      await accounts.doc(1).update({'balance': 90});
      await accounts.doc(2).update({'balance': 110});
    });

    print((await accounts.orderBy('id').get()).rows);
  } finally {
    await store.close();
  }
}
