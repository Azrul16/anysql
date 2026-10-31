## 1.0.1

### Fixed

- Restricted HTTP backend config metadata to host, port, database, username,
  and SSL status. Driver options, including credential-bearing MongoDB URIs,
  are no longer forwarded. Backends must configure driver options server-side.
- Replaced SQLite SQL-prefix heuristics with prepared statements so commented
  reads, EXPLAIN, CTE writes, and RETURNING statements execute correctly.
- Reported SQLite affected rows for CTE and RETURNING writes, while avoiding
  stale counts on reads and schema changes.
- Rejected parent-connection queries, closure, nested transactions, and
  overlapping transaction starts during SQLite, PostgreSQL, and MySQL
  transactions. Pending parent queries must finish before a transaction starts.
- Formatted the external-driver tests to satisfy CI.

### Added

- Regression coverage for backend credential filtering, SQLite query results,
  write metadata, transaction guards, and connection reuse after rollback.
- Flutter consumer build checks for Android, iOS, Linux, macOS, and Windows.
- A migration guide for upgrading from 0.3.x.

### Migration

- Configure database driver options on the backend; HTTP requests no longer
  contain a `config.options` field.
- Use the callback's transaction executor or transaction store for all work
  inside a transaction. Await pending queries before starting a transaction.
- SQLite query calls execute one prepared statement at a time. Split SQL
  scripts into individual calls. Returned write rows now include affected-row
  counts; reads no longer expose a previous write's insert ID.

## 0.3.1

### Added

- Added optional driver capability declarations for transactions, returned
  write rows, upserts, and native aggregation.
- Added `AnySqlUnsupportedException` for optional operations unavailable on a
  driver, backend, or store dialect.
- Added `AnySqlStore.transaction()` with a transaction-scoped keyword store.
- Added store field projection plus `count()` and `exists()` query helpers.
- Added bulk `addAll()` writes and `whereNotIn` filters for SQL and MongoDB.

### Changed

- Unsupported MongoDB and HTTP backend transactions now throw
  `AnySqlUnsupportedException` instead of a connection exception.

### Fixed

- Declared the external-integration test tag so local test runs are warning-free.
- Standardized driver selection, connection lifecycle, and completed
  transaction failures on their specific exception types.
- Made offset-only store queries valid for MySQL and SQLite by emitting their
  dialect-specific unlimited limit clauses.
- Changed SQLite document `set` operations to use `ON CONFLICT DO UPDATE`
  instead of the delete-and-insert behavior of `INSERT OR REPLACE`.

## 0.3.0

### Added

- Added `AnySqlStore.close()` plus generated `withStore` and
  `withBackendStore` helpers for safer connection cleanup.
- Added GitHub Actions CI with live PostgreSQL, MySQL, and MongoDB
  service-container smoke tests.

### Changed

- Kept core contracts, HTTP backend, and built-in direct drivers in the single
  `anysql` package.
- Updated the Dart SDK constraint to `^3.10.0` for modern SQLite native-asset
  support.

### Fixed

- Made the SQLite driver return rows for statements that use `RETURNING`, while
  ignoring `returning` inside comments and string literals.
- Added clear MySQL config validation for `collation` and `timeoutMs` driver
  options.

## 0.2.2

### Added

- Added `AnySqlStore`, a Firebase-style keyword API over `AnySqlConnection`
  with `collection`, `where`, `orderBy`, `limit`, `offset`, `doc`, `add`,
  `set`, `update`, and `delete` operations for SQL and MongoDB dialects.
- Added `connection.store(dialect: ...)` plus `first()` helpers for easier
  single-row and single-document reads.
- Improved `dart run anysql`/`dart run anysql setup` so setup asks only for one
  included database and generates a focused options file with store helpers.
- Made `dart run anysql` a short alias for interactive setup.
- Reworked README and example docs so the keyword-store workflow is easier to
  learn on pub.dev and GitHub.
- Added keyword-store examples and SQLite coverage for real CRUD behavior.

## 0.2.1

### Added

- Added `dart run anysql setup` for interactive options file generation after
  installing the package.
- Added `AnySqlParameters` helpers for named, positional, and document-style
  query parameters.
- Added opt-in live smoke tests for PostgreSQL, MySQL, and MongoDB drivers.

### Changed

- Removed advertised web platform support while the package includes native
  direct-driver dependencies.
- Clarified transaction behavior and the shared contract's limits around
  nested transactions and savepoints.
- Reused a shared internal statement preview helper across built-in drivers.
- Updated README, driver guide, example docs, and examples for the new setup
  and parameter helper flows.

### Fixed

- Fixed HTTP backend client ownership so internally managed clients are scoped
  per connection while injected clients remain caller-owned.
- Changed config validation failures to throw `AnySqlConfigException`.
- Hardened HTTP backend response decoding for malformed rows, metadata, and
  affected row counts.

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
- Added MongoDB adapter support for `insertMany`, `updateMany`, `replaceOne`,
  `deleteMany`, and `count`.
- Added `AnySqlHttpBackendClient` for JSON HTTP backend/proxy connections.
- Added tests for HTTP backend requests, result decoding, missing backend URLs,
  failed HTTP responses, and closed backend connections.

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
- Changed unsupported MongoDB transactions to throw a typed
  `AnySqlConnectionException` with a stable explanation.
- Completed the example and test fake transaction implementations so no sample
  connection code is left as an unimplemented stub.
- Replaced the unused `shelf` dependency with `http` for the built-in backend
  client.

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
- Options generator available through `dart run anysql configure`.
- Generated `AnySqlOptions` support for direct drivers and backend/proxy
  clients.
- Defensive copying for config options and result rows.
- Public example covering direct and backend connection flows.

### Security

- Generated setup files use `String.fromEnvironment` for passwords through
  `--password-env`.
- The CLI intentionally does not support inline password generation.
