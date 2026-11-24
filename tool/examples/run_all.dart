import 'custom_driver.dart' as custom_driver;
import 'direct_queries.dart' as direct_queries;
import 'http_backend.dart' as http_backend;
import 'keyword_store.dart' as keyword_store;
import 'transactions.dart' as transactions;

Future<void> main() async {
  print('Direct SQL queries');
  await direct_queries.main();

  print('\nKeyword store');
  await keyword_store.main();

  print('\nTransactions');
  await transactions.main();

  print('\nHTTP backend');
  await http_backend.main();

  print('\nCustom driver');
  await custom_driver.main();
}
