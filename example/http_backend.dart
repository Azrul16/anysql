import 'dart:convert';

import 'package:anysql/anysql.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> main() async {
  final options = AnySqlOptions(
    config: AnySqlConfig.postgres(host: 'db.internal', database: 'app'),
    backendUri: Uri.parse('https://api.example.com/anysql'),
  );

  // Simulate the HTTP endpoint locally so the example needs no server.
  final httpClient = MockClient((request) async {
    print('Request: ${request.body}');
    return http.Response(
      jsonEncode({
        'rows': [
          {'id': 1, 'email': 'ada@example.com'},
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  try {
    final connection = await options.connectBackend(
      client: AnySqlHttpBackendClient(client: httpClient),
    );

    try {
      final user = await connection.query(
        'users.findById',
        parameters: AnySqlParameters.document({'id': 1}),
      );
      print(user.firstOrNull);
    } finally {
      await connection.close();
    }
  } finally {
    httpClient.close();
  }
}
