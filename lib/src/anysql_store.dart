import 'dart:collection';

import 'anysql_config.dart';
import 'anysql_connection.dart';
import 'anysql_exception.dart';
import 'anysql_parameters.dart';
import 'anysql_result.dart';

/// Firebase-style document/table API layered over an [AnySqlConnection].
///
/// This API is intentionally small and predictable. It builds parameterized
/// database commands for the configured [dialect] while keeping
/// [AnySqlConnection.query] available as the low-level escape hatch.
final class AnySqlStore {
  /// Creates a keyword-style store over [connection].
  const AnySqlStore(this.connection, {required this.dialect});

  /// Underlying database connection.
  final AnySqlConnection connection;

  /// Database family used to compile keyword operations.
  final AnySqlDialect dialect;

  /// Runs keyword-store work inside a database transaction.
  ///
  /// The callback receives a transaction-scoped store with the same
  /// collection API. It is committed when the callback completes and rolled
  /// back when it throws, following the underlying connection contract.
  Future<T> transaction<T>(
    Future<T> Function(AnySqlTransactionStore store) action,
  ) {
    return connection.transaction((transaction) {
      return action(AnySqlTransactionStore._(transaction, dialect: dialect));
    });
  }

  /// Closes the underlying database connection.
  Future<void> close() {
    return connection.close();
  }

  /// Returns a collection/table reference.
  AnySqlCollectionReference collection(String name, {String idField = 'id'}) {
    return AnySqlCollectionReference._(
      executor: connection,
      dialect: dialect,
      name: name,
      idField: idField,
    );
  }
}

/// Keyword-style store scoped to an active database transaction.
final class AnySqlTransactionStore {
  const AnySqlTransactionStore._(this.transaction, {required this.dialect});

  /// Underlying transaction used by collection operations.
  final AnySqlTransaction transaction;

  /// Database family used to compile keyword operations.
  final AnySqlDialect dialect;

  /// Returns a transaction-scoped collection/table reference.
  AnySqlCollectionReference collection(String name, {String idField = 'id'}) {
    return AnySqlCollectionReference._(
      executor: transaction,
      dialect: dialect,
      name: name,
      idField: idField,
    );
  }
}

/// Convenience helpers for opening the keyword-style API from a connection.
extension AnySqlStoreConnection on AnySqlConnection {
  /// Creates an [AnySqlStore] over this connection.
  AnySqlStore store({required AnySqlDialect dialect}) {
    return AnySqlStore(this, dialect: dialect);
  }
}

/// A queryable collection/table reference.
final class AnySqlCollectionReference {
  AnySqlCollectionReference._({
    required AnySqlQueryExecutor executor,
    required AnySqlDialect dialect,
    required String name,
    required String idField,
    List<_AnySqlFilter> filters = const [],
    List<_AnySqlOrder> orders = const [],
    List<String> selectedFields = const [],
    int? limitValue,
    int? offsetValue,
  }) : _executor = executor,
       _dialect = dialect,
       name = _checkedIdentifier(name, 'collection'),
       idField = _checkedIdentifier(idField, 'id field'),
       _filters = List.unmodifiable(filters),
       _orders = List.unmodifiable(orders),
       _selectedFields = List.unmodifiable(selectedFields),
       _limit = limitValue,
       _offset = offsetValue;

  final AnySqlQueryExecutor _executor;
  final AnySqlDialect _dialect;
  final List<_AnySqlFilter> _filters;
  final List<_AnySqlOrder> _orders;
  final List<String> _selectedFields;
  final int? _limit;
  final int? _offset;

  /// Collection name for document databases, or table name for SQL databases.
  final String name;

  /// Field/column used by [doc].
  final String idField;

  /// Returns a document/row reference by [id].
  AnySqlDocumentReference doc(Object? id) {
    return AnySqlDocumentReference._(collection: this, id: id);
  }

