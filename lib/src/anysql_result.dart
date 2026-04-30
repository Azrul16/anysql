import 'dart:collection';

/// A normalized result returned by SQL and NoSQL drivers.
final class AnySqlResult {
  AnySqlResult({
    List<Map<String, Object?>> rows = const [],
    this.affectedRows = 0,
    this.lastInsertId,
    Map<String, Object?> metadata = const {},
  }) : rows = UnmodifiableListView(
         rows
             .map((row) => UnmodifiableMapView(Map<String, Object?>.of(row)))
             .toList(),
       ),
       metadata = UnmodifiableMapView(Map<String, Object?>.of(metadata));

  /// Creates a result from returned rows.
  AnySqlResult.rows(
    List<Map<String, Object?>> rows, {
    int affectedRows = 0,
    Object? lastInsertId,
    Map<String, Object?> metadata = const {},
  }) : this(
         rows: rows,
         affectedRows: affectedRows,
         lastInsertId: lastInsertId,
         metadata: metadata,
       );

  /// Creates a result for insert, update, delete, or command operations.
  AnySqlResult.command({
    int affectedRows = 0,
    Object? lastInsertId,
    Map<String, Object?> metadata = const {},
  }) : this(
         affectedRows: affectedRows,
         lastInsertId: lastInsertId,
         metadata: metadata,
       );

  final List<Map<String, Object?>> rows;
  final int affectedRows;
  final Object? lastInsertId;
  final Map<String, Object?> metadata;

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;

  int get rowCount => rows.length;

  Map<String, Object?>? get firstOrNull {
    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  Map<String, Object?> get first {
    if (rows.isEmpty) {
      throw StateError('Result has no rows.');
    }

    return rows.first;
  }
}
