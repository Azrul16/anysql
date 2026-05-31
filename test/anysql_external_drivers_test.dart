@Tags(['external'])
library;

import 'dart:io';

import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';
import 'package:test/test.dart';

void main() {
  test(
    'postgres driver runs a live smoke query',
    () async {
      final connection = await AnySql.connect(
        config: AnySqlConfig.postgres(
          host: _env('ANYSQL_POSTGRES_HOST')!,
          port: _envInt('ANYSQL_POSTGRES_PORT') ?? 5432,
          database: _env('ANYSQL_POSTGRES_DATABASE') ?? 'postgres',
          username: _env('ANYSQL_POSTGRES_USERNAME'),
          password: _env('ANYSQL_POSTGRES_PASSWORD'),
          sslEnabled: _envBool('ANYSQL_POSTGRES_SSL'),
        ),
        driver: const PostgresAnySqlDriver(),
      );

      try {
        final result = await connection.query('select 1 as value');
        expect(result.first['value'], 1);
      } finally {
        await connection.close();
      }
    },
    skip: _skipUnless('ANYSQL_POSTGRES_HOST'),
  );

  test('mysql driver runs a live smoke query', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.mysql(
        host: _env('ANYSQL_MYSQL_HOST')!,
        port: _envInt('ANYSQL_MYSQL_PORT') ?? 3306,
        database: _env('ANYSQL_MYSQL_DATABASE') ?? 'mysql',
        username: _env('ANYSQL_MYSQL_USERNAME'),
        password: _env('ANYSQL_MYSQL_PASSWORD'),
        sslEnabled: _envBool('ANYSQL_MYSQL_SSL'),
      ),
      driver: const MysqlAnySqlDriver(),
    );

    try {
      final result = await connection.query('select 1 as value');
      expect(result.first['value'].toString(), '1');
    } finally {
      await connection.close();
    }
  }, skip: _skipUnless('ANYSQL_MYSQL_HOST'));

  test(
    'mongodb driver runs a live smoke command',
    () async {
      final uri = _env('ANYSQL_MONGODB_URI');
      final connection = await AnySql.connect(
        config: AnySqlConfig.mongodb(
          host: _env('ANYSQL_MONGODB_HOST') ?? 'localhost',
          port: _envInt('ANYSQL_MONGODB_PORT') ?? 27017,
          database: _env('ANYSQL_MONGODB_DATABASE') ?? 'test',
          username: _env('ANYSQL_MONGODB_USERNAME'),
          password: _env('ANYSQL_MONGODB_PASSWORD'),
          sslEnabled: _envBool('ANYSQL_MONGODB_SSL'),
          options: uri == null ? const {} : {'uri': uri},
        ),
        driver: const MongodbAnySqlDriver(),
      );

      try {
        final result = await connection.query('anysql_smoke.count');
        expect(result.first['count'], isA<int>());
      } finally {
        await connection.close();
      }
    },
    skip: _skipUnlessAny(['ANYSQL_MONGODB_HOST', 'ANYSQL_MONGODB_URI']),
  );
}

String? _env(String name) {
  final value = Platform.environment[name];
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
}

int? _envInt(String name) {
  final value = _env(name);
  if (value == null) {
    return null;
  }

  return int.parse(value);
}

bool _envBool(String name) {
  final value = _env(name)?.toLowerCase();
  return value == 'true' || value == '1' || value == 'yes';
}

String? _skipUnless(String name) {
  return _env(name) == null ? 'Set $name to run this live driver test.' : null;
}

String? _skipUnlessAny(List<String> names) {
  if (names.any((name) => _env(name) != null)) {
    return null;
  }

  return 'Set one of ${names.join(', ')} to run this live driver test.';
}