  /// Adds an equality or comparison filter.
  ///
  /// Only one operator can be supplied per call. Call [where] multiple times to
  /// combine filters with AND semantics.
  AnySqlCollectionReference where(
    String field, {
    Object? isEqualTo = _unset,
    Object? isNotEqualTo = _unset,
    Object? isLessThan = _unset,
    Object? isLessThanOrEqualTo = _unset,
    Object? isGreaterThan = _unset,
    Object? isGreaterThanOrEqualTo = _unset,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
  }) {
    final supplied = [
      !identical(isEqualTo, _unset),
      !identical(isNotEqualTo, _unset),
      !identical(isLessThan, _unset),
      !identical(isLessThanOrEqualTo, _unset),
      !identical(isGreaterThan, _unset),
      !identical(isGreaterThanOrEqualTo, _unset),
      whereIn != null,
      whereNotIn != null,
    ].where((value) => value).length;
    if (supplied != 1) {
      throw const AnySqlException(
        'where requires exactly one comparison operator.',
      );
    }

    final checkedField = _checkedIdentifier(field, 'filter field');
    final filter = switch ((
      !identical(isEqualTo, _unset),
      !identical(isNotEqualTo, _unset),
      !identical(isLessThan, _unset),
      !identical(isLessThanOrEqualTo, _unset),
      !identical(isGreaterThan, _unset),
      !identical(isGreaterThanOrEqualTo, _unset),
      whereIn != null,
      whereNotIn != null,
    )) {
      (true, _, _, _, _, _, _, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.equalTo,
        isEqualTo,
      ),
      (_, true, _, _, _, _, _, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.notEqualTo,
        isNotEqualTo,
      ),
      (_, _, true, _, _, _, _, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.lessThan,
        isLessThan,
      ),
      (_, _, _, true, _, _, _, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.lessThanOrEqualTo,
        isLessThanOrEqualTo,
      ),
      (_, _, _, _, true, _, _, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.greaterThan,
        isGreaterThan,
      ),
      (_, _, _, _, _, true, _, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.greaterThanOrEqualTo,
        isGreaterThanOrEqualTo,
      ),
      (_, _, _, _, _, _, true, _) => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.whereIn,
        List<Object?>.unmodifiable(whereIn!),
      ),
      _ => _AnySqlFilter(
        checkedField,
        _AnySqlFilterOperator.whereNotIn,
        List<Object?>.unmodifiable(whereNotIn!),
      ),
    };

