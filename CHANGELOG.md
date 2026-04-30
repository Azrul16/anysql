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
