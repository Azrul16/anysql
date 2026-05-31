import 'package:anysql/anysql.dart';
import 'package:anysql/anysql_drivers.dart';
import 'package:test/test.dart';

void main() {
  test('built-in drivers report supported dialects', () {
    final drivers = [
      (const PostgresAnySqlDriver(), AnySqlDialect.postgres),
      (const MysqlAnySqlDriver(), AnySqlDialect.mysql),
      (const SqliteAnySqlDriver(), AnySqlDialect.sqlite),
      (const MongodbAnySqlDriver(), AnySqlDialect.mongodb),
    ];

    for (final (driver, dialect) in drivers) {
      expect(driver.supports(_configFor(dialect)), isTrue);
    }
  });

  test('mysql driver validates option types before connecting', () async {
    await expectLater(
      const MysqlAnySqlDriver().connect(
        AnySqlConfig.mysql(
          host: 'localhost',
          database: 'app',
          options: {'collation': 123},
        ),
      ),
      throwsA(isA<AnySqlConfigException>()),
    );

    await expectLater(
      const MysqlAnySqlDriver().connect(
        AnySqlConfig.mysql(
          host: 'localhost',
          database: 'app',
          options: {'timeoutMs': 0},
        ),
      ),
      throwsA(isA<AnySqlConfigException>()),
    );
  });

  test('sqlite driver runs real in-memory queries', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );

    try {
      await connection.query(
        'create table users (id integer primary key, name text not null)',
      );
      final insert = await connection.query(
        'insert into users (name) values (?)',
        parameters: AnySqlParameters.positional(['Ada']),
      );
      final result = await connection.query('select id, name from users');

      expect(insert.affectedRows, 1);
      expect(insert.lastInsertId, 1);
      expect(result.rows, [
        {'id': 1, 'name': 'Ada'},
      ]);
    } finally {
      await connection.close();
    }

    expect(connection.isOpen, isFalse);
  });

  test('sqlite driver returns rows from insert returning', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );

    try {
      await connection.query(
        'create table users (id integer primary key, name text not null)',
      );
      final result = await connection.query(
        'insert into users (name) values (?) returning id, name',
        parameters: AnySqlParameters.positional(['Ada']),
      );

      expect(result.rows, [
        {'id': 1, 'name': 'Ada'},
      ]);
      expect(result.metadata, {
        'columns': ['id', 'name'],
      });
    } finally {
      await connection.close();
    }
  });

  test(
    'sqlite driver does not treat returning in literals as row output',
    () async {
      final connection = await AnySql.connect(
        config: AnySqlConfig.sqlite(database: ':memory:'),
        driver: const SqliteAnySqlDriver(),
      );

      try {
        await connection.query(
          'create table users (id integer primary key, name text not null)',
        );
        final result = await connection.query(
          "insert into users (name) values ('returning')",
        );

        expect(result.rows, isEmpty);
        expect(result.affectedRows, 1);
        expect(result.lastInsertId, 1);
      } finally {
        await connection.close();
      }
    },
  );

  test('sqlite driver ignores returning in comments', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );

    try {
      await connection.query(
        'create table users (id integer primary key, name text not null)',
      );
      final result = await connection.query(
        'insert into users (name) values (?) -- returning id',
        parameters: AnySqlParameters.positional(['Ada']),
      );

      expect(result.rows, isEmpty);
      expect(result.affectedRows, 1);
    } finally {
      await connection.close();
    }
  });

  test('sqlite driver commits and rolls back transactions', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );

    try {
      await connection.query(
        'create table users (id integer primary key, name text not null)',
      );
      await connection.transaction((transaction) async {
        await transaction.query(
          'insert into users (name) values (?)',
          parameters: AnySqlParameters.positional(['Ada']),
        );
      });

      await expectLater(
        connection.transaction((transaction) async {
          await transaction.query(
            'insert into users (name) values (?)',
            parameters: AnySqlParameters.positional(['Grace']),
          );
          throw StateError('rollback');
        }),
        throwsStateError,
      );

      final result = await connection.query('select name from users');

      expect(result.rows, [
        {'name': 'Ada'},
      ]);
    } finally {
      await connection.close();
    }
  });

  test('sqlite driver wraps query errors', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );

    try {
      await expectLater(
        connection.query('select * from missing_table'),
        throwsA(
          isA<AnySqlQueryException>().having(
            (error) => error.message,
            'message',
            contains('Failed to execute SQLite query'),
          ),
        ),
      );
    } finally {
      await connection.close();
    }
  });

  test('sqlite driver rejects queries after close', () async {
    final connection = await AnySql.connect(
      config: AnySqlConfig.sqlite(database: ':memory:'),
      driver: const SqliteAnySqlDriver(),
    );

    await connection.close();

    await expectLater(
      connection.query('select 1'),
      throwsA(isA<AnySqlException>()),
    );
  });
}

AnySqlConfig _configFor(AnySqlDialect dialect) {
  return switch (dialect) {
    AnySqlDialect.postgres => AnySqlConfig.postgres(
      host: 'localhost',
      database: 'app',
    ),
    AnySqlDialect.mysql => AnySqlConfig.mysql(
      host: 'localhost',
      database: 'app',
    ),
    AnySqlDialect.sqlite => AnySqlConfig.sqlite(database: ':memory:'),
    AnySqlDialect.mongodb => AnySqlConfig.mongodb(
      host: 'localhost',
      database: 'app',
    ),
    AnySqlDialect.custom => AnySqlConfig(dialect: AnySqlDialect.custom),
  };
}
