# anysql Driver Guide

This guide shows how to use `anysql` with the built-in real database drivers
and how to structure generated options files in Dart or Flutter projects.

## Imports

Use the core API for configuration, results, and connection contracts:

```dart
import 'package:anysql/anysql.dart';
```

Use the driver library when your app connects directly to a database:

```dart
import 'package:anysql/anysql_drivers.dart';
```

For Flutter mobile and web apps, prefer a backend/proxy connection instead of
shipping production database credentials in the app bundle.

## Generate Options

Create starter options for PostgreSQL, MySQL, SQLite, and MongoDB:

```sh
dart run anysql init
```

Generate one PostgreSQL options file:

```sh
dart run anysql configure \
  --dialect postgres \
  --host localhost \
  --database app \
  --username postgres \
  --password-env ANYSQL_PASSWORD
```

Pass secrets at runtime:

```sh
dart -DANYSQL_PASSWORD=your_password run
```

## SQLite

SQLite is the easiest driver to try because it can run in memory:

```dart
final connection = await AnySql.connect(
  config: AnySqlConfig.sqlite(database: ':memory:'),
  driver: const SqliteAnySqlDriver(),
);

await connection.query('create table users (id integer primary key, name text)');
await connection.query(
  'insert into users (name) values (?)',
  parameters: {
    'values': ['Ada'],
  },
);

final users = await connection.query('select * from users');
print(users.rows);

await connection.close();
```

SQLite positional parameters are passed with the special `values` list. If you
pass a normal map without `values`, the driver uses the map values in insertion
order.

SQLite query failures are wrapped as `AnySqlQueryException` with the original
driver error attached as `cause`.

## PostgreSQL

PostgreSQL uses named parameters through `package:postgres`:

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

final result = await connection.query(
  'select id, email from users where id = @id',
  parameters: {'id': 1},
);
```

PostgreSQL query failures are wrapped as `AnySqlQueryException`. A closed
connection fails with `AnySqlConnectionException`.

## MySQL

MySQL uses the placeholder behavior from `package:mysql_client`:

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

Set driver-specific MySQL options with `AnySqlConfig.options`:

```dart
final config = AnySqlConfig.mysql(
  host: 'localhost',
  database: 'app',
  options: {
    'collation': 'utf8mb4_general_ci',
    'timeoutMs': 10000,
  },
);
```

MySQL query failures are wrapped as `AnySqlQueryException`. A closed connection
fails with `AnySqlConnectionException`.

## MongoDB

MongoDB uses statement names in `collection.operation` format:

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

Supported MongoDB operations are:

- `collection.find`
- `collection.findOne`
- `collection.insertOne`
- `collection.updateOne`
- `collection.deleteOne`
- `collection.aggregate`

MongoDB operation failures are wrapped as `AnySqlQueryException`. Invalid
AnySQL command shapes, such as missing `filter` or `document` maps, remain
plain `AnySqlException` values so callers can distinguish local usage mistakes
from database failures.

You can also pass a full MongoDB URI through config options:

```dart
final config = AnySqlConfig.mongodb(
  host: 'localhost',
  database: 'app',
  options: {
    'uri': 'mongodb://localhost:27017/app',
  },
);
```

## Registered Drivers

Register all built-in drivers and let `anysql` choose the first compatible one:

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

## Testing

This package includes generated-file tests that write options files and run
`dart analyze` on them. It also includes CLI integration tests for:

- `dart run anysql init`
- `dart run anysql configure --dialect postgres ...`
- invalid SQLite network flags

SQLite is tested with a real in-memory database. PostgreSQL, MySQL, and MongoDB
live integration tests require external database servers and credentials.

## Ecosystem Notes

The built-in drivers are intentionally adapters, not a full ORM or query
builder. Packages such as Drift focus on reactive, type-safe SQLite
persistence; packages such as Laconic focus on fluent SQL building; and direct
drivers such as `postgres`, `mysql_client`, `sqlite3`, and `mongo_dart` expose
database-specific behavior directly. `anysql` sits underneath those kinds of
choices as a small common contract for configuration, connection lifetime,
results, backend proxy access, and driver swapping.
