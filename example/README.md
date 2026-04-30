# anysql example

This example shows both setup styles supported by `anysql`:

- direct driver connection for trusted Dart environments
- backend/proxy connection for Flutter mobile and web apps

Run it with:

```sh
dart -DANYSQL_PASSWORD=your_password run example/main.dart
```

In a real app, replace `ExamplePostgresDriver` and `ExampleBackendClient` with
database-specific packages that implement the `anysql` contracts.
