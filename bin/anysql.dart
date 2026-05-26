import 'dart:io';

import 'package:anysql/anysql.dart';
import 'package:anysql/src/setup_file_generator.dart';

void main(List<String> arguments) {
  final startsWithSetupOption =
      arguments.isNotEmpty &&
      arguments.first.startsWith('--') &&
      arguments.first != '--help';
  final command = arguments.isEmpty || startsWithSetupOption
      ? 'setup'
      : arguments.first;
  final commandArguments = arguments.isEmpty
      ? const <String>[]
      : startsWithSetupOption
      ? arguments
      : arguments.skip(1).toList();

  switch (command) {
    case 'i':
    case 'init':
      _init(commandArguments);
    case 's':
    case 'setup':
      _setup(commandArguments);
    case 'c':
    case 'configure':
      _configure(commandArguments);
    case 'help':
    case '--help':
    case '-h':
      _printHelp();
    default:
      stderr.writeln('Unknown command: $command');
      _printHelp();
      exitCode = 64;
  }
}

void _setup(List<String> arguments) {
  final args = _Args(arguments);
  final unknownOptions = args.unknownOptions(_knownSetupOptions);
  if (unknownOptions.isNotEmpty) {
    stderr.writeln('Unknown option: ${unknownOptions.first}');
    exitCode = 64;
    return;
  }

  if (args.has('help')) {
    _printHelp();
    return;
  }

  stdout.writeln('AnySQL setup');
  stdout.writeln(
    'Choose one database to configure, like Firebase project setup.',
  );
  stdout.writeln('');
  stdout.writeln('1. PostgreSQL');
  stdout.writeln('2. MySQL');
  stdout.writeln('3. SQLite');
  stdout.writeln('4. MongoDB');

  final dialectValue = _prompt(
    'Database [1-4 or postgres/mysql/sqlite/mongodb]',
    defaultValue: '1',
  );
  final dialect = _parseDialectChoice(dialectValue);
  if (dialect == null || dialect == AnySqlDialect.custom) {
    stderr.writeln('Unsupported database: $dialectValue');
    exitCode = 64;
    return;
  }

  stdout.writeln('');
  stdout.writeln(
    'The generated file will contain TODO credential placeholders.',
  );
  stdout.writeln('Edit lib/anysql_options.dart after setup.');

  final className = args.value('class-name') ?? 'DefaultAnySqlOptions';
  if (!_isValidDartClassName(className)) {
    stderr.writeln('Invalid --class-name value: $className');
    exitCode = 64;
    return;
  }

  final output = args.value('output') ?? 'lib/anysql_options.dart';
  final input = AnySqlSetupInput(
    dialect: dialect,
    database: 'placeholder',
    className: className,
  );

  _writeConfiguredOptionsFile(
    input: input,
    output: output,
    force: args.has('force'),
    firebaseStyle: true,
  );
}

void _init(List<String> arguments) {
  final args = _Args(arguments);
  final unknownOptions = args.unknownOptions(_knownInitOptions);
  if (unknownOptions.isNotEmpty) {
    stderr.writeln('Unknown option: ${unknownOptions.first}');
    exitCode = 64;
    return;
  }

  if (args.has('help')) {
    _printHelp();
    return;
  }

  final className = args.value('class-name') ?? 'AnySqlOptionsFile';
  if (!_isValidDartClassName(className)) {
    stderr.writeln('Invalid --class-name value: $className');
    exitCode = 64;
    return;
  }

  try {
    final output = args.value('output') ?? 'lib/anysql_options.dart';
    final outputFile = File(output);
    if (outputFile.existsSync() && !args.has('force')) {
      stderr.writeln(
        '$output already exists. Re-run with --force to overwrite.',
      );
      exitCode = 73;
      return;
    }

    final contents = generateAnySqlSampleOptionsFile(className: className);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(contents);
    stdout.writeln('Created $output');
  } on Object catch (error) {
    stderr.writeln('Failed to create sample options file: $error');
    exitCode = 1;
  }
}

