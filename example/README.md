# anysql Example

This example is designed to run immediately after `dart pub get`.

```sh
dart run example/main.dart
```

It prints three results:

- a direct connection through a fake PostgreSQL-style driver,
- a backend/proxy connection through a fake backend client,
- a real SQLite query using `SqliteAnySqlDriver` and an in-memory database.

The PostgreSQL-style and backend sections are fake on purpose, so you can learn
the API without running PostgreSQL, MySQL, or MongoDB locally. The SQLite
section uses the real built-in driver.

## What To Copy

For trusted Dart code such as servers, CLIs, workers, and tests, copy the
direct-driver pattern:

```dart
final connection = await options.connect(
  driver: const SqliteAnySqlDriver(),
);
```

For Flutter mobile and web apps, copy the backend/proxy pattern:

```dart
final connection = await options.connectBackend(
  client: myBackendClient,
);
```

Do not ship production database passwords inside a Flutter mobile or web app.

## Generate Your Own Options

Create a starter options file:

```sh
dart run anysql init
```

Create a one-database options file:

```sh
dart run anysql configure --dialect postgres --host localhost --database app
```

If you use `--password-env ANYSQL_PASSWORD`, pass the password at runtime:

```sh
dart -DANYSQL_PASSWORD=your_password run example/main.dart
```

Project repository: [github.com/Azrul16/anysql](https://github.com/Azrul16/anysql)
