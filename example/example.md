# AnySQL examples

## Run your first query

This program creates an in-memory SQLite database, writes two records, and
prints the active user. It needs only the AnySQL dependency and runs without
a database server.

```dart
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
```

To run it in your own Dart app, add the dependency with `dart pub add anysql`,
save the program as `bin/quick_start.dart`, and run
`dart run bin/quick_start.dart`.

## Choose a feature

From a checkout of the [repository](https://github.com/Azrul16/anysql), run
`dart pub get` once, then run the example that matches your use case.

| I want to… | Source | Run |
| --- | --- | --- |
| Read and write through the collection API | [Keyword store](https://github.com/Azrul16/anysql/blob/main/example/keyword_store.dart) | `dart run example/keyword_store.dart` |
| Bind parameters and use SQL `RETURNING` | [Direct SQL](https://github.com/Azrul16/anysql/blob/main/example/direct_queries.dart) | `dart run example/direct_queries.dart` |
| Commit related writes together | [Transactions](https://github.com/Azrul16/anysql/blob/main/example/transactions.dart) | `dart run example/transactions.dart` |
| Use the HTTP client with a simulated server | [HTTP backend](https://github.com/Azrul16/anysql/blob/main/example/http_backend.dart) | `dart run example/http_backend.dart` |
| Register a database adapter | [Custom driver](https://github.com/Azrul16/anysql/blob/main/example/custom_driver.dart) | `dart run example/custom_driver.dart` |

The keyword API uses non-null document IDs. To update a document, get its
reference directly with `store.collection('users').doc(id)`. Use filtered
collection references for reads.

## Generate options for your app

With AnySQL installed, run `dart run anysql` from the directory that contains
your app's `pubspec.yaml`. Choose your database and edit the resulting
`lib/anysql_options.dart`. The Readme shows how to use the generated
`DefaultAnySqlOptions` class with a direct driver or an HTTP backend.

[Read the setup guide](https://pub.dev/packages/anysql#install-and-generate-options)
