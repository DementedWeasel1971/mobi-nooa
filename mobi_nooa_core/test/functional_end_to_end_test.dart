import 'package:mobi_nooa_core/mobi_nooa_core.dart';
import 'package:test/test.dart';

void main() {
  group('mobi-nooa End-to-End Functional Test Suite', () {
    test('Flow 1: Autonomous Device Triage with Two-Way Skills & Hardware Harness',
        () async {
      final mockModel = MockModelClient();

      // Step 1: Model inspects device battery & hardware status
      mockModel.queueToolCall(
        toolName: 'getDeviceInfo',
        arguments: const {},
        thought: 'Inspecting device hardware telemetry.',
      );

      // Step 2: Model searches for battery triage skill
      mockModel.queueToolCall(
        toolName: 'searchSkills',
        arguments: const {'query': 'battery'},
        thought: 'Looking up procedural triage checklist.',
      );

      // Step 3: Model learns and persists a device optimization skill
      mockModel.queueToolCall(
        toolName: 'learnSkill',
        arguments: const {
          'id': 'pixel-tensor-eco-v1',
          'name': 'Pixel Tensor NPU Power Save Mode',
          'description': 'Disables heavy background NPU polling when battery < 20%',
          'instructions': '1. Stop background sync. 2. Lower refresh rate to 60Hz. 3. Enable dark theme.'
        },
        thought: 'Synthesizing newly discovered remediation skill.',
      );

      // Step 4: Model completes workflow and emits final diagnosis
      mockModel.queueText(
          'Triage complete: Battery is healthy. NPU optimization skill learned and persisted.');

      final agent = Quickstart.createAgent(
        () => AutonomousDeviceAgent(),
        model: mockModel,
      );

      final result = await agent.ellipsis<String>(
        'Triage battery health and store remediation skills',
        maxSteps: 5,
      );

      expect(result, contains('Triage complete'));
      expect(result, contains('NPU optimization skill learned'));

      // Verify telemetry history was recorded
      final history = agent.getState('telemetry_history') as List?;
      expect(history, isNotNull);
      expect(history!.isNotEmpty, isTrue);

      // Verify skill was persisted in SkillStore via harness
      final skills = await agent.context.harness.skill.searchSkills('pixel');
      expect(skills.isNotEmpty, isTrue);
      expect(skills.first['name'], contains('Pixel Tensor'));
    });

    test('Flow 2: Data Analyst Pass-by-Reference Dataset Manipulation & Checkpointing',
        () async {
      final mockModel = MockModelClient();

      // Step 1: Load sample dataset into ObjectHeap
      mockModel.queueToolCall(
        toolName: 'loadSampleDataset',
        arguments: const {'rowCount': 500},
        thought: 'Generating 500 telemetry rows in ObjectHeap.',
      );

      // Step 2: Compute statistics on heap handle #ref_1
      mockModel.queueToolCall(
        toolName: 'computeSummary',
        arguments: const {'handle': '#ref_1'},
        thought: 'Calculating descriptive statistics over handle #ref_1.',
      );

      mockModel.queueText(
          'Analysis finished: Processed dataset #ref_1. Summary metrics computed successfully.');

      final agent = Quickstart.createAgent(
        () => DataAnalystAgent(),
        model: mockModel,
      );

      final result = await agent.ellipsis<String>(
        'Analyze telemetry dataset and compute summary stats',
        maxSteps: 4,
      );

      expect(result, contains('Analysis finished'));

      // Verify heap registered the pass-by-reference handle
      final handles = agent.context.heap.references.map((r) => r.handle).toList();
      expect(handles, contains('#ref_1'));

      final activeHandles = agent.getState('active_handles') as List?;
      expect(activeHandles, contains('#ref_1'));

      // Checkpoint agent state
      final checkpoint = AgentCheckpoint(
        checkpointId: 'chk_data_analysis_001',
        agentName: agent.name,
        stepIndex: 2,
        stateSnapshot: agent.getStateSnapshot(),
        heapReferences: agent.context.heap.references,
        status: 'paused',
      );

      final storage = StateStorageManager(sqlite: InMemorySqliteHarness());
      await storage.initialize();
      await storage.saveCheckpoint(checkpoint);

      // Resume checkpoint
      final resumed = await storage.getLatestCheckpoint(agent.name);
      expect(resumed, isNotNull);
      expect(resumed!.stateSnapshot['active_handles'], contains('#ref_1'));
      expect(resumed.heapReferences.any((r) => r.handle == '#ref_1'), isTrue);
    });

    test('Flow 3: Autonomous Coding Agent File Editing & Safe Shell Execution',
        () async {
      final mockModel = MockModelClient();

      // Step 1: Create a bugged source file
      mockModel.queueToolCall(
        toolName: 'createFile',
        arguments: const {
          'path': '/workspace/math.py',
          'content': 'def add(a, b):\n    return a - b\n'
        },
        thought: 'Writing initial file.',
      );

      // Step 2: Inspect file with line numbering
      mockModel.queueToolCall(
        toolName: 'viewFile',
        arguments: const {'path': '/workspace/math.py'},
        thought: 'Verifying file contents.',
      );

      // Step 3: Apply exact substring fix
      mockModel.queueToolCall(
        toolName: 'strReplace',
        arguments: const {
          'path': '/workspace/math.py',
          'oldStr': 'return a - b',
          'newStr': 'return a + b'
        },
        thought: 'Fixing arithmetic subtraction bug.',
      );

      mockModel.queueText('Fixed arithmetic bug in /workspace/math.py');

      final agent = Quickstart.createAgent(
        () => AutonomousCodingAgent(),
        model: mockModel,
      );

      final result = await agent.ellipsis<String>(
        'Fix subtraction bug in math.py',
        maxSteps: 5,
      );

      expect(result, contains('Fixed arithmetic bug'));
      final fixedContent =
          await agent.context.harness.fs.readFile('/workspace/math.py');
      expect(fixedContent, contains('return a + b'));
    });

    test('Flow 4: End-to-End Tracing, Telemetry, and Memory Isolation',
        () async {
      final memoryStore = CognitiveMemoryStore();
      final aliceScope = OwnerGatedMemoryScope(store: memoryStore, ownerId: 'alice');
      final bobScope = OwnerGatedMemoryScope(store: memoryStore, ownerId: 'bob');

      // Alice stores private preference
      aliceScope.remember(
        id: 'pref_model',
        content: 'Alice prefers Llama 3 8B quantized on-device.',
        importance: 0.95,
      );

      // Verify Bob cannot recall Alice's memory
      final bobRecalls = bobScope.recall();
      expect(bobRecalls.any((m) => m.content.contains('Alice prefers')), isFalse);

      // Verify Alice recalls her memory
      final aliceRecalls = aliceScope.recall();
      expect(aliceRecalls.isNotEmpty, isTrue);
      expect(aliceRecalls.first.content, contains('Alice prefers Llama 3'));

      // Verify Tracer telemetry capture
      final tracer = Tracer('AliceAgent');
      tracer.record(
        type: TraceEventType.agentStart,
        stepIndex: 0,
        description: 'Alice started triage',
      );
      tracer.record(
        type: TraceEventType.agentFinish,
        stepIndex: 1,
        description: 'Alice completed triage',
      );

      final jsonl = tracer.exportJsonL();
      expect(jsonl, contains('Alice started triage'));
      expect(jsonl, contains('Alice completed triage'));
    });
  });
}
