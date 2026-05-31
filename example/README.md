# anysql Example

This example is designed to run immediately after `dart pub get`. It shows the
three ways people usually use the `anysql` package: direct driver access
through a driver interface, backend/proxy access for Flutter apps, and
Firebase-style keyword calls.

```sh
dart run example/main.dart
```

Run it:

```sh
dart run example/main.dart
```

It prints three sections:

- a direct connection through a fake PostgreSQL-style driver,
- a backend/proxy connection through a fake backend client,
- a keyword-store query over a fake connection.

The sections are fake on purpose, so you can learn the API without running
PostgreSQL, MySQL, MongoDB, SQLite, or a backend locally. Direct database
drivers are available from `package:anysql/anysql_drivers.dart`.

## Keyword API

```dart
final db = connection.store(dialect: AnySqlDialect.sqlite);

await db.collection('users').add({'email': 'ada@example.com', 'active': 1});

final result = await db
    .collection('users')
    .where('active', isEqualTo: 1)
    .limit(10)
    .get();
```

## Generated Options

Create your own `lib/anysql_options.dart`:

```sh
dart run anysql
```

Then use the generated helper:

```dart
final db = await DefaultAnySqlOptions.connectStore(
  driver: const SqliteAnySqlDriver(),
);

try {
  final users = await db.collection('users').limit(20).get();
} finally {
  await db.close();
}
```

For Flutter mobile apps, keep credentials on your server and use the generated
backend helper:

```dart
final db = await DefaultAnySqlOptions.connectBackendStore(
  client: AnySqlHttpBackendClient(),
);

try {
  final user = await db.collection('users').doc(1).first();
} finally {
  await db.close();
}
```

Do not ship production database passwords inside a Flutter mobile app.

## More CLI Commands

Create a sample options file for all built-in databases:

```sh
dart run anysql init
```

Create a one-database options file:

```sh
dart run anysql configure --dialect postgres --host localhost --database app
```

If you use `--password-env ANYSQL_PASSWORD`, pass the password at runtime:

```sh
dart -DANYSQL_PASSWORD=your_password run example/main.dart
```

Project repository: [github.com/Azrul16/anysql](https://github.com/Azrul16/anysql)

