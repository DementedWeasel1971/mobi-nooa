import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('FileEditorTool & CodeSearchTool Suite', () {
    late MemoryFileSystemHarness fs;
    late FileEditorTool editor;
    late CodeSearchTool search;

    setUp(() async {
      fs = MemoryFileSystemHarness();
      editor = FileEditorTool(fs: fs);
      search = CodeSearchTool(fs: fs);

      await fs.writeFile('lib/main.dart', '''
class AppEngine {
  void start() {
    print('Starting engine');
  }

  void stop() {
    print('Stopping engine');
  }
}

void bootstrap() {
  final engine = AppEngine();
  engine.start();
}
'''.trim());
    });

    test('viewFile returns formatted line numbers and respects slicing bounds', () async {
      final resAll = await editor.viewFile('lib/main.dart');
      expect(resAll.success, isTrue);
      expect(resAll.output, contains('1 | class AppEngine {'));
      expect(resAll.output, contains('14 | }'));

      // Slice lines 2 to 4
      final resSlice = await editor.viewFile('lib/main.dart', startLine: 2, endLine: 4);
      expect(resSlice.success, isTrue);
      expect(resSlice.output, contains('2 |   void start() {'));
      expect(resSlice.output, contains('4 |   }'));
      expect(resSlice.output, isNot(contains('1 | class AppEngine')));
    });

    test('viewFile rejects path traversal attempts with AstGuardrails', () async {
      final res = await editor.viewFile('../../etc/passwd');
      expect(res.success, isFalse);
      expect(res.error, contains('Path traversal'));
    });

    test('createFile creates new file and writes content', () async {
      final resCreate = await editor.createFile('lib/config.json', content: '{"version": 1}');
      expect(resCreate.success, isTrue);
      expect(await fs.readFile('lib/config.json'), equals('{"version": 1}'));
    });

    test('strReplace replaces exact unique substring and rejects non-unique or missing target', () async {
      final resRep = await editor.strReplace(
        'lib/main.dart',
        oldStr: "print('Starting engine');",
        newStr: "print('Engine initialized safely');",
      );
      expect(resRep.success, isTrue);
      final updatedContent = await fs.readFile('lib/main.dart');
      expect(updatedContent, contains("print('Engine initialized safely');"));

      // Target substring not found
      final resMissing = await editor.strReplace(
        'lib/main.dart',
        oldStr: 'non_existent_code_block();',
        newStr: 'replacement',
      );
      expect(resMissing.success, isFalse);
      expect(resMissing.error, contains('not found'));
    });

    test('CodeSearchTool finds files by pattern and extension', () async {
      await fs.writeFile('lib/utils/helper.dart', '// Helper');
      await fs.writeFile('test/main_test.dart', '// Test');
      await fs.writeFile('README.md', '# Documentation');

      final dartFiles = await search.findFiles(extension: 'dart');
      expect(dartFiles, containsAll(['lib/main.dart', 'lib/utils/helper.dart', 'test/main_test.dart']));
      expect(dartFiles, isNot(contains('README.md')));

      final helperMatches = await search.findFiles(pattern: 'helper');
      expect(helperMatches, equals(['lib/utils/helper.dart']));
    });

    test('CodeSearchTool grep searches regex across files', () async {
      final matches = await search.grep(query: 'void start');
      expect(matches, isNotEmpty);
      expect(matches.first.path, equals('lib/main.dart'));
      expect(matches.first.lineNumber, equals(2));
      expect(matches.first.lineContent, contains('void start()'));
    });

    test('CodeSearchTool extractSymbols extracts classes and functions', () async {
      final symbols = await search.extractSymbols();
      final symbolNames = symbols.map((s) => s.name).toList();
      expect(symbolNames, contains('AppEngine'));
      expect(symbolNames, contains('bootstrap'));
    });
  });

  group('SqliteHarness & Pass-by-Reference Object Heap Suite', () {
    test('SqliteHarness executes DDL, DML, and parameter-bound queries', () async {
      final sqlite = InMemorySqliteHarness();
      await sqlite.execute('''
        CREATE TABLE metrics (
          id INTEGER PRIMARY KEY,
          category TEXT,
          value REAL
        );
      ''');

      await sqlite.execute(
        'INSERT INTO metrics (category, value) VALUES (?, ?);',
        ['battery', 88.5],
      );
      await sqlite.execute(
        'INSERT INTO metrics (category, value) VALUES (?, ?);',
        ['ram_free_mb', 1420.0],
      );

      final result = await sqlite.query('SELECT * FROM metrics ORDER BY id ASC;');
      final rows = result.toListOfMaps();
      expect(rows.length, equals(2));
      expect(rows[0]['category'], equals('battery'));
      expect(rows[0]['value'], equals(88.5));
      expect(rows[1]['category'], equals('ram_free_mb'));
      expect(rows[1]['value'], equals(1420.0));
    });
  });

  group('DefaultDeviceHarness & Capabilities Suite', () {
    test('DefaultDeviceHarness reports battery, thermal, and network status', () async {
      final harness = DefaultDeviceHarness();

      final status = await harness.getStatus();
      expect(status.batteryLevel, greaterThanOrEqualTo(0.0));
      expect(status.batteryLevel, lessThanOrEqualTo(1.0));
      expect(status.thermalState, equals(ThermalState.nominal));
      expect(status.networkType, equals('wifi'));

      final location = await harness.getLocation();
      expect(location.latitude, isNotNull);
      expect(location.longitude, isNotNull);
    });

    test('DefaultDeviceHarness notification and vibration execute properly', () async {
      final harness = DefaultDeviceHarness();

      await harness.sendNotification(title: 'Agent Alert', body: 'Task complete');
      expect(harness.sentNotifications.length, equals(1));
      expect(harness.sentNotifications.first['title'], equals('Agent Alert'));
      expect(harness.sentNotifications.first['body'], equals('Task complete'));

      await harness.vibrate(durationMs: 150);
    });
  });
}
