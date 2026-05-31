import 'dart:convert';

import 'package:anysql/anysql.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('http backend sends query requests and decodes results', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;

      return http.Response(
        jsonEncode({
          'rows': [
            {'id': 1, 'email': 'ada@example.com'},
          ],
          'affectedRows': 0,
          'metadata': {
            'columns': ['id', 'email'],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final options = AnySqlOptions(
      config: AnySqlConfig.postgres(
        host: 'localhost',
        database: 'app',
        username: 'postgres',
        password: 'placeholder-value',
      ),
      backendUri: Uri.parse('https://api.example.com/anysql'),
      backendHeaders: const {'x-example-auth': 'example-auth-value'},
    );

    final connection = await AnySqlHttpBackendClient(
      client: client,
    ).connect(options);
    final result = await connection.query(
      'users.findById',
      parameters: {'id': 1},
    );

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url, options.backendUri);
    expect(capturedRequest.headers['x-example-auth'], 'example-auth-value');
    expect(body['dialect'], 'postgres');
    expect(body['statement'], 'users.findById');
    expect(body['parameters'], {'id': 1});
    expect(
      body['config'],
      isNot(containsPair('password', 'placeholder-value')),
    );
    expect(result.first, {'id': 1, 'email': 'ada@example.com'});
    expect(result.metadata, {
      'columns': ['id', 'email'],
    });
  });

  test('http backend requires backend URL', () async {
    final options = AnySqlOptions(
      config: AnySqlConfig.sqlite(database: ':memory:'),
    );

    await expectLater(
      AnySqlHttpBackendClient(
        client: MockClient((_) async => http.Response('{}', 200)),
      ).connect(options),
      throwsA(isA<AnySqlConfigException>()),
    );
  });

  test('http backend wraps non-success responses', () async {
    final client = MockClient((request) async {
      return http.Response('nope', 500);
    });
    final options = AnySqlOptions(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      backendUri: Uri.parse('https://api.example.com/anysql'),
    );
    final connection = await AnySqlHttpBackendClient(
      client: client,
    ).connect(options);

    await expectLater(
      connection.query('select 1'),
      throwsA(isA<AnySqlQueryException>()),
    );
  });

  test('http backend rejects non-object responses', () async {
    final connection = await _backendConnectionForResponse('[1, 2, 3]');

    await expectLater(
      connection.query('select 1'),
      throwsA(
        isA<AnySqlQueryException>().having(
          (error) => error.message,
          'message',
          'Backend response must be a JSON object.',
        ),
      ),
    );
  });

  test('http backend rejects malformed rows', () async {
    final connection = await _backendConnectionForResponse(
      jsonEncode({'rows': 'not-a-list'}),
    );

    await expectLater(
      connection.query('select 1'),
      throwsA(
        isA<AnySqlQueryException>().having(
          (error) => error.message,
          'message',
          'Backend response rows must be a list.',
        ),
      ),
    );
  });

  test('http backend rejects non-integer affected rows', () async {
    final connection = await _backendConnectionForResponse(
      jsonEncode({'affectedRows': '1'}),
    );

    await expectLater(
      connection.query('update users set active = true'),
      throwsA(
        isA<AnySqlQueryException>().having(
          (error) => error.message,
          'message',
          'Backend response affectedRows must be an integer.',
        ),
      ),
    );
  });

  test('http backend rejects queries after close', () async {
    final options = AnySqlOptions(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      backendUri: Uri.parse('https://api.example.com/anysql'),
    );
    final connection = await AnySqlHttpBackendClient(
      client: MockClient((_) async => http.Response('{}', 200)),
    ).connect(options);

    await connection.close();

    await expectLater(
      connection.query('select 1'),
      throwsA(isA<AnySqlConnectionException>()),
    );
  });

  test(
    'http backend does not close an injected client with a connection',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests += 1;
        return http.Response('{}', 200);
      });
      final options = AnySqlOptions(
        config: AnySqlConfig.sqlite(database: ':memory:'),
        backendUri: Uri.parse('https://api.example.com/anysql'),
      );
      final backend = AnySqlHttpBackendClient(client: client);

      final first = await backend.connect(options);
      await first.close();
      final second = await backend.connect(options);
      await second.query('select 1');

      expect(requests, 1);
    },
  );
}

Future<AnySqlConnection> _backendConnectionForResponse(String body) {
  final options = AnySqlOptions(
    config: AnySqlConfig.sqlite(database: ':memory:'),
    backendUri: Uri.parse('https://api.example.com/anysql'),
  );
  return AnySqlHttpBackendClient(
    client: MockClient((_) async => http.Response(body, 200)),
  ).connect(options);
}
