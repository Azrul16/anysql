# anysql

`anysql` is a Dart database package with a Firebase-style keyword API for SQL,
MongoDB, direct drivers, and backend proxy connections.

Use it when you want app code that reads like this:

```dart
final users = await db
    .collection('users')
    .where('active', isEqualTo: true)
    .limit(20)
    .get();
```

instead of writing raw SQL or MongoDB commands in every feature.

> Important: direct database connections are for trusted Dart environments such
> as CLIs, backend services, workers, and tests. Flutter mobile apps should
> normally call a secure backend API instead of shipping production database
> credentials inside the app.

## Quick Start

Install:

```sh
dart pub add anysql
```

For Flutter:

```sh
flutter pub add anysql
```

Create `lib/anysql_options.dart`:

```sh
dart run anysql
```

The setup command asks which database you want:

```text
1. PostgreSQL
2. MySQL
3. SQLite
4. MongoDB
```

Then it generates one focused options file for that database. Edit the values
in the generated file, then connect.

For trusted Dart code such as servers, CLIs, workers, and tests:

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

import 'anysql_options.dart';

Future<void> main() async {
  final db = await DefaultAnySqlOptions.connectStore(
    driver: const SqliteAnySqlDriver(),
  );

  final users = await db.collection('users').limit(20).get();
  print(users.rows);
}
```

For Flutter apps, keep database credentials on your backend and connect through
your API:

```dart
import 'package:anysql/anysql.dart';

import 'anysql_options.dart';

final db = await DefaultAnySqlOptions.connectBackendStore(
  client: AnySqlHttpBackendClient(),
);

final user = await db.collection('users').doc(1).first();
```

## Try It Now

This example uses an in-memory SQLite database, so it runs without PostgreSQL,
MySQL, MongoDB, or a backend server:

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

Future<void> main() async {
  final connection = await AnySql.connect(
    config: AnySqlConfig.sqlite(database: ':memory:'),
    driver: const SqliteAnySqlDriver(),
  );

  try {
    final db = connection.store(dialect: AnySqlDialect.sqlite);

    await connection.query(
      'create table users ('
      'id integer primary key, '
      'email text not null, '
      'active integer not null'
      ')',
    );

    await db.collection('users').add({
      'email': 'ada@example.com',
      'active': 1,
    });

    final result = await db
        .collection('users')
        .where('active', isEqualTo: 1)
        .limit(10)
        .get();
    print(result.rows);
  } finally {
    await connection.close();
  }
}
```

Output:

```text
[{id: 1, email: ada@example.com, active: 1}]
```

## Keyword Store API

`AnySqlStore` gives `anysql` a Firebase-like API while keeping the package
database-neutral:

```dart
final db = connection.store(dialect: config.dialect);

await db.collection('users').add({
  'email': 'ada@example.com',
  'active': true,
});

final users = await db
    .collection('users')
    .where('active', isEqualTo: true)
    .orderBy('created_at', descending: true)
    .limit(20)
    .get();

await db.collection('users').doc(1).update({'active': false});
await db.collection('users').doc(1).delete();
```

Supported keyword operations:

- `collection(name).get()`
- `where(field, isEqualTo: value)`
- `where(field, isNotEqualTo: value)`
- `where(field, isLessThan: value)`
- `where(field, isLessThanOrEqualTo: value)`
- `where(field, isGreaterThan: value)`
- `where(field, isGreaterThanOrEqualTo: value)`
- `where(field, whereIn: values)`
- `orderBy(field, descending: true)`
- `limit(count)` and `offset(count)`
- `first()` to read the first matching row or document
- `add(data)`, `doc(id).get()`, `doc(id).set(data)`,
  `doc(id).first()`, `doc(id).update(data)`, and `doc(id).delete()`

SQL identifiers are validated before commands are built. Collection/table and
field names must use letters, numbers, and underscores, starting with a letter
or underscore.

## What This Package Includes

- Firebase-style keyword access with `AnySqlStore`, `collection`, `where`,
  `doc`, `add`, `set`, `update`, and `delete`.
- `dart run anysql` setup that generates one focused options file.
- Shared connection, driver, config, result, and backend contracts.
- A ready-to-use JSON HTTP backend client: `AnySqlHttpBackendClient`.
- Built-in direct drivers:
  - `PostgresAnySqlDriver`
  - `MysqlAnySqlDriver`
  - `SqliteAnySqlDriver`
  - `MongodbAnySqlDriver`

## Generate an Options File

For the easiest setup after installing the package, run:

```sh
dart run anysql
```

