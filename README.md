# anysql

`anysql` is a small Dart database abstraction for projects that want one
application-facing API for SQL, NoSQL, direct database drivers, and backend
proxy connections.

Use it when you want your app code to work with `AnySqlConfig`,
`AnySqlConnection`, `AnySqlResult`, and `AnySqlOptions` instead of being tightly
coupled to PostgreSQL, MySQL, SQLite, MongoDB, or a custom data service.

> Important: direct database connections are for trusted Dart environments such
> as CLIs, backend services, workers, and tests. Flutter mobile and web apps
> should normally call a secure backend API instead of shipping production
> database credentials inside the app.

## What This Package Includes

- A shared connection contract: `AnySqlConnection`.
- A shared driver contract: `AnySqlDriver`.
- Normalized query results: `AnySqlResult`.
- Connection settings for PostgreSQL, MySQL, SQLite, MongoDB, and custom
  backends: `AnySqlConfig`.
- App-level options files: `AnySqlOptions`.
- Built-in direct drivers:
  - `PostgresAnySqlDriver`
  - `MysqlAnySqlDriver`
  - `SqliteAnySqlDriver`
  - `MongodbAnySqlDriver`
- CLI setup commands:
  - `dart run anysql init`
  - `dart run anysql configure`

## Install

```sh
dart pub add anysql
```

For Flutter:

```sh
flutter pub add anysql
```

Import the core API:

```dart
import 'package:anysql/anysql.dart';
```

Import the built-in direct database drivers only when you need them:

```dart
import 'package:anysql/anysql_drivers.dart';
```

## Fastest Working Example

SQLite can run in memory, so this example works without any external database
server:

```dart
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

    await connection.query(
      'insert into users (email) values (?)',
      parameters: {
        'values': ['ada@example.com'],
      },
    );

    final result = await connection.query('select id, email from users');
    print(result.rows);
  } finally {
    await connection.close();
  }
}
```

SQLite positional parameters use the special `values` list.

## Generate an Options File

Create an editable options file with sample configs for PostgreSQL, MySQL,
SQLite, and MongoDB:

```sh
dart run anysql init
```

This creates:

```text
lib/anysql_options.dart
```

Use one generated config like this:

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
      parameters: {'id': 1},
    );

    print(result.firstOrNull);
  } finally {
    await connection.close();
  }
}
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

## Direct Connections

Direct connections are a good fit for Dart servers, command-line tools,
background jobs, local scripts, and tests.

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

Future<void> main() async {
  final config = AnySqlConfig.postgres(
    host: 'localhost',
    database: 'app',
    username: 'postgres',
    password: const String.fromEnvironment('ANYSQL_PASSWORD'),
  );

  final connection = await AnySql.connect(
    config: config,
    driver: const PostgresAnySqlDriver(),
  );

  try {
    final users = await connection.query(
      'select id, email from users where active = @active',
      parameters: {'active': true},
    );

    for (final row in users.rows) {
      print(row);
    }
  } finally {
    await connection.close();
  }
}
```

## Flutter Mobile and Web

Do not put production database usernames or passwords directly in Flutter
mobile or web apps. Instead, keep the real database connection on your server
and let the app call that server.

`anysql` supports this with `AnySqlBackendClient`:

```dart
final connection = await DefaultAnySqlOptions.connectBackend(
  client: myBackendClient,
);

final result = await connection.query(
  'users.findById',
  parameters: {'id': 1},
);
```

Your backend client decides how to send the request, authenticate the user, and
return an `AnySqlResult`.

## Built-in Driver Notes

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
  parameters: {
    'filter': {'active': true},
  },
);
```

MongoDB statements use `collection.operation` names. Supported operations are
`find`, `findOne`, `insertOne`, `updateOne`, `deleteOne`, and `aggregate`.

## Errors and Debugging

Built-in drivers throw `AnySqlException` subclasses:

- `AnySqlConfigException` for invalid or incomplete configuration.
- `AnySqlDriverException` when no registered driver supports a config.
- `AnySqlConnectionException` when a closed connection is used.
- `AnySqlQueryException` when the underlying database package rejects a query.

Query exceptions include a short statement preview but not parameter values, so
logs are useful without accidentally printing secrets.

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
  service and use `AnySqlBackendClient` in the app.
- SQLite insert parameters do not bind: pass positional values as
  `parameters: {'values': [...]}`.
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
