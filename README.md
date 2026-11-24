# AnySQL

AnySQL is a Dart database toolkit for SQLite, PostgreSQL, MySQL, and MongoDB.
Use a collection-style API for common reads and writes, pass parameterized SQL
or MongoDB commands to a direct driver, or connect a Flutter app to your own
HTTP backend.

[Examples](https://pub.dev/packages/anysql/example) ·
[API reference](https://pub.dev/documentation/anysql/latest/) ·
[Driver guide](https://github.com/Azrul16/anysql/blob/main/doc/driver_guide.md) ·
[Changelog](https://pub.dev/packages/anysql/changelog)

## Contents

- [Install and generate options](#install-and-generate-options)
- [Quick start with SQLite](#quick-start-with-sqlite)
- [Choose a connection](#choose-a-connection)
- [Query and write records](#query-and-write-records)
- [Run raw queries and transactions](#run-raw-queries-and-transactions)
- [Configure direct drivers](#configure-direct-drivers)
- [Connect a Flutter app over HTTP](#connect-a-flutter-app-over-http)
- [CLI reference](#cli-reference)
- [Troubleshooting](#troubleshooting)
- [Runnable examples](#runnable-examples)

## Install and generate options

Run these commands from the directory that contains your app's `pubspec.yaml`.

| App | Install |
| --- | --- |
| Dart | `dart pub add anysql` |
| Flutter | `flutter pub add anysql` |

Then start the setup wizard:

```sh
dart run anysql
```

Choose PostgreSQL, MySQL, SQLite, or MongoDB. Enter a number or a database
name. Pressing Enter selects PostgreSQL. The wizard creates
`lib/anysql_options.dart` with a `DefaultAnySqlOptions` class for your chosen
database. Open the generated file and fill in its placeholders. The wizard
writes a configuration file. Your code opens the connection when it uses the
generated helpers.

AnySQL requires Dart 3.10 or newer. Native Flutter targets are Android, iOS,
Linux, macOS, and Windows. This package targets Dart and native Flutter apps.

## Quick start with SQLite

Choose **SQLite** in the wizard, leave the default `app.sqlite` path, and save
this program as `lib/quick_start.dart` next to `anysql_options.dart`.

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

import 'anysql_options.dart';

Future<void> main() async {
  await DefaultAnySqlOptions.withStore(
    driver: const SqliteAnySqlDriver(),
    action: (db) async {
      await db.connection.query(
        'create table if not exists users ('
        'id integer primary key, email text not null, active integer not null)',
      );

      final users = db.collection('users');
      await users.doc(1).set({'email': 'ada@example.com', 'active': 1});

      final result = await users
          .where('active', isEqualTo: 1)
          .select(['id', 'email'])
          .get();

      print(result.rows);
    },
  );
}
```

```sh
dart run lib/quick_start.dart
```

This prints `[{id: 1, email: ada@example.com}]`. The helper closes the store
when the callback finishes, including when it throws. To try the same API
without keeping a database file, run the [in-memory example](#runnable-examples).

## Choose a connection

| Use case | Connection |
| --- | --- |
| Local storage, a Dart CLI, or tests | SQLite with a writable file path or `:memory:` |
| A trusted server, worker, or CLI accessing a database | Direct PostgreSQL, MySQL, or MongoDB driver |
| A Flutter app accessing shared server data | `AnySqlHttpBackendClient` connected to your API |
| A database or transport you provide | Implement `AnySqlDriver` or `AnySqlBackendClient` |

Import `package:anysql/anysql.dart` for configuration, results, the keyword
store, and the HTTP client. Import `package:anysql/anysql_drivers.dart` when
opening a direct connection with a built-in driver.

`store(dialect: ...)` uses the supplied dialect to generate commands. Match it
to the database your connection serves. The generated `connectStore()` and
`withStore()` helpers use the dialect from your configuration. Close manually
opened connections and stores when you're done.

## Query and write records

A collection maps to a SQL table or MongoDB collection. An ID lookup uses
`id` by default and requires a non-null value. For MongoDB's generated IDs,
specify `idField: '_id'`.

```dart
final users = db.collection('users');

final page = await users
    .where('active', isEqualTo: 1)
    .select(['id', 'email'])
    .orderBy('id')
    .limit(20)
    .offset(20)
    .get();

final user = await users.doc(1).first();
print(user?['email']);
```

| Task | API |
| --- | --- |
| Read rows or documents | `get()` returns a result, and `first()` returns a record or `null` |
| Filter | `where()` supports equality, comparisons, `whereIn`, and `whereNotIn`. Chained calls use AND |
| Project and paginate | `select()`, `orderBy()`, `limit()`, and `offset()` |
| Count matches | `count()` and `exists()` apply the filters without pagination |
| Insert | `add(data)` or `addAll(records)`. Bulk records must have the same fields |
| Edit or delete by ID | `doc(id).update(data)` or `doc(id).delete()` |

Sort by a unique field for stable ordering when paginating. Collection, table,
and field names in the keyword API must start with a letter or underscore and
contain only letters, digits, and underscores.

`limit(0)` produces an empty page. Calls to `first()` return `null` on that
page. Use `where()` on a nullable field to find rows with null values.

Obtain document references for writes directly from the collection, such as
`db.collection('users').doc(1)`. Reads can use a filtered reference. Calling
`set()`, `update()`, or `delete()` on a filtered reference throws before
sending a database command.

### What `set()` does on each database

- **SQLite and PostgreSQL:** inserts or updates by ID. Existing rows retain
  omitted columns if the upsert succeeds. Supply all required insert columns
  that lack defaults, even when the row exists.
- **MySQL:** inserts or updates the row with the requested ID. It requires a
  unique ID field and a transaction-capable connection. A conflict on another
  unique key surfaces as an error.
- **MongoDB:** inserts or replaces the document. Replacement drops omitted
  fields apart from MongoDB's `_id`.

Use `update()` to change selected fields on an existing record.

MongoDB write failures throw `AnySqlQueryException`. A bulk write may have
applied some records before it failed. Inspect the counts and server responses
on the exception's `cause` before deciding which records to retry.

## Run raw queries and transactions

Call `connection.query()` for schema operations, joins, or database-specific
commands. Use the binding syntax for your driver:

| Driver | Statement placeholder or command | Parameters |
| --- | --- | --- |
| SQLite | `where id = ?` | `AnySqlParameters.positional([1])` |
| PostgreSQL | `where id = @id` | `AnySqlParameters.named({'id': 1})` |
| MySQL | `where id = :id` | `AnySqlParameters.named({'id': 1})` |
| MongoDB | `users.findOne` | `AnySqlParameters.document({'filter': {'id': 1}})` |

Reads expose `rows` and `firstOrNull`. Writes expose `affectedRows` and
`lastInsertId` when supported by the driver. SQLite and PostgreSQL support
`RETURNING` to read values produced by a write.

Use a transaction on a direct SQLite, PostgreSQL, or MySQL connection when
several writes belong together:

```dart
await db.transaction((tx) async {
  final accounts = tx.collection('accounts');
  await accounts.doc(1).update({'balance': 90});
  await accounts.doc(2).update({'balance': 110});
});
```

Use the callback's transaction store or executor for all work inside the
transaction. Await its operations. AnySQL commits on successful completion
and rolls back when the callback throws. Built-in MongoDB and HTTP connections
do not provide managed transactions.

An InnoDB deadlock rolls back the whole MySQL transaction. The transaction
executor rejects further work, and the transaction call reports the original
error even if the callback caught it. If your app retries, start a new
transaction so all writes are attempted together again.

## Configure direct drivers

`AnySql.connect(config: ..., driver: ...)` opens a direct connection. Match the
config constructor and driver:

| Database | Config | Driver | Backing package |
| --- | --- | --- | --- |
| SQLite | `AnySqlConfig.sqlite(database: 'app.sqlite')` | `SqliteAnySqlDriver` | `sqlite3` |
| PostgreSQL | `AnySqlConfig.postgres(host: ..., database: ...)` | `PostgresAnySqlDriver` | `postgres` |
| MySQL | `AnySqlConfig.mysql(host: ..., database: ...)` | `MysqlAnySqlDriver` | `mysql_dart` |
| MongoDB | `AnySqlConfig.mongodb(host: ..., database: ...)` | `MongodbAnySqlDriver` | `mongo_dart` |

For a trusted Dart backend that supplies credentials at runtime, use
`Platform.environment` from `dart:io` or your application's secret store.
The CLI's `--password-env` flag generates a `String.fromEnvironment` lookup,
which reads a **Dart define**. For example, use
`dart run -DANYSQL_PASSWORD=... bin/server.dart` with a config generated for
that key.

On PostgreSQL and MySQL, `sslEnabled: true` enables TLS with server certificate
verification. For a private CA, pass a Dart `SecurityContext` through
`options['securityContext']`. MySQL also accepts `collation` and `timeoutMs`.
MongoDB accepts a full connection URI through `options['uri']`. Keep these
settings and credentials on trusted systems.

Register several drivers with `AnySql([...])` and open a config with
`client.open(config)`. AnySQL selects the first registered driver that
supports the config. Use `driver.capabilities` to check optional features such
as transactions, returned write rows, upserts, and aggregation.

## Connect a Flutter app over HTTP

Keep production database credentials on your server. In the generated options
file, set `backendUri` to your API endpoint. The app's database dialect should
match the database served by that endpoint.

```dart
import 'package:anysql/anysql.dart';

import 'anysql_options.dart';

Future<Map<String, Object?>?> loadUser(int id) {
  return DefaultAnySqlOptions.withBackendStore(
    client: AnySqlHttpBackendClient(),
    action: (db) => db.collection('users').doc(id).first(),
  );
}
```

The client sends a JSON POST with `dialect`, `config`, `statement`, and
`parameters`. Config metadata includes host, port, database, username, and
TLS status. Database passwords and driver-specific options stay out of the
request. Authenticate the app's callers and authorize operations on your
server. For a backend that exposes named operations, use
`connection.query('users.findById', parameters: {'id': id})` with a matching
server handler. Do not forward arbitrary client-supplied SQL to a database.

HTTP parameters must be JSON-encodable, such as strings, numbers, booleans,
null, lists, and maps with string keys. Convert values such as `DateTime` to
the format your server expects, for example
`createdAfter.toUtc().toIso8601String()`. Unsupported values throw
`AnySqlQueryException` before the request is sent.

An endpoint that returns rows can respond with:

```json
{
  "rows": [{"id": 1, "email": "ada@example.com"}],
  "affectedRows": 0,
  "lastInsertId": null,
  "metadata": {"columns": ["id", "email"]}
}
```

Use a custom `AnySqlBackendClient` for a different protocol or authentication
workflow. Perform atomic multi-step writes inside an authorized server command.

## CLI reference

| Command | Result |
| --- | --- |
| `dart run anysql` or `dart run anysql setup` | Interactive setup for one database |
| `dart run anysql init` | Sample options for all four built-in databases |
| `dart run anysql configure --help` | Flags for scripted setup |
| `dart run anysql --help` | Full CLI help |

For example, to generate a SQLite configuration without prompts:

```sh
dart run anysql configure --dialect sqlite --database app.sqlite
```

For PostgreSQL:

```sh
dart run anysql configure --dialect postgres --host localhost \
  --database app --username app_user --password-env ANYSQL_PASSWORD
```

`--output` sets the destination, `--class-name` changes the generated class,
and `--backend-url` sets the backend endpoint for `configure`. The default
destination is `lib/anysql_options.dart`. Use `--force` only when you intend
to overwrite an existing file.

To install the wizard globally, run `dart pub global activate anysql`, then
run `dart pub global run anysql` from your application directory.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| The CLI cannot find the package | Add AnySQL to your app and run the command beside its `pubspec.yaml` |
| The options file already exists | Edit it or set a separate `--output` path |
| A built-in driver class is missing | Import `package:anysql/anysql_drivers.dart` |
| SQLite reports a missing table | Create the schema before querying and check which database path you opened |
| A raw query rejects a parameter | Check the placeholder syntax for the active driver |
| The HTTP client reports a missing backend URL | Set `backendUri` in the generated options |
| The parent connection is busy in a transaction | Use the transaction executor passed to the callback |

## Runnable examples

Run `dart pub get` from a checkout of the repository, then choose a program.
The SQLite examples run in memory. The HTTP example uses a simulated server.

| Source | Run |
| --- | --- |
| [Keyword store](https://github.com/Azrul16/anysql/blob/main/example/keyword_store.dart) | `dart run example/keyword_store.dart` |
| [Direct SQL](https://github.com/Azrul16/anysql/blob/main/example/direct_queries.dart) | `dart run example/direct_queries.dart` |
| [Transactions](https://github.com/Azrul16/anysql/blob/main/example/transactions.dart) | `dart run example/transactions.dart` |
| [HTTP backend](https://github.com/Azrul16/anysql/blob/main/example/http_backend.dart) | `dart run example/http_backend.dart` |
| [Custom driver](https://github.com/Azrul16/anysql/blob/main/example/custom_driver.dart) | `dart run example/custom_driver.dart` |

Run `dart run example/run_all.dart` to execute all five examples. The
[Example tab](https://pub.dev/packages/anysql/example) includes an in-memory
walkthrough and links to each program.

## Project links

- [Source repository](https://github.com/Azrul16/anysql)
- [Driver guide](https://github.com/Azrul16/anysql/blob/main/doc/driver_guide.md)
- [Migration guide from 0.3.x](https://github.com/Azrul16/anysql/blob/main/doc/migration_1_0_1.md)
- [Issue tracker](https://github.com/Azrul16/anysql/issues)
- [MIT license](https://github.com/Azrul16/anysql/blob/main/LICENSE)
