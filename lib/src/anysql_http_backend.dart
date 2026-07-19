import 'dart:convert';

import 'package:http/http.dart' as http;

import 'anysql_backend.dart';
import 'anysql_config.dart';
import 'anysql_connection.dart';
import 'anysql_exception.dart';
import 'anysql_options.dart';
import 'anysql_result.dart';

/// Backend client that sends AnySQL queries to an HTTP JSON endpoint.
///
/// The client sends `POST` requests to [AnySqlOptions.backendUri]. The request
/// body includes the query statement, parameters, and non-secret config
/// metadata. Passwords are intentionally not sent.
///
/// Expected response body:
///
/// ```json
/// {
///   "rows": [{"id": 1}],
///   "affectedRows": 0,
///   "lastInsertId": null,
///   "metadata": {"columns": ["id"]}
/// }
/// ```
final class AnySqlHttpBackendClient implements AnySqlBackendClient {
  /// Creates an HTTP backend client.
  ///
  /// When [client] is omitted, each returned connection owns its own
  /// `http.Client` and closes it when that connection is closed.
  AnySqlHttpBackendClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  @override
  Future<AnySqlConnection> connect(AnySqlOptions options) async {
    final uri = options.backendUri;
    if (uri == null) {
      throw const AnySqlConfigException('Backend URL is required.');
    }

    final client = _client ?? http.Client();
    return _AnySqlHttpBackendConnection(
      client: client,
      closeClientOnClose: _client == null,
      options: options,
      uri: uri,
    );
  }
}

final class _AnySqlHttpBackendConnection implements AnySqlConnection {
  _AnySqlHttpBackendConnection({
    required http.Client client,
    required bool closeClientOnClose,
    required AnySqlOptions options,
    required Uri uri,
  }) : _client = client,
       _closeClientOnClose = closeClientOnClose,
       _options = options,
       _uri = uri;

  final http.Client _client;
  final bool _closeClientOnClose;
  final AnySqlOptions _options;
  final Uri _uri;
  var _isOpen = true;

  @override
  bool get isOpen => _isOpen;

  @override
  Future<void> close() async {
    if (!_isOpen) {
      return;
    }

    if (_closeClientOnClose) {
      _client.close();
    }
    _isOpen = false;
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    _checkOpen();

    try {
      final response = await _client.post(
        _uri,
        headers: {
          'content-type': 'application/json',
          'accept': 'application/json',
          ..._options.backendHeaders,
        },
        body: jsonEncode({
          'dialect': _options.config.dialect.name,
          'config': _safeConfig(_options.config),
          'statement': statement,
          'parameters': parameters,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AnySqlQueryException(
          'Backend query failed with HTTP ${response.statusCode}.',
          response.body,
        );
      }

      return _decodeResult(response.body);
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute backend query: ${_statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw const AnySqlUnsupportedException(
      'HTTP backend transactions require backend-specific support. '
      'Expose a transaction-aware backend command and call it with query().',
    );
  }

  void _checkOpen() {
    if (!_isOpen) {
      throw const AnySqlConnectionException(
        'HTTP backend connection is closed.',
      );
    }
  }
}

Map<String, Object?> _safeConfig(AnySqlConfig config) {
  return {
    'host': config.host,
    'port': config.port,
    'database': config.database,
    'username': config.username,
    'sslEnabled': config.sslEnabled,
    'options': config.options,
  };
}

AnySqlResult _decodeResult(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const AnySqlQueryException('Backend response must be a JSON object.');
  }

  return AnySqlResult(
    rows: _rows(decoded['rows']),
    affectedRows: _optionalInt(decoded['affectedRows'], 'affectedRows') ?? 0,
    lastInsertId: decoded['lastInsertId'],
    metadata: _objectMap(decoded['metadata']) ?? const {},
  );
}

List<Map<String, Object?>> _rows(Object? value) {
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw const AnySqlQueryException('Backend response rows must be a list.');
  }

  return value.map((row) {
    final mapped = _objectMap(row);
    if (mapped == null) {
      throw const AnySqlQueryException(
        'Backend response row entries must be JSON objects.',
      );
    }

    return mapped;
  }).toList();
}

Map<String, Object?>? _objectMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }

  throw const AnySqlQueryException('Backend response metadata must be a map.');
}

int? _optionalInt(Object? value, String key) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }

  throw AnySqlQueryException('Backend response $key must be an integer.');
}

String _statementPreview(String statement) {
  final compact = statement.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= 120) {
    return compact;
  }

  return '${compact.substring(0, 117)}...';
}
