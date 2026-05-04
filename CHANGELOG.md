## 0.2.0

### Added

- Added `package:anysql/anysql_drivers.dart` with built-in real driver adapters
  for PostgreSQL, MySQL, SQLite, and MongoDB.
- Added `PostgresAnySqlDriver` backed by `package:postgres`.
- Added `MysqlAnySqlDriver` backed by `package:mysql_client`.
- Added `SqliteAnySqlDriver` backed by `package:sqlite3`.
- Added `MongodbAnySqlDriver` backed by `package:mongo_dart`.
- Added real in-memory SQLite coverage for query and transaction behavior.
- Added generated-file analysis tests so generated options files must compile.
- Added CLI integration tests for `init`, `configure`, and invalid SQLite flags.
- Added `doc/driver_guide.md` with built-in driver usage examples.
- Added a driver capability matrix to the README for PostgreSQL, MySQL,
  SQLite, and MongoDB.
- Added clearer error and debugging documentation for `AnySqlException`
  subclasses.
- Added ecosystem notes that explain how `anysql` differs from ORMs, query
  builders, and direct database drivers.
- Added SQLite tests for wrapped query failures and closed-connection behavior.

### Changed

- Updated README usage examples for the built-in drivers.
- Added README badges for pub.dev, Dart SDK, license, and GitHub.
- Reworked the README into a more practical getting-started guide with a
  copyable in-memory SQLite example.
- Updated the example to include a real SQLite connection alongside the fake
  direct and backend/proxy examples.
- Improved the example README so users can tell which parts use fake
  demo clients and which part uses a real driver.
- Updated the runnable example output to show the direct-driver,
  backend/proxy, and real SQLite patterns separately.
- Wrapped built-in driver query failures in `AnySqlQueryException` with a short
  statement preview.
- Wrapped closed PostgreSQL, MySQL, and MongoDB connection usage in
  `AnySqlConnectionException`.

### Fixed

- Prevented SQLite options generation from emitting invalid network-only
  constructor arguments.
- Added CLI validation for unsupported SQLite options like `--host`, `--port`,
  `--username`, `--password-env`, and `--ssl`.
- Fixed documentation snippets that used built-in drivers without showing the
  required `package:anysql/anysql_drivers.dart` import.
- Clarified that Flutter mobile and web apps should use a backend/proxy instead
  of shipping production database credentials.
- Clarified SQLite positional parameter usage with `parameters: {'values': [...]}`.

## 0.1.1

### Added

- Added `dart run anysql init` to generate a starter
  `lib/anysql_options.dart` file with editable dummy options for PostgreSQL,
  MySQL, SQLite, and MongoDB.
- Added `AnySqlOptionsFile.byDialect` to the generated starter file.

### Fixed

- Escaped generated Dart string literals more safely for values containing
  dollar signs, quotes, and control characters.
- Clarified CLI help text for `init` and `configure` class-name defaults.

## 0.1.0

Initial public release of `anysql`.

### Added

- Core `AnySql` client for direct driver lookup and connection opening.
- `AnySqlConfig` with convenience constructors for PostgreSQL, MySQL, SQLite,
  MongoDB, and custom driver options.
- Driver, connection, transaction, backend client, result, and exception
  contracts for database packages to implement.
- Firebase-style setup generator available through `dart run anysql configure`.
- Generated `AnySqlOptions` support for direct drivers and backend/proxy
  clients.
- Defensive copying for config options and result rows.
- Public example covering direct and backend connection flows.

### Security

- Generated setup files use `String.fromEnvironment` for passwords through
  `--password-env`.
- The CLI intentionally does not support inline password generation.
