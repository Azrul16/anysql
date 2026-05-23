import 'package:mongo_dart/mongo_dart.dart' as mongo;

import '../anysql_config.dart';
import '../anysql_connection.dart';
import '../anysql_driver.dart';
import '../anysql_exception.dart';
import '../anysql_result.dart';
import 'driver_helpers.dart';

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
/// - `collection.insertMany`
/// - `collection.updateOne`
/// - `collection.updateMany`
/// - `collection.replaceOne`
/// - `collection.deleteOne`
/// - `collection.deleteMany`
/// - `collection.count`
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
            metadata: _writeMetadata(result),
          );
        case 'insertMany':
          final result = await collection.insertMany(
            _requiredDocuments(parameters, 'documents'),
            ordered: parameters['ordered'] as bool?,
          );
          return AnySqlResult.command(
            affectedRows: result.nInserted,
            metadata: _writeMetadata(result),
          );
        case 'updateOne':
          final result = await collection.updateOne(
            _requiredDocument(parameters, 'filter'),
            _requiredDocument(parameters, 'update'),
            upsert: parameters['upsert'] as bool?,
          );
          return AnySqlResult.command(
            affectedRows: result.nModified + result.nUpserted,
            metadata: _writeMetadata(result),
          );
        case 'updateMany':
          final result = await collection.updateMany(
            _requiredDocument(parameters, 'filter'),
            _requiredDocument(parameters, 'update'),
            upsert: parameters['upsert'] as bool?,
          );
          return AnySqlResult.command(
            affectedRows: result.nModified + result.nUpserted,
            metadata: _writeMetadata(result),
          );
        case 'replaceOne':
          final result = await collection.replaceOne(
            _requiredDocument(parameters, 'filter'),
            _requiredDocument(parameters, 'replacement'),
            upsert: parameters['upsert'] as bool?,
          );
          return AnySqlResult.command(
            affectedRows: result.nModified + result.nUpserted,
            metadata: _writeMetadata(result),
          );
        case 'deleteOne':
          final result = await collection.deleteOne(
            _requiredDocument(parameters, 'filter'),
          );
          return AnySqlResult.command(
            affectedRows: result.nRemoved,
            metadata: _writeMetadata(result),
          );
        case 'deleteMany':
          final result = await collection.deleteMany(
            _requiredDocument(parameters, 'filter'),
          );
          return AnySqlResult.command(
            affectedRows: result.nRemoved,
            metadata: _writeMetadata(result),
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
        case 'count':
          final count = await collection.count(
            _document(parameters['filter']) ?? _document(parameters),
          );
          return AnySqlResult.rows([
            {'count': count},
          ]);
        default:
          throw AnySqlException(
            'Unsupported MongoDB operation: ${parsed.operation}.',
          );
      }
    } on AnySqlException {
      rethrow;
    } on Object catch (error) {
      throw AnySqlQueryException(
        'Failed to execute MongoDB operation: ${statementPreview(statement)}',
        error,
      );
    }
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransaction transaction) action,
  ) {
    throw const AnySqlConnectionException(
      'MongoDB transactions are not supported by this driver because '
      'package:mongo_dart does not expose client sessions.',
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

Map<String, Object?> _writeMetadata(dynamic result) {
  return {
    'inserted': result.nInserted as int,
    'matched': result.nMatched as int,
    'modified': result.nModified as int,
    'upserted': result.nUpserted as int,
    'removed': result.nRemoved as int,
    'acknowledged': result.isAcknowledged as bool,
    'writeErrors': result.writeErrorsNumber as int,
    'serverResponses': result.serverResponses as List<Map<String, dynamic>>,
  };
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

List<Map<String, dynamic>> _requiredDocuments(
  Map<String, Object?> parameters,
  String key,
) {
  final values = parameters[key];
  if (values is! Iterable) {
    throw AnySqlException('MongoDB operation requires "$key" document list.');
  }

  return values.map((value) {
    final document = _document(value);
    if (document == null) {
      throw AnySqlException('MongoDB "$key" entries must be maps.');
    }

    return document;
  }).toList();
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
