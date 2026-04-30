# anysql

`anysql` is a Dart and Flutter-friendly database abstraction for working with
SQL and NoSQL backends through one consistent API.

The package currently provides the core contracts for drivers, connections,
transactions, configuration, normalized results, and exceptions. Concrete
drivers for PostgreSQL, MySQL, SQLite, MongoDB, and other backends can
implement the same interface without changing application code.

This package does not ship concrete database drivers yet. It gives you the
shared contracts, generated setup file, and backend/proxy hook that driver
packages can build on.

> For mobile and web apps, avoid connecting directly to production databases
> with embedded credentials. Prefer a secure backend API or trusted proxy for
> user-facing apps.

## Features

- One connection entry point with `AnySql.connect`.
- Shared config model for PostgreSQL, MySQL, SQLite, MongoDB, and custom drivers.
- Driver and connection interfaces for database-specific implementations.
- Normalized `AnySqlResult` for rows, affected row counts, insert IDs, and metadata.
- Transaction contract for drivers that support transactional work.

## Usage

Generate an app options file:

```sh
dart run anysql configure \
  --dialect postgres \
  --host localhost \
  --database app \
  --username postgres \
  --password-env ANYSQL_PASSWORD \
  --backend-url https://api.example.com/anysql \
  --backend-header x-api-key=dev-key
```

This creates `lib/anysql_options.dart`, similar to Firebase options:

```dart
import 'anysql_options.dart';

final connection = await DefaultAnySqlOptions.connect(
  driver: myPostgresDriver,
);
```

For mobile or web apps, point the generated file at your backend and connect
through a backend client:

```dart
final connection = await DefaultAnySqlOptions.connectBackend(
  client: myBackendClient,
);
```

Pass the password with Dart defines instead of committing secrets:

```sh
flutter run --dart-define=ANYSQL_PASSWORD=your_password
```

You can still configure connections manually:

```dart
import 'package:anysql/anysql.dart';

final config = AnySqlConfig.postgres(
  host: 'localhost',
  database: 'app',
  username: 'postgres',
  password: const String.fromEnvironment('ANYSQL_PASSWORD'),
);

final connection = await AnySql.connect(
  config: config,
  driver: myPostgresDriver,
);

final result = await connection.query(
  'select * from users where id = @id',
  parameters: {'id': 1},
);

print(result.firstOrNull);

await connection.close();
```

You can also register drivers once and let `anysql` pick the first compatible
driver for a config:

```dart
final anySql = AnySql([
  myPostgresDriver,
  myMysqlDriver,
]);

final connection = await anySql.open(config);
```

## Creating a Driver

```dart
import 'package:anysql/anysql.dart';

final class PostgresAnySqlDriver extends AnySqlDriverBase {
  const PostgresAnySqlDriver() : super('postgres', AnySqlDialect.postgres);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    // Create and return an AnySqlConnection backed by your PostgreSQL client.
    throw UnimplementedError();
  }
}
```

## Roadmap

- PostgreSQL driver package.
- MySQL driver package.
- SQLite driver package for local Flutter storage.
- MongoDB-style document driver contract refinements.
- Connection pooling helpers.
- Safer mobile/web guidance and backend proxy examples.

## Reliability Notes

- `AnySqlConfig` validates obvious invalid values like empty hosts and invalid
  ports.
- Passwords are masked in `AnySqlConfig.toString()`.
- Generated options can read passwords from `String.fromEnvironment`, so secrets
  do not need to be written into source files.
- Config options and result rows are defensively copied so outside code cannot
  mutate them after creation.
- Drivers are explicit and swappable; `anysql` does not hide which backend
  client is actually doing the database work.
