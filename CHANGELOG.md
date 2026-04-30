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
