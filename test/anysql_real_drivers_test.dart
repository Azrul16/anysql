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

  test('built-in drivers declare optional capabilities', () {
    expect(const PostgresAnySqlDriver().capabilities.transactions, isTrue);
    expect(const PostgresAnySqlDriver().capabilities.returningRows, isTrue);
    expect(const MysqlAnySqlDriver().capabilities.transactions, isTrue);
    expect(const MysqlAnySqlDriver().capabilities.returningRows, isFalse);
    expect(const SqliteAnySqlDriver().capabilities.upsert, isTrue);
    expect(const MongodbAnySqlDriver().capabilities.aggregation, isTrue);
    expect(const MongodbAnySqlDriver().capabilities.transactions, isFalse);
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

  test(
    'sqlite prepares commented reads, CTE writes, and returning writes',
    () async {
      final connection = await const SqliteAnySqlDriver().connect(
        AnySqlConfig.sqlite(database: ':memory:'),
      );
      addTearDown(connection.close);
      await connection.query(
        'create table items (id integer primary key, value text)',
      );
      final inserted = await connection.query(
        "/* insert */ with v as (select 'first' as value) "
        'insert into items(value) select value from v returning id, value',
      );
      expect(inserted.affectedRows, 1);
      expect(inserted.lastInsertId, 1);
      expect(inserted.first, {'id': 1, 'value': 'first'});
      for (final prefix in ['-- read\n', '/* read */ ', '']) {
        final read = await connection.query('${prefix}select * from items');
        expect(read.rowCount, 1);
        expect(read.affectedRows, 0);
        expect(read.lastInsertId, isNull);
      }
      expect(
        (await connection.query(
          'explain query plan select * from items',
        )).rowCount,
        greaterThan(0),
      );
      await expectLater(
        connection.query(
          "insert into items(value) values ('ignored'); select * from items",
        ),
        throwsA(isA<AnySqlQueryException>()),
      );
      expect((await connection.query('select * from items')).rowCount, 1);
      final updated = await connection.query(
        "with v as (select 'second' as value) update items set value = (select value from v)",
      );
      expect(updated.affectedRows, 1);
      expect(updated.lastInsertId, isNull);
      final returned = await connection.query(
        "update items set value = 'third' returning value",
      );
      expect(returned.affectedRows, 1);
      expect(returned.first, {'value': 'third'});
      final missing = await connection.query(
        'delete from items where id = 999 returning id',
      );
      expect(missing.rows, isEmpty);
      expect(missing.affectedRows, 0);
      final deleted = await connection.query('delete from items returning id');
      expect(deleted.affectedRows, 1);
      expect(deleted.first, {'id': 1});
      final ddl = await connection.query('create table other (id integer)');
      expect(ddl.affectedRows, 0);
      await connection.transaction((tx) async {
        final write = await tx.query(
          "insert into items(value) values ('transaction') returning id",
        );
        expect(write.affectedRows, 1);
        expect(write.rowCount, 1);
      });
    },
  );

  test(
    'sqlite rejects parent operations and nested transactions while active',
    () async {
      final connection = await const SqliteAnySqlDriver().connect(
        AnySqlConfig.sqlite(database: ':memory:'),
      );
      addTearDown(connection.close);
      late AnySqlTransaction completed;
      await connection.transaction((tx) async {
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
        expect((await tx.query('select 1 as value')).first['value'], 1);
        await tx.commit();
        await expectLater(
          connection.query('select 1'),
          throwsA(isA<AnySqlConnectionException>()),
        );
      });
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
      await connection.transaction((tx) => tx.query('select 1'));
    },
  );

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
      throwsA(isA<AnySqlConnectionException>()),
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
