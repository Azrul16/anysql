import 'anysql_connection.dart';
import 'anysql_options.dart';

/// Opens connections through a trusted backend or proxy service.
abstract interface class AnySqlBackendClient {
  /// Opens a connection-like client using generated [options].
  Future<AnySqlConnection> connect(AnySqlOptions options);
}