    return _copyWith(filters: [..._filters, filter]);
  }

  /// Adds an ordering expression.
  AnySqlCollectionReference orderBy(String field, {bool descending = false}) {
    return _copyWith(
      orders: [
        ..._orders,
        _AnySqlOrder(_checkedIdentifier(field, 'order field'), descending),
      ],
    );
  }

  /// Selects only the supplied fields from matching rows/documents.
  AnySqlCollectionReference select(Iterable<String> fields) {
    final checked = fields
        .map((field) => _checkedIdentifier(field, 'selected field'))
        .toSet()
        .toList();
    if (checked.isEmpty) {
      throw const AnySqlException('select requires at least one field.');
    }
    return _copyWith(selectedFields: checked);
  }

  /// Limits the number of returned rows/documents.
  AnySqlCollectionReference limit(int count) {
    if (count < 0) {
      throw const AnySqlException('limit cannot be negative.');
    }
    return _copyWith(limitValue: count);
  }

  /// Skips the first [count] rows/documents.
  AnySqlCollectionReference offset(int count) {
    if (count < 0) {
      throw const AnySqlException('offset cannot be negative.');
    }
    return _copyWith(offsetValue: count);
  }

  /// Executes this collection query.
  Future<AnySqlResult> get() {
    return switch (_dialect) {
      AnySqlDialect.mongodb => _executor.query(
        '$name.aggregate',
        parameters: AnySqlParameters.document({
          'pipeline': _mongoPipeline(
            filters: _filters,
            orders: _orders,
            selectedFields: _selectedFields,
            limit: _limit,
            offset: _offset,
          ),
        }),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => _runSql(_sqlSelect()),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom dialect queries.',
      ),
    };
  }

  /// Executes this query and returns the first row/document, or `null`.
  Future<Map<String, Object?>?> first() async {
    return (await limit(1).get()).firstOrNull;
  }

  /// Returns the number of rows/documents matching this query's filters.
  Future<int> count() async {
    final result = switch (_dialect) {
      AnySqlDialect.mongodb => await _executor.query(
        '$name.count',
        parameters: AnySqlParameters.document({
          'filter': _mongoFilter(_filters),
        }),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => await _runSql(_sqlCount()),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom dialect counts.',
      ),
    };
    final value = result.firstOrNull?['count'];
    if (value is int) {
      return value;
    }
    if (value is BigInt) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw AnySqlQueryException(
      'Count result must contain an integer "count" value.',
      value,
    );
  }

  /// Whether at least one row/document matches this query.
  Future<bool> exists() async => await count() > 0;

  /// Inserts a new row/document.
  Future<AnySqlResult> add(Map<String, Object?> data) {
    final checkedData = _checkedData(data);
    if (checkedData.isEmpty) {
      throw const AnySqlException('add requires at least one field.');
    }

    return switch (_dialect) {
      AnySqlDialect.mongodb => _executor.query(
        '$name.insertOne',
        parameters: AnySqlParameters.document({'document': checkedData}),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => _runSql(_sqlInsert(checkedData)),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom dialect inserts.',
      ),
    };
  }

  /// Inserts multiple rows/documents in one command.
  Future<AnySqlResult> addAll(Iterable<Map<String, Object?>> values) {
    final rows = values.map(_checkedData).toList();
    if (rows.isEmpty || rows.any((row) => row.isEmpty)) {
      throw const AnySqlException('addAll requires non-empty data rows.');
    }
    final fields = rows.first.keys.toList();
    if (rows.any((row) => !_sameFields(row.keys, fields))) {
      throw const AnySqlException('addAll rows must use the same fields.');
    }
    return switch (_dialect) {
      AnySqlDialect.mongodb => _executor.query(
        '$name.insertMany',
        parameters: AnySqlParameters.document({'documents': rows}),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => _runSql(_sqlInsertAll(rows)),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom bulk inserts.',
      ),
    };
  }

  AnySqlCollectionReference _copyWith({
    List<_AnySqlFilter>? filters,
    List<_AnySqlOrder>? orders,
    List<String>? selectedFields,
    int? limitValue,
    int? offsetValue,
  }) {
    return AnySqlCollectionReference._(
      executor: _executor,
      dialect: _dialect,
      name: name,
      idField: idField,
      filters: filters ?? _filters,
      orders: orders ?? _orders,
      selectedFields: selectedFields ?? _selectedFields,
      limitValue: limitValue ?? _limit,
      offsetValue: offsetValue ?? _offset,
    );
  }

  Future<AnySqlResult> _runSql(_SqlCommand command) {
    return _executor.query(command.statement, parameters: command.parameters);
  }

  _SqlCommand _sqlSelect() {
    final builder = _SqlBuilder(_dialect);
    final selection = _selectedFields.isEmpty
        ? '*'
        : _selectedFields.map(builder.identifier).join(', ');
    final where = builder.where(_filters);
    final orderBy = _orders.isEmpty
        ? ''
        : ' order by ${_orders.map((order) {
            final direction = order.descending ? 'desc' : 'asc';
            return '${builder.identifier(order.field)} $direction';
          }).join(', ')}';
    final limit = switch ((_limit, _offset, _dialect)) {
      (final value?, _, _) => ' limit ${builder.addParameter(value)}',
      (null, final offset?, AnySqlDialect.mysql) when offset >= 0 =>
        ' limit 18446744073709551615',
      (null, final offset?, AnySqlDialect.sqlite) when offset >= 0 =>
        ' limit -1',
      _ => '',
    };
    final offset = _offset == null
        ? ''
        : ' offset ${builder.addParameter(_offset)}';

    return builder.command(
      'select $selection from ${builder.identifier(name)}'
      '$where$orderBy$limit$offset',
    );
  }

  _SqlCommand _sqlCount() {
    final builder = _SqlBuilder(_dialect);
    final where = builder.where(_filters);
    return builder.command(
      'select count(*) as ${builder.identifier('count')} '
      'from ${builder.identifier(name)}$where',
    );
  }

  _SqlCommand _sqlInsert(Map<String, Object?> data) {
    final builder = _SqlBuilder(_dialect);
    final columns = data.keys.map(builder.identifier).join(', ');
    final values = data.values.map(builder.addParameter).join(', ');
    return builder.command(
      'insert into ${builder.identifier(name)} ($columns) values ($values)',
    );
  }

  _SqlCommand _sqlInsertAll(List<Map<String, Object?>> rows) {
    final builder = _SqlBuilder(_dialect);
    final columns = rows.first.keys.map(builder.identifier).join(', ');
    final values = rows
        .map(
          (row) =>
              '(${rows.first.keys.map((field) => builder.addParameter(row[field])).join(', ')})',
        )
        .join(', ');
    return builder.command(
      'insert into ${builder.identifier(name)} ($columns) values $values',
    );
  }
}

