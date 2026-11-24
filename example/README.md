# AnySQL examples

Choose an example based on what you're building. Each Dart file runs on its own
from the repository root after `dart pub get`.

| I want to… | Example | Run it |
| --- | --- | --- |
| Query collections and documents with the Firebase-style API | [Keyword store](https://github.com/Azrul16/anysql/blob/main/example/keyword_store.dart) | `dart run example/keyword_store.dart` |
| Connect directly and run parameterized SQL | [Direct SQL queries](https://github.com/Azrul16/anysql/blob/main/example/direct_queries.dart) | `dart run example/direct_queries.dart` |
| Commit related writes together | [Transactions](https://github.com/Azrul16/anysql/blob/main/example/transactions.dart) | `dart run example/transactions.dart` |
| Call an HTTP backend from a Flutter app | [HTTP backend](https://github.com/Azrul16/anysql/blob/main/example/http_backend.dart) | `dart run example/http_backend.dart` |
| Register a driver for my own adapter | [Custom driver](https://github.com/Azrul16/anysql/blob/main/example/custom_driver.dart) | `dart run example/custom_driver.dart` |

The SQL examples use in-memory SQLite. The HTTP and custom driver examples
simulate their server and driver locally, so all five run without external
services. Run `dart run example/main.dart` to try them together.

## Generate options in your app

From your app's root directory, add the dependency and launch the setup wizard.
For a Dart app, use `dart pub add anysql` in place of `flutter pub add anysql`.

```sh
flutter pub add anysql
dart run anysql
```

The wizard creates `lib/anysql_options.dart` with `DefaultAnySqlOptions`.
Choose **SQLite** during setup to use the direct examples, and use
`DefaultAnySqlOptions.connectStore(driver: const SqliteAnySqlDriver())` to open
the store with your generated settings.

For a Flutter app with an HTTP backend, configure the backend URL in your
generated options and use
`DefaultAnySqlOptions.connectBackendStore(client: AnySqlHttpBackendClient())`.
Keep database credentials on your server.

For scripted setup, use `dart run anysql configure --help`. To generate a
template with placeholder configurations for all built-in databases, use
`dart run anysql init`.

[Quick start and driver-specific configuration](https://pub.dev/packages/anysql#quick-start)