void _configure(List<String> arguments) {
  final args = _Args(arguments);
  final unknownOptions = args.unknownOptions(_knownConfigureOptions);
  if (unknownOptions.isNotEmpty) {
    stderr.writeln('Unknown option: ${unknownOptions.first}');
    exitCode = 64;
    return;
  }

  if (args.has('help')) {
    _printHelp();
    return;
  }

  final dialectValue = args.value('dialect') ?? 'postgres';
  final dialect = _parseDialect(dialectValue);
  if (dialect == null || dialect == AnySqlDialect.custom) {
    stderr.writeln('Unsupported dialect: $dialectValue');
    exitCode = 64;
    return;
  }

  final database = args.value('database');
  if (database == null || database.trim().isEmpty) {
    stderr.writeln('Missing required option: --database');
    exitCode = 64;
    return;
  }

  final host = args.value('host');
  if (dialect != AnySqlDialect.sqlite &&
      (host == null || host.trim().isEmpty)) {
    stderr.writeln('Missing required option for ${dialect.name}: --host');
    exitCode = 64;
    return;
  }
  if (dialect == AnySqlDialect.sqlite) {
    final sqliteOnlyOptions = [
      'host',
      'port',
      'username',
      'password-env',
      'ssl',
    ].where(args.containsOption).toList();
    if (sqliteOnlyOptions.isNotEmpty) {
      stderr.writeln(
        'Unsupported option for sqlite: --${sqliteOnlyOptions.first}',
      );
      exitCode = 64;
      return;
    }
  }

  final passwordEnvironmentKey = args.value('password-env');

  final port = args.value('port') == null
      ? null
      : int.tryParse(args.value('port')!);
  if (args.value('port') != null && port == null) {
    stderr.writeln('Invalid --port value: ${args.value('port')}');
    exitCode = 64;
    return;
  }
  if (port != null && (port < 1 || port > 65535)) {
    stderr.writeln('Port must be between 1 and 65535: $port');
    exitCode = 64;
    return;
  }

  final backendUrl = args.value('backend-url');
  if (backendUrl != null) {
    final uri = Uri.tryParse(backendUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      stderr.writeln('Invalid --backend-url value: $backendUrl');
      exitCode = 64;
      return;
    }
  }

  final className = args.value('class-name') ?? 'DefaultAnySqlOptions';
  if (!_isValidDartClassName(className)) {
    stderr.writeln('Invalid --class-name value: $className');
    exitCode = 64;
    return;
  }

  final backendHeaders = args.values('backend-header');
  final parsedBackendHeaders = <String, String>{};
  for (final header in backendHeaders) {
    final separator = header.indexOf('=');
    if (separator <= 0) {
      stderr.writeln('Invalid --backend-header value: $header');
      stderr.writeln('Use --backend-header Name=Value.');
      exitCode = 64;
      return;
    }
    parsedBackendHeaders[header.substring(0, separator)] = header.substring(
      separator + 1,
    );
  }

  final input = AnySqlSetupInput(
    dialect: dialect,
    host: host,
    port: port,
    database: database,
    username: args.value('username'),
    passwordEnvironmentKey: passwordEnvironmentKey,
    sslEnabled: args.has('ssl'),
    backendUrl: backendUrl,
    backendHeaders: parsedBackendHeaders,
    className: className,
  );

  _writeConfiguredOptionsFile(
    input: input,
    output: args.value('output') ?? 'lib/anysql_options.dart',
    force: args.has('force'),
  );
}

void _writeConfiguredOptionsFile({
  required AnySqlSetupInput input,
  required String output,
  required bool force,
  bool firebaseStyle = false,
}) {
  final outputFile = File(output);
  if (outputFile.existsSync() && !force) {
    stderr.writeln('$output already exists. Re-run with --force to overwrite.');
    exitCode = 73;
    return;
  }

  try {
    final contents = firebaseStyle
        ? generateAnySqlFirebaseStyleOptionsFile(input)
        : generateAnySqlOptionsFile(input);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(contents);
    stdout.writeln('Created $output');
  } on Object catch (error) {
    stderr.writeln('Failed to create options file: $error');
    exitCode = 1;
  }
}

