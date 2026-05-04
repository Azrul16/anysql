import 'package:mongo_dart/mongo_dart.dart' as mongo;

import '../anysql_config.dart';
import '../anysql_connection.dart';
import '../anysql_driver.dart';
import '../anysql_exception.dart';
import '../anysql_result.dart';

/// Real MongoDB driver backed by `package:mongo_dart`.
///
/// The driver builds a MongoDB URI from [AnySqlConfig] fields. To provide a
/// complete URI yourself, set `options: {'uri': 'mongodb://...'}`.
final class MongodbAnySqlDriver extends AnySqlDriverBase {
  /// Creates a MongoDB driver.
  const MongodbAnySqlDriver() : super('mongodb', AnySqlDialect.mongodb);

  @override
  Future<AnySqlConnection> connect(AnySqlConfig config) async {
    checkSupported(config);

    try {
      final db = await mongo.Db.create(_mongoUri(config));
      await db.open(secure: config.sslEnabled);
      return MongodbAnySqlConnection(db);
    } on Object catch (error) {
      throw AnySqlException('Failed to connect to MongoDB.', error);
    }
  }
}

/// AnySQL connection backed by a MongoDB database.
///
/// MongoDB does not use SQL strings, so this adapter treats [query] statements
/// as `collection.operation` names. Supported statement formats:
///
/// - `collection.find`
/// - `collection.findOne`
/// - `collection.insertOne`
/// - `collection.updateOne`
/// - `collection.deleteOne`
/// - `collection.aggregate`
///
/// Operation arguments are passed through `parameters`, for example
/// `parameters: {'filter': {'active': true}}`.
final class MongodbAnySqlConnection implements AnySqlConnection {
  /// Wraps an existing MongoDB [database].
  MongodbAnySqlConnection(this.database);

  /// Underlying MongoDB database.
  final mongo.Db database;

  @override
  bool get isOpen => database.isConnected;

  @override
  Future<void> close() async {
    await database.close();
  }

  @override
  Future<AnySqlResult> query(
    String statement, {
    Map<String, Object?> parameters = const {},
  }) async {
    _checkOpen();

    try {
      final parsed = _MongoStatement.parse(statement);
      final collection = database.collection(parsed.collection);

      switch (parsed.operation) {
        case 'find':
          final rows = await collection
              .find(_document(parameters['filter']) ?? _document(parameters))
              .toList();
          return AnySqlResult.rows(_mongoRows(rows));
        case 'findOne':
          final row = await collection.findOne(
            _document(parameters['filter']) ?? _document(parameters),
          );
          return AnySqlResult.rows(row == null ? const [] : _mongoRows([row]));
        case 'insertOne':
          final document = _requiredDocument(parameters, 'document');
          final result = await collection.insertOne(document);
          return AnySqlResult.command(
            affectedRows: result.nInserted,
            lastInsertId: document['_id'],
            metadata: _document(result.document) ?? const {},
          );
        case 'updateOne':
          final result = await collection.updateOne(
            _requiredDocument(parameters, 'filter'),
            _requiredDocument(parameters, 'update'),
            upsert: parameters['upsert'] as bool?,
          );
          return AnySqlResult.command(
            affectedRows: result.nModified,
            metadata: _document(result.document) ?? const {},
          );
        case 'deleteOne':
          final result = await collection.deleteOne(
            _requiredDocument(parameters, 'filter'),
          );
          return AnySqlResult.command(
            affectedRows: result.nRemoved,
            metadata: _document(result.document) ?? const {},
          );
        case 'aggregate':
          final pipeline = parameters['pipeline'];
          if (pipeline is! List) {
            throw const AnySqlException(
              'MongoDB aggregate requires a pipeline list.',
            );
          }
          final rows = await collection
              .aggregateToStream(_pipeline(pipeline))
              .toList();
          return AnySqlResult.rows(_mongoRows(rows));
        default:
          throw AnySqlException(
            'Unsupported MongoDB operation: ${parsed.operation}.',
          );
      }
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute MongoDB operation: ${_statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw UnsupportedError(
      'MongoDB transactions are not exposed by this AnySQL driver yet.',
    );
  }

  void _checkOpen() {
    if (!database.isConnected) {
      throw const AnySqlConnectionException('MongoDB connection is closed.');
    }
  }
}

final class _MongoStatement {
  const _MongoStatement({required this.collection, required this.operation});

  final String collection;
  final String operation;

  static _MongoStatement parse(String statement) {
    final separator = statement.lastIndexOf('.');
    if (separator <= 0 || separator == statement.length - 1) {
      throw const AnySqlException(
        'MongoDB statements must use collection.operation format.',
      );
    }

    return _MongoStatement(
      collection: statement.substring(0, separator),
      operation: statement.substring(separator + 1),
    );
  }
}

String _mongoUri(AnySqlConfig config) {
  final uri = config.options['uri'];
  if (uri is String && uri.trim().isNotEmpty) {
    return uri;
  }

  final credentials = config.username == null
      ? ''
      : '${Uri.encodeComponent(config.username!)}:'
            '${Uri.encodeComponent(config.password ?? '')}@';
  final query = config.sslEnabled ? '?tls=true' : '';

  return 'mongodb://$credentials${config.host}:${config.port ?? 27017}/'
      '${Uri.encodeComponent(config.database!)}$query';
}

Map<String, dynamic>? _document(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  throw const AnySqlException('MongoDB document values must be maps.');
}

Map<String, dynamic> _requiredDocument(
  Map<String, Object?> parameters,
  String key,
) {
  final document = _document(parameters[key]);
  if (document == null) {
    throw AnySqlException('MongoDB operation requires "$key" document.');
  }

  return document;
}

List<Map<String, Object>> _pipeline(List values) {
  return values.map((value) {
    final document = _document(value);
    if (document == null) {
      throw const AnySqlException('MongoDB pipeline entries must be maps.');
    }

    return Map<String, Object>.from(document);
  }).toList();
}

List<Map<String, Object?>> _mongoRows(List<Map<String, dynamic>> rows) {
  return rows.map((row) => Map<String, Object?>.from(row)).toList();
}

String _statementPreview(String statement) {
  final compact = statement.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= 120) {
    return compact;
  }

  return '${compact.substring(0, 117)}...';
}