/// A single document/row reference.
final class AnySqlDocumentReference {
  AnySqlDocumentReference._({
    required AnySqlCollectionReference collection,
    required this.id,
  }) : _collection = collection;

  final AnySqlCollectionReference _collection;

  /// Document id or row primary key value.
  final Object? id;

  /// Reads this document/row.
  Future<AnySqlResult> get() {
    return _collection.where(_collection.idField, isEqualTo: id).limit(1).get();
  }

  /// Reads this document/row and returns the first row/document, or `null`.
  Future<Map<String, Object?>?> first() async {
    return (await get()).firstOrNull;
  }

  /// Creates or replaces this document/row.
  Future<AnySqlResult> set(Map<String, Object?> data) {
    final checkedData = _checkedData({...data, _collection.idField: id});
    if (checkedData.length == 1) {
      throw const AnySqlException('set requires at least one data field.');
    }

    return switch (_collection._dialect) {
      AnySqlDialect.mongodb => _collection._executor.query(
        '${_collection.name}.replaceOne',
        parameters: AnySqlParameters.document({
          'filter': {_collection.idField: id},
          'replacement': checkedData,
          'upsert': true,
        }),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => _collection._runSql(_sqlSet(checkedData)),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom dialect writes.',
      ),
    };
  }

  /// Updates fields on this document/row.
  Future<AnySqlResult> update(Map<String, Object?> data) {
    final checkedData = _checkedData(data);
    if (checkedData.isEmpty) {
      throw const AnySqlException('update requires at least one field.');
    }

    return switch (_collection._dialect) {
      AnySqlDialect.mongodb => _collection._executor.query(
        '${_collection.name}.updateOne',
        parameters: AnySqlParameters.document({
          'filter': {_collection.idField: id},
          'update': {r'$set': checkedData},
        }),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => _collection._runSql(_sqlUpdate(checkedData)),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom dialect writes.',
      ),
    };
  }

  /// Deletes this document/row.
  Future<AnySqlResult> delete() {
    return switch (_collection._dialect) {
      AnySqlDialect.mongodb => _collection._executor.query(
        '${_collection.name}.deleteOne',
        parameters: AnySqlParameters.document({
          'filter': {_collection.idField: id},
        }),
      ),
      AnySqlDialect.postgres ||
      AnySqlDialect.mysql ||
      AnySqlDialect.sqlite => _collection._runSql(_sqlDelete()),
      AnySqlDialect.custom => throw const AnySqlUnsupportedException(
        'AnySqlStore does not know how to compile custom dialect deletes.',
      ),
    };
  }

