import 'anysql.dart';
import 'anysql_backend.dart';
import 'anysql_config.dart';
import 'anysql_connection.dart';
import 'anysql_driver.dart';

/// App-level connection options, similar in spirit to Firebase options files.
final class AnySqlOptions {
  AnySqlOptions({
    required this.config,
    this.backendUri,
    Map<String, String> backendHeaders = const {},
  }) : backendHeaders = Map.unmodifiable(backendHeaders);

  /// Direct database connection settings for trusted environments.
  final AnySqlConfig config;

  /// Optional backend endpoint for apps that should not connect directly.
  final Uri? backendUri;

  /// Default headers a backend client can use when talking to [backendUri].
  final Map<String, String> backendHeaders;

  /// Whether a backend endpoint has been configured.
  bool get hasBackend => backendUri != null;

  /// Opens a direct database connection with [driver].
  Future<AnySqlConnection> connect({required AnySqlDriver driver}) {
    return AnySql.connect(config: config, driver: driver);
  }

  /// Opens a direct database connection using registered drivers.
  Future<AnySqlConnection> openWith(AnySql anySql) {
    return anySql.open(config);
  }

  /// Opens a connection through a backend or proxy client.
  Future<AnySqlConnection> connectBackend({
    required AnySqlBackendClient client,
  }) {
    return client.connect(this);
  }
}
