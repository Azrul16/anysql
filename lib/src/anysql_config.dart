import 'dart:collection';

import 'anysql_exception.dart';
import 'anysql_value.dart';

/// Known database families supported by the AnySQL abstraction.
enum AnySqlDialect { postgres, mysql, sqlite, mongodb, custom }

/// Connection settings passed to an [AnySqlDriver].
final class AnySqlConfig {
  AnySqlConfig({
    required this.dialect,
    this.host,
    this.port,
    this.database,
    this.username,
    this.password,
    this.sslEnabled = false,
    Map<String, Object?> options = const {},
  }) : options = UnmodifiableMapView(Map<String, Object?>.of(options)) {
    _validate();
  }

  /// Convenience constructor for PostgreSQL connections.
  AnySqlConfig.postgres({
    required String host,
    int port = 5432,
    required String database,
    String? username,
    String? password,
    bool sslEnabled = false,
    Map<String, Object?> options = const {},
  }) : this(
         dialect: AnySqlDialect.postgres,
         host: host,
         port: port,
         database: database,
         username: username,
         password: password,
         sslEnabled: sslEnabled,
         options: options,
       );

  /// Convenience constructor for MySQL connections.
  AnySqlConfig.mysql({
    required String host,
    int port = 3306,
    required String database,
    String? username,
    String? password,
    bool sslEnabled = false,
    Map<String, Object?> options = const {},
  }) : this(
         dialect: AnySqlDialect.mysql,
         host: host,
         port: port,
         database: database,
         username: username,
         password: password,
         sslEnabled: sslEnabled,
         options: options,
       );

  /// Convenience constructor for SQLite file or in-memory connections.
  AnySqlConfig.sqlite({
    required String database,
    Map<String, Object?> options = const {},
  }) : this(
         dialect: AnySqlDialect.sqlite,
         database: database,
         options: options,
       );

  /// Convenience constructor for MongoDB-style NoSQL connections.
  AnySqlConfig.mongodb({
    required String host,
    int port = 27017,
    required String database,
    String? username,
    String? password,
    bool sslEnabled = false,
    Map<String, Object?> options = const {},
  }) : this(
         dialect: AnySqlDialect.mongodb,
         host: host,
         port: port,
         database: database,
         username: username,
         password: password,
         sslEnabled: sslEnabled,
         options: options,
       );

  final AnySqlDialect dialect;
  final String? host;
  final int? port;
  final String? database;
  final String? username;
  final String? password;
  final bool sslEnabled;
  final Map<String, Object?> options;

  AnySqlConfig copyWith({
    AnySqlDialect? dialect,
    AnySqlValue<String?>? host,
    AnySqlValue<int?>? port,
    AnySqlValue<String?>? database,
    AnySqlValue<String?>? username,
    AnySqlValue<String?>? password,
    bool? sslEnabled,
    Map<String, Object?>? options,
  }) {
    return AnySqlConfig(
      dialect: dialect ?? this.dialect,
      host: host == null ? this.host : host.value,
      port: port == null ? this.port : port.value,
      database: database == null ? this.database : database.value,
      username: username == null ? this.username : username.value,
      password: password == null ? this.password : password.value,
      sslEnabled: sslEnabled ?? this.sslEnabled,
      options: options ?? this.options,
    );
  }

  void _validate() {
    if (host != null && host!.trim().isEmpty) {
      throw const AnySqlException('Host cannot be empty.');
    }
    if (database != null && database!.trim().isEmpty) {
      throw const AnySqlException('Database cannot be empty.');
    }
    if (username != null && username!.trim().isEmpty) {
      throw const AnySqlException('Username cannot be empty.');
    }
    if (port != null && (port! < 1 || port! > 65535)) {
      throw AnySqlException('Port must be between 1 and 65535: $port.');
    }

    switch (dialect) {
      case AnySqlDialect.postgres:
      case AnySqlDialect.mysql:
      case AnySqlDialect.mongodb:
        if (host == null) {
          throw AnySqlException('${dialect.name} connections require a host.');
        }
        if (database == null) {
          throw AnySqlException(
            '${dialect.name} connections require a database.',
          );
        }
      case AnySqlDialect.sqlite:
        if (database == null) {
          throw const AnySqlException('sqlite connections require a database.');
        }
      case AnySqlDialect.custom:
        break;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is AnySqlConfig &&
        other.dialect == dialect &&
        other.host == host &&
        other.port == port &&
        other.database == database &&
        other.username == username &&
        other.password == password &&
        other.sslEnabled == sslEnabled &&
        _mapsEqual(other.options, options);
  }

  @override
  int get hashCode {
    final sortedOptionKeys = options.keys.toList()..sort();

    return Object.hash(
      dialect,
      host,
      port,
      database,
      username,
      password,
      sslEnabled,
      Object.hashAll(
        sortedOptionKeys.map((key) => Object.hash(key, options[key])),
      ),
    );
  }

  @override
  String toString() {
    return 'AnySqlConfig('
        'dialect: $dialect, '
        'host: $host, '
        'port: $port, '
        'database: $database, '
        'username: $username, '
        'password: ${password == null ? null : '***'}, '
        'sslEnabled: $sslEnabled'
        ')';
  }
}

bool _mapsEqual(Map<String, Object?> left, Map<String, Object?> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }

  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }

  return true;
}