  _SqlCommand _sqlSet(Map<String, Object?> data) {
    final builder = _SqlBuilder(_collection._dialect);
    final table = builder.identifier(_collection.name);
    final idColumn = builder.identifier(_collection.idField);
    final columns = data.keys.map(builder.identifier).join(', ');
    final values = data.values.map(builder.addParameter).join(', ');
    final updateColumns = data.keys
        .where((field) => field != _collection.idField)
        .map((field) {
          final column = builder.identifier(field);
          return switch (_collection._dialect) {
            AnySqlDialect.mysql => '$column = values($column)',
            _ => '$column = excluded.$column',
          };
        })
        .join(', ');

    final statement = switch (_collection._dialect) {
      AnySqlDialect.sqlite =>
        'insert into $table ($columns) values ($values) '
            'on conflict ($idColumn) do update set $updateColumns',
      AnySqlDialect.postgres =>
        'insert into $table ($columns) values ($values) '
            'on conflict ($idColumn) do update set $updateColumns',
      AnySqlDialect.mysql =>
        'insert into $table ($columns) values ($values) '
            'on duplicate key update $updateColumns',
      _ => throw const AnySqlException('Unsupported SQL dialect.'),
    };

    return builder.command(statement);
  }

  _SqlCommand _sqlUpdate(Map<String, Object?> data) {
    final builder = _SqlBuilder(_collection._dialect);
    final assignments = data.entries
        .map((entry) {
          return '${builder.identifier(entry.key)} = '
              '${builder.addParameter(entry.value)}';
        })
        .join(', ');
    final idParameter = builder.addParameter(id);

    return builder.command(
      'update ${builder.identifier(_collection.name)} set $assignments '
      'where ${builder.identifier(_collection.idField)} = $idParameter',
    );
  }

  _SqlCommand _sqlDelete() {
    final builder = _SqlBuilder(_collection._dialect);
    final idParameter = builder.addParameter(id);

    return builder.command(
      'delete from ${builder.identifier(_collection.name)} '
      'where ${builder.identifier(_collection.idField)} = $idParameter',
    );
  }
}

final class _SqlBuilder {
  _SqlBuilder(this.dialect);

  final AnySqlDialect dialect;
  final _parameters = <Object?>[];
  var _nextParameter = 0;

  String identifier(String value) {
    return switch (dialect) {
      AnySqlDialect.mysql => '`$value`',
      AnySqlDialect.postgres || AnySqlDialect.sqlite => '"$value"',
      _ => throw const AnySqlException('Unsupported SQL dialect.'),
    };
  }

  String addParameter(Object? value) {
    _parameters.add(value);
    final index = _nextParameter++;
    return switch (dialect) {
      AnySqlDialect.postgres => '@p$index',
      AnySqlDialect.mysql => ':p$index',
      AnySqlDialect.sqlite => '?',
      _ => throw const AnySqlException('Unsupported SQL dialect.'),
    };
  }

  String where(List<_AnySqlFilter> filters) {
    if (filters.isEmpty) {
      return '';
    }

    final clauses = filters
        .map((filter) {
          final field = identifier(filter.field);
          return switch (filter.operator) {
            _AnySqlFilterOperator.equalTo when filter.value == null =>
              '$field is null',
            _AnySqlFilterOperator.notEqualTo when filter.value == null =>
              '$field is not null',
            _AnySqlFilterOperator.equalTo =>
              '$field = ${addParameter(filter.value)}',
            _AnySqlFilterOperator.notEqualTo =>
              '$field <> ${addParameter(filter.value)}',
            _AnySqlFilterOperator.lessThan =>
              '$field < ${addParameter(filter.value)}',
            _AnySqlFilterOperator.lessThanOrEqualTo =>
              '$field <= ${addParameter(filter.value)}',
            _AnySqlFilterOperator.greaterThan =>
              '$field > ${addParameter(filter.value)}',
            _AnySqlFilterOperator.greaterThanOrEqualTo =>
              '$field >= ${addParameter(filter.value)}',
            _AnySqlFilterOperator.whereIn => _whereIn(field, filter.value),
            _AnySqlFilterOperator.whereNotIn => _whereNotIn(
              field,
              filter.value,
            ),
          };
        })
        .join(' and ');

    return ' where $clauses';
  }

  String _whereIn(String field, Object? value) {
    final values = value as List<Object?>;
    if (values.isEmpty) {
      return '1 = 0';
    }

    return '$field in (${values.map(addParameter).join(', ')})';
  }

  String _whereNotIn(String field, Object? value) {
    final values = value as List<Object?>;
    if (values.isEmpty) {
      return '1 = 1';
    }
    return '$field not in (${values.map(addParameter).join(', ')})';
  }

