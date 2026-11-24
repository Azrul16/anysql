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

## Contents

- [Install and generate options](#quick-start)
- [Run your first SQLite query](#try-it-now)
- [Choose a connection for your app](#choose-a-connection)
- [Read and write with the keyword API](#keyword-store-api)
- [Configure a database](#generate-an-options-file)
- [Use an HTTP backend from Flutter](#flutter-mobile-and-backend-access)
- [Compare drivers](#driver-capability-matrix)
- [Run raw queries](#raw-query-escape-hatch) and [use transactions](#transactions)
- [Register multiple or custom drivers](#register-multiple-drivers)
- [Use the CLI](#cli-reference)
- [Troubleshoot](#common-errors-users-hit)
- [Run examples by feature](#runnable-examples)

## Compatibility

Requires Dart 3.10 or newer. Native Flutter targets are Android, iOS, Linux,
macOS, and Windows; browser/web support is not advertised. CI builds a Flutter
consumer app for each native target, alongside Dart unit and live-driver tests.
Build checks verify compilation; they do not replace testing on your devices.

The repository commits `pubspec.lock` for reproducible development and CI.
Resolve lockfile updates with Dart 3.10.0 so the locked dependencies remain
compatible with the minimum supported SDK. CI uses
`dart pub get --enforce-lockfile` on both SDK versions. Applications consuming
this package resolve their own dependencies from `pubspec.yaml`.

Upgrading from 0.3.x? Read the [migration guide](doc/migration_1_0_1.md) for
backend payload and transaction changes.

For changes to MySQL connections, TLS, and transactions in 1.0.2, see the
[changelog](CHANGELOG.md).

## Quick Start

Install:

```sh
dart pub add anysql
```

For Flutter:

```sh
flutter pub add anysql
```

Or add the current release directly to `pubspec.yaml`:

```yaml
dependencies:
  anysql: ^1.0.3
```

Then run `dart pub get` or `flutter pub get`. Import the core API from
`package:anysql/anysql.dart`; trusted applications that connect directly also
import `package:anysql/anysql_drivers.dart`.

From your app's root directory, where its `pubspec.yaml` lives, run the setup
wizard to create `lib/anysql_options.dart`:

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

Press Enter to select PostgreSQL, or enter a number or database name. The
wizard writes one configuration with a `DefaultAnySqlOptions` class. Open the
file and set the values for your database. The wizard creates configuration
code. Your app opens the database when it calls a connection helper.

If you selected SQLite, create `lib/quick_start.dart` beside the generated
options file. This example creates a table and runs a keyword-store query.

```dart
import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';

import 'anysql_options.dart';

Future<void> main() async {
  final users = await DefaultAnySqlOptions.withStore(
    driver: const SqliteAnySqlDriver(),
    action: (db) async {
      await db.connection.query(
        'create table if not exists users (id integer primary key, email text)',
      );
      return db.collection('users').limit(20).get();
    },
  );

  print(users.rows);
}
```

Run it with `dart run lib/quick_start.dart`. A new database returns an empty
list. The in-memory tutorial below shows how to insert and read a record.

For Flutter apps, keep database credentials on your backend and connect through
your API:

```dart
import 'package:anysql/anysql.dart';

import 'anysql_options.dart';

final db = await DefaultAnySqlOptions.connectBackendStore(
  client: AnySqlHttpBackendClient(),
);

try {
  final user = await db.collection('users').doc(1).first();
} finally {
  await db.close();
}
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

## Choose a connection

| Your app | Start here | Where the database lives |
| --- | --- | --- |
| Dart CLI, test, or local Flutter app storing data on the device | SQLite driver | In memory or in a writable file |
| Server, worker, or CLI connecting to an existing database | Direct PostgreSQL, MySQL, or MongoDB driver | On your database server |
| Flutter app accessing shared data | HTTP backend client | Behind your application server |
| App using another database or protocol | Custom driver or backend client | Wherever your adapter connects |

Use the keyword store for collection reads and simple writes. Use the same
connection's `query()` for database-specific statements, schema changes, or
queries that need joins.

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

Run keyword operations atomically on drivers that declare transaction support:

```dart
await db.transaction((transaction) async {
  await transaction.collection('accounts').doc(1).update({'balance': 90});
  await transaction.collection('accounts').doc(2).update({'balance': 110});
});
```

Supported keyword operations:

- `collection(name).get()`
- `select(fields)`, `count()`, and `exists()`
- `where(field, isEqualTo: value)`
- `where(field, isNotEqualTo: value)`
- `where(field, isLessThan: value)`
- `where(field, isLessThanOrEqualTo: value)`
- `where(field, isGreaterThan: value)`
- `where(field, isGreaterThanOrEqualTo: value)`
- `where(field, whereIn: values)`
- `where(field, whereNotIn: values)`
- `orderBy(field, descending: true)`
- `limit(count)` and `offset(count)`
- `first()` to read the first matching row or document
- `add(data)` and `addAll(data)` for inserts
- `doc(id).get()`, `doc(id).set(data)`, `doc(id).first()`,
  `doc(id).update(data)`, and `doc(id).delete()`

`doc(id).set(data)` inserts a missing record. For an existing record,
PostgreSQL, MySQL, and SQLite update the supplied columns and preserve omitted
columns. MongoDB replaces the document, dropping omitted fields other than
`_id`. Supply values sufficient for a SQL insert, including required columns
without defaults. PostgreSQL and SQLite check those requirements even for an
existing record. Use `doc(id).update(data)` for partial edits to existing
records.

MySQL `set()` requires a unique ID field and a transaction-capable connection
to lock the target row before writing. The built-in HTTP backend exposes no
transaction support, so a MySQL-backed HTTP app can expose an authorized
server-side command that runs the operation on a direct MySQL connection.

SQL identifiers are validated before commands are built. Collection/table and
field names must use letters, numbers, and underscores, starting with a letter
or underscore.

### Read one record or a page

```dart
final users = db.collection('users');
final user = await users.doc(1).first();
if (user != null) {
  print(user['email']);
}

final page = await users
    .select(['id', 'email'])
    .orderBy('id')
    .limit(20)
    .offset(20)
    .get();
print(page.rows);
```

`first()` returns `null` when no record matches. Sort by a unique field such
as `id` to give paginated results a stable order. Use chained `where()`
calls to combine filters with AND. `count()` and `exists()` use the filters
without applying the page's limit or offset.

### Insert multiple records

```dart
final result = await db.collection('users').addAll([
  {'email': 'ada@example.com', 'active': true},
  {'email': 'grace@example.com', 'active': false},
]);
print(result.affectedRows);
```

Use the same fields in each record. Drivers differ in what they can report
about generated IDs and affected rows. Use SQL `RETURNING` on drivers that
declare `returningRows` when you need the values produced by a write. With
MongoDB, pass `idField: '_id'` to `collection()` when looking up documents
by the generated MongoDB ID.

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
final users = await DefaultAnySqlOptions.withStore(
  driver: const SqliteAnySqlDriver(),
  action: (db) => db.collection('users').limit(20).get(),
);
```

and backend/proxy helpers for Flutter apps:

```dart
final db = await DefaultAnySqlOptions.connectBackendStore(
  client: AnySqlHttpBackendClient(),
);

try {
  final users = await db.collection('users').limit(20).get();
} finally {
  await db.close();
}
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
statement, parameters, and an explicit set of config metadata fields: `host`,
`port`, `database`, `username`, and `sslEnabled`. The config metadata excludes
`password` and all driver-specific `options`, which can contain credentials.

The backend endpoint must authenticate callers and authorize every operation.
Do not expose an unrestricted raw SQL proxy to untrusted applications.

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

Import `package:anysql/anysql_drivers.dart` to use direct drivers.

| Driver | Backing package | Best fit | Parameter style | Notes |
| --- | --- | --- | --- | --- |
| PostgreSQL | `postgres` | Dart servers, CLIs, workers | named `@id` parameters | Supports SSL through `sslEnabled` |
| MySQL | `mysql_dart` | Dart servers, CLIs, workers | Named map parameters | `options` supports `collation`, `timeoutMs`, and `securityContext` |
| SQLite | `sqlite3` | local native apps, CLIs, tests | positional `values` list | `:memory:` is ideal for tests and examples |
| MongoDB | `mongo_dart` | Dart servers, CLIs, workers | document maps | Uses `collection.operation` statement names |

The built-in direct drivers are intentionally thin adapters over established
database packages. They normalize results and errors, but they do not hide the
database engine or replace database-specific knowledge.

Drivers also declare optional features through `capabilities`:

```dart
const driver = SqliteAnySqlDriver();

if (driver.capabilities.transactions) {
  // It is safe to rely on connection.transaction().
}
```

The declared features are `transactions`, `returningRows`, `upsert`, and
`aggregation`. Existing third-party drivers that do not declare capabilities
receive the conservative `AnySqlCapabilities.none` value.

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

MySQL parameter behavior follows `package:mysql_dart`.

### TLS for PostgreSQL and MySQL

Set `sslEnabled: true` to require TLS and verify the server certificate and
hostname. Use the hostname on the certificate. If your database uses a
private certificate authority, configure its certificate in a Dart
`SecurityContext` and pass it through the driver options:

```dart
import 'dart:io';

import 'package:anysql/anysql.dart';

final trust = SecurityContext(withTrustedRoots: true)
  ..setTrustedCertificates('db-ca.pem');

final config = AnySqlConfig.postgres(
  host: 'db.example.com',
  database: 'app',
  sslEnabled: true,
  options: {'securityContext': trust},
);
```

Use the same `sslEnabled` and `options` fields on `AnySqlConfig.mysql`.

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
- `AnySqlUnsupportedException` when a driver or backend lacks an optional
  operation such as transactions.

Query exceptions include a short statement preview but not parameter values, so
logs are useful without accidentally printing secrets.

## Transactions

`AnySqlConnection.transaction` commits when the callback completes and rolls
back when it throws. The shared contract does not include nested transactions
or savepoints; if you need those, use the underlying database package directly
or add a custom driver behavior for your project.

For SQLite, PostgreSQL, and MySQL, use only the callback's transaction executor
(or transaction store) inside the callback. Parent connection queries, closing
that connection, and starting another transaction are rejected with
`AnySqlConnectionException` until the callback finishes. Await pending parent
queries before starting a transaction.

SQLite executes one statement per query call. Prepared statements handle leading
comments, CTEs, and `RETURNING`. Writes expose `affectedRows` even when they
return rows; reads report zero affected rows. Use returned primary-key columns
when you need reliable identifiers from writes.

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

Run the following commands from the application directory. To use the same
wizard from a globally installed CLI, activate it once and then run it in the
application directory:

```sh
dart pub global activate anysql
dart pub global run anysql
```

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

## Runnable examples

From a checkout of the [AnySQL repository](https://github.com/Azrul16/anysql),
run `dart pub get` once. Pick a standalone program based on what you want to
learn.

| Use case | Run from the repository root |
| --- | --- |
| Connect directly, bind SQL parameters, and read insert results | `dart run tool/examples/direct_queries.dart` |
| Insert and filter rows with the keyword store | `dart run tool/examples/keyword_store.dart` |
| Update two accounts within one transaction | `dart run tool/examples/transactions.dart` |
| Send a request through the HTTP client and inspect the JSON | `dart run tool/examples/http_backend.dart` |
| Implement and register a custom driver | `dart run tool/examples/custom_driver.dart` |

The direct SQL, keyword store, and transaction programs use in-memory SQLite.
The HTTP example simulates its server locally, and the custom driver example
uses an in-process adapter. Run `dart run tool/examples/run_all.dart` to try
them together.

## More documentation

See the
[driver guide](https://github.com/Azrul16/anysql/blob/main/doc/driver_guide.md)
for longer direct-driver documentation.

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
