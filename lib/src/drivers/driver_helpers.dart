import '../anysql_exception.dart';

String statementPreview(String statement) {
  final compact = statement.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= 120) {
    return compact;
  }

  return '${compact.substring(0, 117)}...';
}

/// Prevents parent operations from entering an active transaction.
final class ConnectionOperationGuard {
  var _queries = 0;
  var _transactionActive = false;

  void checkIdle() {
    if (_transactionActive || _queries != 0) {
      throw const AnySqlConnectionException(
        'Connection is busy. Use the transaction executor inside a transaction '
        'and await pending operations before closing or starting a transaction.',
      );
    }
  }

  void startQuery() {
    if (_transactionActive) {
      throw const AnySqlConnectionException(
        'A transaction is active. Use its transaction executor for queries.',
      );
    }
    _queries += 1;
  }

  void endQuery() => _queries -= 1;

  void startTransaction() {
    checkIdle();
    _transactionActive = true;
  }

  void endTransaction() => _transactionActive = false;
}
