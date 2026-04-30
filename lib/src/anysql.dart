import 'anysql_config.dart';
import 'anysql_connection.dart';
import 'anysql_driver.dart';
import 'anysql_exception.dart';

/// Entry point for opening database connections through an AnySQL driver.
final class AnySql {
  AnySql([Iterable<AnySqlDriver> drivers = const []])
    : _drivers = List<AnySqlDriver>.of(drivers);

  final List<AnySqlDriver> _drivers;

  /// Registered drivers in lookup order.
  List<AnySqlDriver> get drivers => List.unmodifiable(_drivers);

  /// Registers [driver] if a driver with the same name is not already present.
  void register(AnySqlDriver driver) {
    final existingIndex = _drivers.indexWhere(
      (registered) => registered.name == driver.name,
    );
    if (existingIndex != -1) {
      throw AnySqlException('Driver already registered: ${driver.name}.');
    }

    _drivers.add(driver);
  }

  /// Finds the first registered driver that supports [config].
  AnySqlDriver driverFor(AnySqlConfig config) {
    for (final driver in _drivers) {
      if (driver.supports(config)) {
        return driver;
      }
    }

    throw AnySqlException(
      'No registered driver supports ${config.dialect.name} connections.',
    );
  }

  /// Opens a connection using the first registered driver that supports [config].
  Future<AnySqlConnection> open(AnySqlConfig config) {
    return driverFor(config).connect(config);
  }

  /// Opens a connection with the supplied [driver].
  static Future<AnySqlConnection> connect({
    required AnySqlConfig config,
    required AnySqlDriver driver,
  }) {
    return driver.connect(config);
  }
}
