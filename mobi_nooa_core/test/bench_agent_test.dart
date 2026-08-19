import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class MockShellHarness implements ShellHarness {
  @override
  String workingDirectory = '/workspace/project';
  final List<String> executedCommands = [];

  @override
  Future<ShellExecutionResult> execute(
    String command, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    executedCommands.add(command);
    if (command == 'pytest') {
      return ShellExecutionResult(
        exitCode: 0,
        stdout: '1 passed, 0 failed in 0.42s',
        stderr: '',
        duration: const Duration(milliseconds: 420),
      );
    }
    return ShellExecutionResult(
      exitCode: 0,
      stdout: 'Command executed: $command',
      stderr: '',
      duration: const Duration(milliseconds: 100),
    );
  }
}

void main() {
  group('BenchAgent & Coding Tool Suite Tests', () {
    late MemoryFileSystemHarness fs;
    late ObjectHeap heap;
    late MockModelClient mockModel;
    late Tracer tracer;
    late MockShellHarness mockShell;
    late BenchAgent benchAgent;
    late AgentContext context;

    setUp(() {
      fs = MemoryFileSystemHarness({
        '/workspace/project/main.py': 'def calculate():\n    return 41\n',
        '/workspace/project/test_main.py': 'def test_calc():\n    assert calculate() == 42\n',
      });
      heap = ObjectHeap();
      mockModel = MockModelClient();
      tracer = Tracer('BenchAgentTest');
      mockShell = MockShellHarness();

      final harness = HarnessApi(fs: fs);
      context = AgentContext(
        heap: heap,
        model: mockModel,
        harness: harness,
        tracer: tracer,
      );

      benchAgent = BenchAgent(shellHarness: mockShell);
      benchAgent.attachContext(context);
    });

    test('FileEditorTool: viewFile with line numbering', () async {
      final editor = FileEditorTool(fs: fs);
      final result = await editor.viewFile('/workspace/project/main.py');

      expect(result.success, isTrue);
      expect(result.output, contains('1 | def calculate():'));
      expect(result.output, contains('2 |     return 41'));
    });

    test('FileEditorTool: strReplace with uniqueness check', () async {
      final editor = FileEditorTool(fs: fs);
      final result = await editor.strReplace(
        '/workspace/project/main.py',
        oldStr: 'return 41',
        newStr: 'return 42',
      );

      expect(result.success, isTrue);
      expect(await fs.readFile('/workspace/project/main.py'), contains('return 42'));
    });

    test('CodeSearchTool: grep and symbol outline extraction', () async {
      final search = CodeSearchTool(fs: fs);
      final grepMatches = await search.grep(query: 'return', rootPath: '/workspace/project');
      expect(grepMatches.length, equals(1));
      expect(grepMatches.first.path, equals('/workspace/project/main.py'));

      final symbols = await search.extractSymbols(rootPath: '/workspace/project');
      expect(symbols.any((s) => s.name == 'calculate'), isTrue);
    });

    test('AstGuardrails: blocks dangerous imports and system calls', () {
      const guardrails = AstGuardrails();

      final safeCode = 'a = 10 + 20; return a;';
      final safeRes = guardrails.validate(safeCode);
      expect(safeRes.isValid, isTrue);

      final dangerousCode = 'exit(0);';
      final dangerousRes = guardrails.validate(dangerousCode);
      expect(dangerousRes.isValid, isFalse);
      expect(dangerousRes.violations.first, contains('exit'));
    });

    test('SqliteHarness: creates table and queries data', () async {
      final sqlite = InMemorySqliteHarness();
      await sqlite.execute('CREATE TABLE users (id, name, score)');
      sqlite.insertRecord('users', {'id': 1, 'name': 'Alice', 'score': 95});
      sqlite.insertRecord('users', {'id': 2, 'name': 'Bob', 'score': 88});

      final queryRes = await sqlite.query('SELECT * FROM users');
      expect(queryRes.rows.length, equals(2));
      expect(queryRes.toListOfMaps().first['name'], equals('Alice'));
    });

    test('BenchAgent: completes multi-step bug fix workflow', () async {
      // Step 1: Model views file
      mockModel.queueToolCall(
        toolName: 'viewFile',
        arguments: {'path': '/workspace/project/main.py'},
        thought: 'Inspecting main.py to locate the bug.',
      );

      // Step 2: Model fixes bug via strReplace
      mockModel.queueToolCall(
        toolName: 'strReplace',
        arguments: {
          'path': '/workspace/project/main.py',
          'oldStr': 'return 41',
          'newStr': 'return 42',
        },
        thought: 'Replacing 41 with 42.',
      );

      // Step 3: Model runs test via shell
      mockModel.queueToolCall(
        toolName: 'runShell',
        arguments: {'command': 'pytest'},
        thought: 'Running pytest to verify test passes.',
      );

      // Step 4: Model finishes
      mockModel.queueText('Fixed calculation bug and verified pytest passes.');

      final output = await benchAgent.ellipsis<String>('Fix calculation bug in main.py');
      expect(output, contains('Fixed calculation bug'));

      // Check explicit state
      expect(benchAgent.getState('editedFiles'), equals(['/workspace/project/main.py']));
      expect(benchAgent.getState('commandHistory'), equals(['pytest']));
    });
  });
}