The command asks you to choose one included database:

```text
1. PostgreSQL
2. MySQL
3. SQLite
4. MongoDB
```

Then it writes `lib/anysql_options.dart` for that database only.

The generated file gives you direct-driver helpers:

```dart
final db = await DefaultAnySqlOptions.connectStore(
  driver: const SqliteAnySqlDriver(),
);

final users = await db.collection('users').limit(20).get();
```

and backend/proxy helpers for Flutter apps:

```dart
final db = await DefaultAnySqlOptions.connectBackendStore(
  client: AnySqlHttpBackendClient(),
);
```

To generate an editable sample file with all built-in databases:

```sh
dart run anysql init
```

Then choose one of the sample configs:

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

import 'anysql_options.dart';

Future<void> main() async {
  final connection = await AnySqlOptionsFile.postgres.connect(
    driver: const PostgresAnySqlDriver(),
  );

  try {
    final result = await connection.query(
      'select id, email from users where id = @id',
      parameters: AnySqlParameters.named({'id': 1}),
    );

    print(result.firstOrNull);
  } finally {
    await connection.close();
  }
}
```

## Raw Query Escape Hatch

When you need database-specific SQL or commands, use `connection.query(...)`
directly:

```dart
final result = await connection.query(
  'select id, email from users where active = @active',
  parameters: AnySqlParameters.named({'active': true}),
);
```

## Configure One Database

Generate a smaller options file for one database:

```sh
dart run anysql configure \
  --dialect postgres \
  --host localhost \
  --database app \
  --username postgres \
  --password-env ANYSQL_PASSWORD
```

Run your app with the password as a Dart define:

```sh
dart -DANYSQL_PASSWORD=your_password run
```

Flutter uses:

```sh
flutter run --dart-define=ANYSQL_PASSWORD=your_password
```

Then connect from trusted Dart code:

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

import 'anysql_options.dart';

Future<void> main() async {
  final connection = await DefaultAnySqlOptions.connect(
    driver: const PostgresAnySqlDriver(),
  );

  try {
    final result = await connection.query('select now() as server_time');
    print(result.firstOrNull);
  } finally {
    await connection.close();
  }
}
```

## Flutter Mobile and Backend Access

Do not put production database usernames or passwords directly in Flutter
mobile apps. Instead, keep the real database connection on your server and let
the app call that server. Browser/web support is not advertised while the
package includes native direct-driver dependencies.

`anysql` supports this with `AnySqlBackendClient`. For a JSON HTTP backend,
use the built-in `AnySqlHttpBackendClient`:

```dart
final db = await DefaultAnySqlOptions.connectBackendStore(
  client: AnySqlHttpBackendClient(),
);

final users = await db.collection('users').where('active', isEqualTo: true).get();
```

`AnySqlHttpBackendClient` sends `POST` requests to `backendUri` with the
statement, parameters, and non-secret config metadata. It does not send the
database password from `AnySqlConfig`.

Your backend should return JSON in this shape:

```json
{
  "rows": [{"id": 1, "email": "ada@example.com"}],
  "affectedRows": 0,
  "lastInsertId": null,
  "metadata": {"columns": ["id", "email"]}
}
```

You can also implement `AnySqlBackendClient` yourself when your backend uses a
different protocol, authentication flow, or batching model.

## Driver Capability Matrix

| Driver | Backing package | Best fit | Parameter style | Notes |
| --- | --- | --- | --- | --- |
| PostgreSQL | `postgres` | Dart servers, CLIs, workers | named `@id` parameters | Supports SSL through `sslEnabled` |
| MySQL | `mysql_client` | Dart servers, CLIs, workers | `mysql_client` map parameters | `options` supports `collation` and `timeoutMs` |
| SQLite | `sqlite3` | local native apps, CLIs, tests | positional `values` list | `:memory:` is ideal for tests and examples |
| MongoDB | `mongo_dart` | Dart servers, CLIs, workers | document maps | Uses `collection.operation` statement names |

The built-in direct drivers are intentionally thin adapters over established
database packages. They normalize results and errors, but they do not hide the
database engine or replace database-specific knowledge.

### SQLite

```dart
final connection = await AnySql.connect(
  config: AnySqlConfig.sqlite(database: ':memory:'),
  driver: const SqliteAnySqlDriver(),
);
```

Use `:memory:` for tests or pass a file path such as `app.sqlite`.

### PostgreSQL

