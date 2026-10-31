# Upgrade to anysql 1.0.1

Set `anysql: ^1.0.1` in your dependencies, then run `dart pub get` or
`flutter pub get`. Dart 3.10 or newer is required.

## Backend config payload

HTTP requests include only `host`, `port`, `database`, `username`, and
`sslEnabled` inside `config`. Passwords and all driver options are excluded.
Configure MongoDB connection URIs, tokens, and other driver options on the
server. Backends that read `config.options` must migrate before upgrading their
clients. Query parameters and explicit backend headers still carry the values
you supply; this change filters config metadata only.

## Transactions

Await outstanding parent queries before starting a transaction. Inside the
callback, use the transaction argument rather than the parent connection:

```dart
await connection.transaction((tx) async {
  await tx.query('update accounts set balance = balance - 10 where id = 1');
  await tx.query('update accounts set balance = balance + 10 where id = 2');
});
```

For keyword operations, use the store supplied to `store.transaction`.
SQLite, PostgreSQL, and MySQL reject parent queries, closure, and nested
transactions until the callback finishes, including after a manual commit or
rollback. Automatic commit and rollback behavior remains available. Accessing
an exposed underlying database handle bypasses these protections.

## SQLite results

Each query executes one prepared SQL statement. Split multi-statement scripts
into separate awaited calls. Queries starting with comments, CTE writes, and
writes using `RETURNING` now return the appropriate rows and affected counts.
Reads report zero affected rows and no insert ID. Schema changes do not reuse
an earlier write's affected count. `lastInsertId` is reported when SQLite's
insert row ID changes; use `RETURNING id` for an authoritative write identifier.

## Platforms and validation

The package advertises Android, iOS, Linux, macOS, and Windows. CI builds a
Flutter consumer for each target and runs Dart tests. Browser/web support is
not advertised. Platform builds check compilation, while live PostgreSQL,
MySQL, and MongoDB tests require the environment variables documented in
`test/anysql_external_drivers_test.dart`.
