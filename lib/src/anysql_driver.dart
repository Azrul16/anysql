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

/// Optional features supported by a database driver.
///
/// Capabilities are conservative: a `false` value means callers should not
/// rely on that feature through the shared AnySQL API.
final class AnySqlCapabilities {
  /// Creates a driver capability description.
  const AnySqlCapabilities({
    this.transactions = false,
    this.returningRows = false,
    this.upsert = false,
    this.aggregation = false,
  });

  /// A driver with no optional capabilities declared.
  static const none = AnySqlCapabilities();

  /// Whether the driver implements [AnySqlConnection.transaction].
  final bool transactions;

  /// Whether data-changing statements can return rows.
  final bool returningRows;

  /// Whether the database supports insert-or-update operations.
  final bool upsert;

  /// Whether the driver supports native aggregation pipelines.
  final bool aggregation;
}

/// Implemented by drivers that explicitly describe optional functionality.
abstract interface class AnySqlCapabilityProvider {
  /// Optional functionality supported by this driver.
  AnySqlCapabilities get capabilities;
}

/// Capability lookup that remains compatible with existing third-party
/// implementations of [AnySqlDriver].
extension AnySqlDriverCapabilities on AnySqlDriver {
  /// Returns declared capabilities, or a conservative empty set for legacy
  /// drivers that do not implement [AnySqlCapabilityProvider].
  AnySqlCapabilities get capabilities {
    final driver = this;
    return driver is AnySqlCapabilityProvider
        ? driver.capabilities
        : AnySqlCapabilities.none;
  }
}

/// Helpful base class for concrete drivers.
abstract base class AnySqlDriverBase
    implements AnySqlDriver, AnySqlCapabilityProvider {
  /// Creates a base driver for [dialect] with a human-readable [name].
  const AnySqlDriverBase(
    this.name,
    this.dialect, {
    this.capabilities = AnySqlCapabilities.none,
  });

  @override
  final String name;

  /// Database dialect this driver supports by default.
  final AnySqlDialect dialect;

  @override
  final AnySqlCapabilities capabilities;

  @override
  bool supports(AnySqlConfig config) => config.dialect == dialect;

  /// Throws when [config] is not intended for this driver.
  void checkSupported(AnySqlConfig config) {
    if (!supports(config)) {
      throw AnySqlDriverException(
        '$name does not support ${config.dialect.name} connections.',
      );
    }
  }
}