```dart
final connection = await AnySql.connect(
  config: AnySqlConfig.postgres(
    host: 'localhost',
    database: 'app',
    username: 'postgres',
    password: const String.fromEnvironment('ANYSQL_PASSWORD'),
  ),
  driver: const PostgresAnySqlDriver(),
);
```

PostgreSQL named parameters use the `@name` syntax from `package:postgres`.

### MySQL

```dart
final connection = await AnySql.connect(
  config: AnySqlConfig.mysql(
    host: 'localhost',
    database: 'app',
    username: 'root',
    password: const String.fromEnvironment('ANYSQL_PASSWORD'),
  ),
  driver: const MysqlAnySqlDriver(),
);
```

MySQL parameter behavior follows `package:mysql_client`.

### MongoDB

```dart
final connection = await AnySql.connect(
  config: AnySqlConfig.mongodb(
    host: 'localhost',
    database: 'app',
  ),
  driver: const MongodbAnySqlDriver(),
);

final users = await connection.query(
  'users.find',
  parameters: AnySqlParameters.document({
    'filter': {'active': true},
  }),
);
```

MongoDB statements use `collection.operation` names. Supported operations are
`find`, `findOne`, `insertOne`, `insertMany`, `updateOne`, `updateMany`,
`replaceOne`, `deleteOne`, `deleteMany`, `count`, and `aggregate`.

## Errors and Debugging

Built-in drivers throw `AnySqlException` subclasses:

- `AnySqlConfigException` for invalid or incomplete configuration.
- `AnySqlDriverException` when no registered driver supports a config.
- `AnySqlConnectionException` when a closed connection is used.
- `AnySqlQueryException` when the underlying database package rejects a query.

Query exceptions include a short statement preview but not parameter values, so
logs are useful without accidentally printing secrets.

## Transactions

`AnySqlConnection.transaction` commits when the callback completes and rolls
back when it throws. The shared contract does not include nested transactions
or savepoints; if you need those, use the underlying database package directly
or add a custom driver behavior for your project.

## Register Multiple Drivers

Register drivers when your app wants to choose the correct driver from a
config:

```dart
final anySql = AnySql([
  const PostgresAnySqlDriver(),
  const MysqlAnySqlDriver(),
  const SqliteAnySqlDriver(),
  const MongodbAnySqlDriver(),
]);

final connection = await anySql.open(
  AnySqlConfig.sqlite(database: ':memory:'),
);
```

## CLI Reference

Create one options file interactively:

```sh
dart run anysql
```

Explicit setup command:

```sh
dart run anysql setup
```

Create starter options:

```sh
dart run anysql init
```

Overwrite an existing generated file:

```sh
dart run anysql init --force
```

Configure PostgreSQL:

```sh
dart run anysql configure --dialect postgres --host localhost --database app
```

Configure SQLite:

```sh
dart run anysql configure --dialect sqlite --database app.sqlite
```

SQLite uses only `--database`. Network options such as `--host`, `--port`,
`--username`, `--password-env`, and `--ssl` are for networked databases.

Show help:

```sh
dart run anysql --help
```

## Common Errors Users Hit

- `PostgresAnySqlDriver` is not found: add
  `import 'package:anysql/anysql_drivers.dart';`.
- A Flutter app exposes credentials: move direct database access to a backend
  service and use `AnySqlHttpBackendClient` or a custom `AnySqlBackendClient`
  in the app.
- SQLite insert parameters do not bind: pass positional values with
  `AnySqlParameters.positional([...])`.
- PostgreSQL parameters do not bind: use `@name` placeholders and pass a map
  with the same names.
- `dart run anysql configure --dialect sqlite --host ...` fails: SQLite does
  not use network options.
- A generated file already exists: re-run the command with `--force` only when
  you really want to overwrite it.

## More Documentation

See [doc/driver_guide.md](doc/driver_guide.md) for a longer driver guide.

See [example/main.dart](example/main.dart) for a runnable example that covers:

- a fake direct PostgreSQL-style driver,
- a fake backend/proxy client,
- a real in-memory SQLite database.

## Reliability Notes

- `AnySqlConfig` validates required host, database, username, and port values.
- `AnySqlConfig.toString()` masks passwords.
- Generated configs can read passwords from `String.fromEnvironment`.
- Config maps and result rows are defensively copied.
- Drivers are explicit, so your app can see which database package is doing the
  real work.

## Author

Created and maintained by Azrul Amaline.

- GitHub: [Azrul16](https://github.com/Azrul16)
- Repository: [github.com/Azrul16/anysql](https://github.com/Azrul16/anysql)

## License

`anysql` is released under the MIT License.
