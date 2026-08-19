import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class TestCalculatorAgent extends NooaAgent {
  TestCalculatorAgent()
      : super(
          name: 'TestCalculatorAgent',
          role: 'Arithmetic & Analysis Agent',
          description: 'Calculates values and tracks arithmetic history.',
        );

  @override
  void initAgent() {
    setState('operationsCount', 0);
    setState('history', <String>[]);

    registerAction(
      name: 'addNumbers',
      description: 'Adds two numbers together.',
      parameters: const [
        ToolParameter(name: 'a', type: 'number', description: 'First number'),
        ToolParameter(name: 'b', type: 'number', description: 'Second number'),
      ],
      returnType: 'num',
      invoker: (args) async {
        final a = args['a'] as num;
        final b = args['b'] as num;
        final sum = a + b;

        final count = (getState('operationsCount') as int) + 1;
        setState('operationsCount', count);

        final hist = List<String>.from(getState('history') as List)..add('$a + $b = $sum');
        setState('history', hist);

        return sum;
      },
    );

    registerAction(
      name: 'createLargeArray',
      description: 'Creates a large list of numbers stored in ObjectHeap.',
      parameters: const [
        ToolParameter(name: 'size', type: 'integer', description: 'Array size'),
      ],
      returnType: 'ObjectReference',
      invoker: (args) async {
        final size = (args['size'] as num).toInt();
        return List.generate(size, (i) => i * 10);
      },
    );
  }
}

void main() {
  group('mobi-nooa NOOA 6 Principles Validation', () {
    late ObjectHeap heap;
    late HarnessApi harness;
    late Tracer tracer;
    late MockModelClient mockModel;
    late TestCalculatorAgent agent;
    late AgentContext context;

    setUp(() {
      heap = ObjectHeap();
      harness = HarnessApi();
      tracer = Tracer('TestAgentTracer');
      mockModel = MockModelClient();
      agent = TestCalculatorAgent();
      context = AgentContext(
        heap: heap,
        model: mockModel,
        harness: harness,
        tracer: tracer,
      );
      agent.attachContext(context);
    });

    test('Principle 1: Typed input/output and prompt synthesis from class', () {
      final actions = AgentReflector.getActions(agent);
      expect(actions.length, equals(2));
      expect(actions.first.name, equals('addNumbers'));
      expect(actions.first.parameters.length, equals(2));

      final prompt = AgentReflector.buildSystemPrompt(
        agent: agent,
        heapSummary: heap.toPromptSummary(),
      );

      expect(prompt, contains('# Agent: TestCalculatorAgent'));
      expect(prompt, contains('addNumbers(number a, number b) -> num'));
      expect(prompt, contains('createLargeArray(integer size) -> ObjectReference'));
    });

    test('Principle 2: Pass-by-reference over live objects in ObjectHeap', () {
      final largeList = List.generate(1000, (i) => 'Item $i');
      final ref = heap.put(largeList, label: 'LargeItemSet');

      expect(ref.handle, startsWith('#ref_'));
      expect(heap.size, equals(1));
      expect(ref.typeName, equals('List<String>'));
      expect(ref.preview, contains('Item 0'));
      expect(ref.preview, contains('and 995 more items'));

      // Retrieve live object from handle
      final retrieved = heap.get(ref.handle);
      expect(retrieved, equals(largeList));
      expect((retrieved as List).length, equals(1000));
    });

    test('Principle 3: Code as Action (CodeAct) with Sandboxed Environment', () async {
      final env = SandboxedEnvironment(heap: heap, harness: harness);
      final engine = CodeActEngine(env);

      // Register live object in heap
      final datasetRef = heap.put([10, 20, 30, 40, 50], label: 'TestNumbers');

      final script = '''
      data = heap.get('${datasetRef.handle}')
      total = sum(data)
      average = avg(data)
      print('Calculated total: ' + total)
      return average
      ''';

      final result = await engine.execute(script);
      expect(result.success, isTrue);
      expect(result.returnValue, equals(30.0));
      expect(result.stdout, contains('Calculated total: 150'));
    });

    test('Principle 4: Programmable Loop Engineering and Dynamic Ellipsis', () async {
      // Step 1: Model invokes addNumbers tool
      mockModel.queueToolCall(
        toolName: 'addNumbers',
        arguments: {'a': 15, 'b': 27},
        thought: 'I will calculate 15 + 27.',
      );

      // Step 2: Model returns final answer
      mockModel.queueText('The sum is 42.');

      final output = await agent.ellipsis<String>('Calculate 15 + 27.');
      expect(output, equals('The sum is 42.'));

      // Verify traces
      expect(tracer.events.any((e) => e.type == TraceEventType.toolExecution), isTrue);
      expect(tracer.events.any((e) => e.type == TraceEventType.agentFinish), isTrue);
    });

    test('Principle 5: Explicit Object State and Reactivity', () async {
      expect(agent.getState('operationsCount'), equals(0));

      mockModel.queueToolCall(
        toolName: 'addNumbers',
        arguments: {'a': 100, 'b': 200},
      );
      mockModel.queueText('Result is 300');

      await agent.ellipsis<String>('Add 100 and 200');

      // Check that explicit state updated
      expect(agent.getState('operationsCount'), equals(1));
      expect(agent.getState('history'), equals(['100 + 200 = 300']));

      final snapshot = agent.getStateSnapshot();
      expect(snapshot['operationsCount'], equals(1));
    });

    test('Principle 6: Model-Callable Harness APIs (Device, FS, Memory)', () async {
      // Device Harness
      final status = await harness.device.getStatus();
      expect(status.batteryLevel, greaterThanOrEqualTo(0.0));

      // FileSystem Harness
      await harness.fs.writeFile('/workspace/config.json', '{"agent":"mobi-nooa"}');
      expect(await harness.fs.exists('/workspace/config.json'), isTrue);
      expect(await harness.fs.readFile('/workspace/config.json'), contains('mobi-nooa'));

      // Memory Harness Vector Index
      await harness.memory.indexDocument(MemoryDocument(
        id: 'doc_1',
        content: 'Mobile agent harness for Android',
        embedding: [0.9, 0.1, 0.0],
      ));

      final results = await harness.memory.searchSimilar([0.85, 0.12, 0.0], topK: 1);
      expect(results.length, equals(1));
      expect(results.first.id, equals('doc_1'));
    });
  });
}