  _SqlCommand command(String statement) {
    final parameters = switch (dialect) {
      AnySqlDialect.sqlite => AnySqlParameters.positional(_parameters),
      AnySqlDialect.postgres || AnySqlDialect.mysql => AnySqlParameters.named({
        for (var index = 0; index < _parameters.length; index += 1)
          'p$index': _parameters[index],
      }),
      _ => throw const AnySqlException('Unsupported SQL dialect.'),
    };

    return _SqlCommand(statement, parameters);
  }
}

final class _SqlCommand {
  const _SqlCommand(this.statement, this.parameters);

  final String statement;
  final Map<String, Object?> parameters;
}

final class _AnySqlFilter {
  const _AnySqlFilter(this.field, this.operator, this.value);

  final String field;
  final _AnySqlFilterOperator operator;
  final Object? value;
}

enum _AnySqlFilterOperator {
  equalTo,
  notEqualTo,
  lessThan,
  lessThanOrEqualTo,
  greaterThan,
  greaterThanOrEqualTo,
  whereIn,
  whereNotIn,
}

final class _AnySqlOrder {
  const _AnySqlOrder(this.field, this.descending);

  final String field;
  final bool descending;
}

const _unset = Object();

final _identifierPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

String _checkedIdentifier(String value, String label) {
  if (!_identifierPattern.hasMatch(value)) {
    throw AnySqlException(
      'Invalid $label "$value". Use letters, numbers, and underscores only, '
      'starting with a letter or underscore.',
    );
  }

  return value;
}

Map<String, Object?> _checkedData(Map<String, Object?> data) {
  return UnmodifiableMapView({
    for (final entry in data.entries)
      _checkedIdentifier(entry.key, 'data field'): entry.value,
  });
}

List<Map<String, Object?>> _mongoPipeline({
  required List<_AnySqlFilter> filters,
  required List<_AnySqlOrder> orders,
  required List<String> selectedFields,
  required int? limit,
  required int? offset,
}) {
  return [
    if (filters.isNotEmpty) {'\$match': _mongoFilter(filters)},
    if (orders.isNotEmpty)
      {
        '\$sort': {
          for (final order in orders) order.field: order.descending ? -1 : 1,
        },
      },
    if (selectedFields.isNotEmpty)
      {
        '\$project': {
          for (final field in selectedFields) field: 1,
          if (!selectedFields.contains('_id')) '_id': 0,
        },
      },
    if (offset != null) {'\$skip': offset},
    if (limit != null) {'\$limit': limit},
  ];
}

Map<String, Object?> _mongoFilter(List<_AnySqlFilter> filters) {
  if (filters.isEmpty) {
    return const {};
  }
  if (filters.length == 1) {
    return _singleMongoFilter(filters.single);
  }

  return {'\$and': filters.map(_singleMongoFilter).toList()};
}

Map<String, Object?> _singleMongoFilter(_AnySqlFilter filter) {
  final value = filter.value;
  return switch (filter.operator) {
    _AnySqlFilterOperator.equalTo => {filter.field: value},
    _AnySqlFilterOperator.notEqualTo => {
      filter.field: {'\$ne': value},
    },
    _AnySqlFilterOperator.lessThan => {
      filter.field: {'\$lt': value},
    },
    _AnySqlFilterOperator.lessThanOrEqualTo => {
      filter.field: {'\$lte': value},
    },
    _AnySqlFilterOperator.greaterThan => {
      filter.field: {'\$gt': value},
    },
    _AnySqlFilterOperator.greaterThanOrEqualTo => {
      filter.field: {'\$gte': value},
    },
    _AnySqlFilterOperator.whereIn => {
      filter.field: {'\$in': value},
    },
    _AnySqlFilterOperator.whereNotIn => {
      filter.field: {'\$nin': value},
    },
  };
}

bool _sameFields(Iterable<String> actual, List<String> expected) {
  final values = actual.toList();
  if (values.length != expected.length) return false;
  return values.toSet().containsAll(expected);
}
