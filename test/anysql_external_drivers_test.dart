@Tags(['external'])
library;

import 'dart:io';

import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';
import 'package:test/test.dart';

void main() {
  test('postgres driver runs a live smoke query', () async {
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
      await _checkTransactionIsolation(connection);
      await connection.query(
        'create temporary table anysql_rollback_test (id integer primary key)',
      );
      await expectLater(
        connection.transaction((tx) async {
          await tx.query('insert into anysql_rollback_test values (1)');
          try {
            await tx.query('insert into anysql_rollback_test values (1)');
          } on AnySqlQueryException {
            // The callback returns normally after the server aborted its tx.
          }
        }),
        throwsA(isA<AnySqlQueryException>()),
      );
      expect(
        (await connection.query('select * from anysql_rollback_test')).rows,
        isEmpty,
      );
    } finally {
      await connection.close();
    }
  }, skip: _skipUnless('ANYSQL_POSTGRES_HOST'));

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
      await _checkTransactionIsolation(connection);
      await connection.query(
        'create temporary table anysql_set_test (id integer primary key, '
        'email varchar(100) not null unique, name varchar(100) not null) '
        'engine=InnoDB',
      );
      final users = connection
          .store(dialect: AnySqlDialect.mysql)
          .collection('anysql_set_test');
      await users.doc(1).set({'email': 'ada@example.com', 'name': 'Ada'});
      await expectLater(
        users.doc(2).set({'email': 'ada@example.com', 'name': 'Grace'}),
        throwsA(isA<AnySqlQueryException>()),
      );
      expect((await users.doc(1).first())?['name'], 'Ada');
      expect(await users.doc(2).first(), isNull);
      await users.doc(1).set({'name': 'Ada Lovelace'});
      expect((await users.doc(1).first())?['name'], 'Ada Lovelace');
    } finally {
      await connection.close();
    }
  }, skip: _skipUnless('ANYSQL_MYSQL_HOST'));

  test('mongodb driver runs a live smoke command', () async {
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
      final marker = DateTime.now().microsecondsSinceEpoch.toString();
      final documents = connection
          .store(dialect: AnySqlDialect.mongodb)
          .collection('anysql_smoke', idField: '_id');
      try {
        final inserted = await documents.add({'anysqlTestRun': marker});
        expect(inserted.affectedRows, 1);
        expect(inserted.lastInsertId, isNotNull);
        expect(
          (await documents
              .doc(inserted.lastInsertId)
              .first())?['anysqlTestRun'],
          marker,
        );
        final bulk = await documents.addAll([
          {'anysqlTestRun': marker},
          {'anysqlTestRun': marker},
        ]);
        expect(bulk.affectedRows, 2);
        expect(
          await documents.where('anysqlTestRun', isEqualTo: marker).count(),
          3,
        );
        expect((await documents.limit(0).get()).rows, isEmpty);
        expect(await documents.limit(0).first(), isNull);

        await expectLater(
          documents.add({
            '_id': inserted.lastInsertId,
            'anysqlTestRun': marker,
          }),
          throwsA(
            isA<AnySqlQueryException>().having(
              (error) => error.cause,
              'write failure details',
              containsPair('writeErrors', 1),
            ),
          ),
        );
        await expectLater(
          documents.addAll([
            {'_id': 'anysql-$marker', 'anysqlTestRun': marker},
            {'_id': inserted.lastInsertId, 'anysqlTestRun': marker},
          ]),
          throwsA(
            isA<AnySqlQueryException>().having(
              (error) => error.cause,
              'partial write details',
              allOf(
                containsPair('inserted', 1),
                containsPair('writeErrors', 1),
              ),
            ),
          ),
        );
      } finally {
        await connection.query(
          'anysql_smoke.deleteMany',
          parameters: {
            'filter': {'anysqlTestRun': marker},
          },
        );
      }
    } finally {
      await connection.close();
    }
  }, skip: _skipUnlessAny(['ANYSQL_MONGODB_HOST', 'ANYSQL_MONGODB_URI']));
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

Future<void> _checkTransactionIsolation(AnySqlConnection connection) async {
  late AnySqlTransaction completed;
  final pending = connection.transaction((tx) async {
    completed = tx;
    await expectLater(
      connection.query('select 1'),
      throwsA(isA<AnySqlConnectionException>()),
    );
    await expectLater(
      connection.close(),
      throwsA(isA<AnySqlConnectionException>()),
    );
    await expectLater(
      connection.transaction((_) async {}),
      throwsA(isA<AnySqlConnectionException>()),
    );
    expect((await tx.query('select 1')).rowCount, 1);
  });
  // The connection must be guarded even while BEGIN is awaiting a response.
  await expectLater(
    connection.query('select 1'),
    throwsA(isA<AnySqlConnectionException>()),
  );
  await pending;
  await expectLater(
    completed.query('select 1'),
    throwsA(isA<AnySqlConnectionException>()),
  );
  await expectLater(
    connection.transaction((_) async {
      throw StateError('rollback');
    }),
    throwsStateError,
  );
  expect((await connection.query('select 1')).rowCount, 1);
  final inFlight = connection.query('select 1');
  await expectLater(
    connection.transaction((_) async {}),
    throwsA(isA<AnySqlConnectionException>()),
  );
  await inFlight;
  await connection.transaction((tx) => tx.query('select 1'));
}
