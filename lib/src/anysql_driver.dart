import 'anysql_config.dart';
import 'anysql_connection.dart';
import 'anysql_exception.dart';

/// Creates [AnySqlConnection] instances for a specific database backend.
abstract interface class AnySqlDriver {
  /// Human-readable driver name, such as `postgres` or `mysql`.
  String get name;

  /// Whether this driver can open a connection for [config].
  bool supports(AnySqlConfig config);

  /// Opens a new database connection.
  Future<AnySqlConnection> connect(AnySqlConfig config);
}

/// Helpful base class for concrete drivers.
abstract base class AnySqlDriverBase implements AnySqlDriver {
  const AnySqlDriverBase(this.name, this.dialect);

  @override
  final String name;

  final AnySqlDialect dialect;

  @override
  bool supports(AnySqlConfig config) => config.dialect == dialect;

  /// Throws when [config] is not intended for this driver.
  void checkSupported(AnySqlConfig config) {
    if (!supports(config)) {
      throw AnySqlException(
        '$name does not support ${config.dialect.name} connections.',
      );
    }
  }
}
