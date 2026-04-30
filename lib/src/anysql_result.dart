import 'dart:collection';

/// A normalized result returned by SQL and NoSQL drivers.
final class AnySqlResult {
  /// Creates a normalized result.
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

  /// Returned rows as immutable maps.
  final List<Map<String, Object?>> rows;

  /// Number of rows affected by a command, if reported by the driver.
  final int affectedRows;

  /// Identifier returned by an insert command, if reported by the driver.
  final Object? lastInsertId;

  /// Driver-specific metadata associated with the result.
  final Map<String, Object?> metadata;

  /// Whether [rows] is empty.
  bool get isEmpty => rows.isEmpty;

  /// Whether [rows] contains at least one row.
  bool get isNotEmpty => rows.isNotEmpty;

  /// Number of rows returned.
  int get rowCount => rows.length;

  /// First row, or `null` when no rows were returned.
  Map<String, Object?>? get firstOrNull {
    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  /// First row.
  ///
  /// Throws [StateError] when no rows were returned.
  Map<String, Object?> get first {
    if (rows.isEmpty) {
      throw StateError('Result has no rows.');
    }

    return rows.first;
  }
}
