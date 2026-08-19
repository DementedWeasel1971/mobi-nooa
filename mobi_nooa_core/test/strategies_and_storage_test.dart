import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('Execution Strategies, Storage, and BenchmarkSuite Tests', () {
    test('AgentCheckpoint serialization and StateStorageManager persistence', () async {
      final sqlite = InMemorySqliteHarness();
      final storage = StateStorageManager(sqlite: sqlite);
      await storage.initialize();

      final checkpoint = AgentCheckpoint(
        checkpointId: 'chk_101',
        agentName: 'MobileAnalyzer',
        stepIndex: 3,
        stateSnapshot: {'counter': 42, 'target': 'device_audit'},
        heapReferences: [
          ObjectReference(
            handle: '#ref_1',
            typeName: 'List<int>',
            preview: '[1, 2, 3]',
          ),
        ],
        status: 'paused',
      );

      await storage.saveCheckpoint(checkpoint);

      final loaded = await storage.getLatestCheckpoint('MobileAnalyzer');
      expect(loaded, isNotNull);
      expect(loaded!.checkpointId, equals('chk_101'));
      expect(loaded.stepIndex, equals(3));
      expect(loaded.stateSnapshot['counter'], equals(42));
      expect(loaded.heapReferences.length, equals(1));
      expect(loaded.heapReferences.first.handle, equals('#ref_1'));
    });

    test('ReActStrategy parses thoughts and final answers', () async {
      final strategy = ReActStrategy();
      final modelResp = ModelResponse(
        text: 'Thought: I know the answer.\nFinal Answer: 42 is the ultimate answer.',
      );

      final result = await strategy.processResponse(
        agent: Quickstart.createAgent(() => GeneralMobileAgent()),
        modelResponse: modelResp,
        history: [],
      );

      expect(result.shouldContinue, isFalse);
      expect(result.finalOutput, equals('42 is the ultimate answer.'));
    });

    test('PlanAndSolveStrategy produces plan and executes sequentially', () async {
      final strategy = PlanAndSolveStrategy();
      final planResponse = ModelResponse(
        text: '1. Inspect battery\n2. Log status to SQLite',
      );

      final result = await strategy.processResponse(
        agent: Quickstart.createAgent(() => GeneralMobileAgent()),
        modelResponse: planResponse,
        history: [],
      );

      expect(result.shouldContinue, isTrue);
      expect(result.thought, contains('Plan formulated'));
    });

    test('Quickstart helper instantiates and executes an agent in 3 lines', () async {
      final mockModel = MockModelClient();
      mockModel.queueText('Quickstart agent execution ready.');

      final agent = Quickstart.createAgent(
        () => GeneralMobileAgent(),
        model: mockModel,
      );

      final output = await agent.ellipsis<String>('Test quickstart');
      expect(output, contains('Quickstart agent execution ready.'));
    });

    test('BenchmarkSuite evaluates tasks and produces aggregate report', () async {
      final suite = BenchmarkSuite('TestEvaluationSuite');
      suite.addTask(BenchmarkTask(
        id: 'task_001',
        title: 'Simple Addition Task',
        prompt: 'Calculate 10 + 20',
        expectedOutputSubstring: '30',
        maxSteps: 2,
      ));

      final report = await suite.evaluate(() {
        final mockModel = MockModelClient();
        mockModel.queueText('The result is 30.');
        return Quickstart.createAgent(() => GeneralMobileAgent(), model: mockModel);
      });

      expect(report.totalTasks, equals(1));
      expect(report.resolvedTasks, equals(1));
      expect(report.passRate, equals(1.0));
      expect(report.exportJsonL(), contains('task_001'));
    });
  });
}
