import 'dart:io';

import 'package:anysql/anysql.dart';
import 'package:anysql/src/setup_file_generator.dart';
import 'package:test/test.dart';

void main() {
  final generatedRoot = Directory('.dart_tool/anysql_test_generated');

  setUpAll(() {
    if (generatedRoot.existsSync()) {
      generatedRoot.deleteSync(recursive: true);
    }
    generatedRoot.createSync(recursive: true);
  });

  test('generated configure file analyzes successfully', () async {
    final file = File('${generatedRoot.path}/configured_options.dart');
    file.writeAsStringSync(
      generateAnySqlOptionsFile(
        const AnySqlSetupInput(
          dialect: AnySqlDialect.postgres,
          host: 'localhost',
          database: 'app',
          username: 'postgres',
          passwordEnvironmentKey: 'ANYSQL_PASSWORD',
          backendUrl: 'https://api.example.com/anysql',
          backendHeaders: {'x-client': 'anysql-test'},
        ),
      ),
    );

    await _expectAnalyzeSuccess(file.path);
  });

  test('generated init file analyzes successfully', () async {
    final file = File('${generatedRoot.path}/sample_options.dart');
    file.writeAsStringSync(generateAnySqlSampleOptionsFile());

    await _expectAnalyzeSuccess(file.path);
  });

  test('cli init creates an analyzable options file', () async {
    final output = '${generatedRoot.path}/cli_init_options.dart';
    final result = await _runCli(['init', '--output', output, '--force']);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(output).existsSync(), isTrue);
    expect(result.stdout.toString(), contains('Created $output'));

    await _expectAnalyzeSuccess(output);
  });

  test('cli configure creates an analyzable postgres options file', () async {
    final output = '${generatedRoot.path}/cli_postgres_options.dart';
    final result = await _runCli([
      'configure',
      '--dialect',
      'postgres',
      '--host',
      'localhost',
      '--database',
      'app',
      '--username',
      'postgres',
      '--password-env',
      'ANYSQL_PASSWORD',
      '--backend-url',
      'https://api.example.com/anysql',
      '--backend-header',
      'x-client=anysql-test',
      '--output',
      output,
      '--force',
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(output).existsSync(), isTrue);
    expect(result.stdout.toString(), contains('Created $output'));

    await _expectAnalyzeSuccess(output);
  });

  test('cli configure creates analyzable options for every dialect', () async {
    final arguments = <String, List<String>>{
      'postgres': ['--host', 'localhost', '--database', 'app'],
      'mysql': ['--host', 'localhost', '--database', 'app'],
      'sqlite': ['--database', ':memory:'],
      'mongodb': ['--host', 'localhost', '--database', 'app'],
    };

    for (final entry in arguments.entries) {
      final output = '${generatedRoot.path}/cli_${entry.key}_audit.dart';
      final result = await _runCli([
        'configure',
        '--dialect',
        entry.key,
        ...entry.value,
        '--output',
        output,
        '--force',
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      await _expectAnalyzeSuccess(output);
    }
  });

  test('cli setup creates an analyzable options file from prompts', () async {
    final output = '${generatedRoot.path}/cli_setup_options.dart';
    final result = await _runCliWithInput(
      ['setup', '--output', output, '--force'],
      ['3'],
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(output).existsSync(), isTrue);
    expect(result.stdout.toString(), contains('AnySQL setup'));
    expect(result.stdout.toString(), contains('Choose one database'));
    expect(result.stdout.toString(), contains('Created $output'));

    await _expectAnalyzeSuccess(output);
  });

  test('cli without command runs setup', () async {
    final output = '${generatedRoot.path}/cli_short_setup_options.dart';
    final result = await _runCliWithInput(
      ['--output', output, '--force'],
      ['3'],
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(File(output).existsSync(), isTrue);
    expect(result.stdout.toString(), contains('AnySQL setup'));

    await _expectAnalyzeSuccess(output);
  });

  test('cli setup rejects unknown databases', () async {
    final result = await _runCliWithInput(
      [
        'setup',
        '--output',
        '${generatedRoot.path}/invalid_setup_options.dart',
        '--force',
      ],
      ['oracle'],
    );

    expect(result.exitCode, 64);
    expect(result.stderr.toString(), contains('Unsupported database'));
  });

  test('cli configure rejects sqlite network options', () async {
    final result = await _runCli([
      'configure',
      '--dialect',
      'sqlite',
      '--database',
      'app.db',
      '--host',
      'localhost',
      '--output',
      '${generatedRoot.path}/invalid_sqlite_options.dart',
      '--force',
    ]);

    expect(result.exitCode, 64);
    expect(result.stderr.toString(), contains('Unsupported option for sqlite'));
  });

  test('cli protects existing generated files without force', () async {
    final output = '${generatedRoot.path}/existing_options.dart';
    File(output).writeAsStringSync('// keep me\n');

    final result = await _runCli([
      'configure',
      '--dialect',
      'sqlite',
      '--database',
      'app.db',
      '--output',
      output,
    ]);

    expect(result.exitCode, 73);
    expect(File(output).readAsStringSync(), '// keep me\n');
    expect(result.stderr.toString(), contains('--force'));
  });
}

Future<void> _expectAnalyzeSuccess(String path) async {
  final result = await _runDart(['analyze', path]);
  expect(result.exitCode, 0, reason: result.stdout.toString());
}

Future<ProcessResult> _runDart(List<String> arguments) {
  return Process.run(
    'dart',
    arguments,
    workingDirectory: Directory.current.path,
  );
}

Future<ProcessResult> _runCli(List<String> arguments) {
  return _runDart(['bin/anysql.dart', ...arguments]);
}

Future<ProcessResult> _runCliWithInput(
  List<String> arguments,
  List<String> input,
) async {
  final process = await Process.start('dart', [
    'bin/anysql.dart',
    ...arguments,
  ], workingDirectory: Directory.current.path);

  for (final line in input) {
    process.stdin.writeln(line);
  }
  await process.stdin.close();

  final stdoutText = await process.stdout
      .transform(systemEncoding.decoder)
      .join();
  final stderrText = await process.stderr
      .transform(systemEncoding.decoder)
      .join();
  final exitCode = await process.exitCode;

  return ProcessResult(process.pid, exitCode, stdoutText, stderrText);
}