AnySqlDialect? _parseDialect(String value) {
  for (final dialect in AnySqlDialect.values) {
    if (dialect.name == value) {
      return dialect;
    }
  }

  return null;
}

AnySqlDialect? _parseDialectChoice(String value) {
  return switch (value.trim().toLowerCase()) {
    '1' || 'postgres' || 'postgresql' => AnySqlDialect.postgres,
    '2' || 'mysql' => AnySqlDialect.mysql,
    '3' || 'sqlite' || 'sqllite' => AnySqlDialect.sqlite,
    '4' || 'mongodb' || 'mongo' => AnySqlDialect.mongodb,
    _ => _parseDialect(value),
  };
}

void _printHelp() {
  stdout.writeln('''
anysql

Usage:
  dart run anysql
  dart run anysql init
  dart run anysql setup
  dart run anysql configure --dialect postgres --host localhost --database app

Options:
  --dialect       postgres, mysql, sqlite, or mongodb. Defaults to postgres.
  --host          Database host. Required except for sqlite.
                  Not supported for sqlite.
  --port          Database port. Not supported for sqlite.
  --database      Database name or sqlite path. Required.
  --username      Database username. Not supported for sqlite.
  --password-env  Dart define key for the password, for example ANYSQL_PASSWORD.
                  Not supported for sqlite.
  --ssl           Enable SSL in the generated config. Not supported for sqlite.
  --backend-url   Optional backend API URL for mobile apps.
  --backend-header Optional backend header in Name=Value format. Repeatable.
  --output        Output file. Defaults to lib/anysql_options.dart.
  --class-name    Generated class name.
                  Defaults to AnySqlOptionsFile for init.
                  Defaults to DefaultAnySqlOptions for configure.
  --force         Overwrite the output file if it already exists.

Init command:
  Creates lib/anysql_options.dart with editable dummy configs for PostgreSQL,
  MySQL, SQLite, and MongoDB.

Setup command:
  Asks which built-in database you want and creates one focused
  lib/anysql_options.dart file with editable values and keyword-store helpers.
  `dart run anysql` is the short form for setup.
''');
}

String _prompt(String label, {String? defaultValue}) {
  final suffix = defaultValue == null ? '' : ' ($defaultValue)';
  stdout.write('$label$suffix: ');
  final value = stdin.readLineSync()?.trim() ?? '';
  if (value.isEmpty && defaultValue != null) {
    return defaultValue;
  }

  return value;
}

final class _Args {
  _Args(this._arguments);

  final List<String> _arguments;

  bool has(String name) => _arguments.contains('--$name');

  String? value(String name) {
    final found = values(name);
    if (found.isEmpty) {
      return null;
    }

    return found.first;
  }

  List<String> values(String name) {
    final prefix = '--$name=';
    final found = <String>[];
    for (var index = 0; index < _arguments.length; index += 1) {
      final argument = _arguments[index];
      if (argument.startsWith(prefix)) {
        found.add(argument.substring(prefix.length));
      }
      if (argument == '--$name' && index + 1 < _arguments.length) {
        final next = _arguments[index + 1];
        if (!next.startsWith('--')) {
          found.add(next);
        }
      }
    }

    return found;
  }

  List<String> unknownOptions(Set<String> knownOptions) {
    final unknown = <String>[];
    for (final argument in _arguments) {
      if (!argument.startsWith('--')) {
        continue;
      }

      final option = argument.substring(2).split('=').first;
      if (!knownOptions.contains(option)) {
        unknown.add('--$option');
      }
    }

    return unknown;
  }

  bool containsOption(String name) {
    final prefix = '--$name=';
    return _arguments.any(
      (argument) => argument == '--$name' || argument.startsWith(prefix),
    );
  }
}

const _knownConfigureOptions = {
  'backend-header',
  'backend-url',
  'class-name',
  'database',
  'dialect',
  'force',
  'help',
  'host',
  'output',
  'password-env',
  'port',
  'ssl',
  'username',
};

const _knownInitOptions = {'class-name', 'force', 'help', 'output'};

const _knownSetupOptions = {'class-name', 'force', 'help', 'output'};

bool _isValidDartClassName(String value) {
  return RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(value);
}
