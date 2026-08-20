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

    test('Flow 5: Multi-Agent Orchestrator & Subagent Delegation with ObjectHeap Handle Exchange',
        () async {
      final heap = ObjectHeap();
      final tracer = Tracer('OrchestratorAgent');

      // Subagent 1: Worker Agent produces dataset into shared heap
      final workerHeap = ObjectHeap();
      final sampleData = List.generate(100, (i) => {'id': i, 'metric': i * 2.5});
      final ref = workerHeap.put(sampleData, label: '100 metric records');

      expect(ref.handle, equals('#ref_1'));

      // Transfer handle to coordinator
      final coordinatorRef = heap.put(
        workerHeap.get(ref.handle),
        label: 'Imported metric records from worker',
      );

      expect(coordinatorRef.handle, equals('#ref_1'));
      final coordinatorData = heap.get(coordinatorRef.handle) as List<Map<String, dynamic>>?;
      expect(coordinatorData, isNotNull);
      expect(coordinatorData!.length, equals(100));

      tracer.record(
        type: TraceEventType.subagentSpawn,
        stepIndex: 0,
        description: 'Spawned DataWorker subagent with handle ${coordinatorRef.handle}',
      );

      final jsonl = tracer.exportJsonL();
      expect(jsonl, contains('Spawned DataWorker subagent'));
      expect(jsonl, contains('#ref_1'));
    });

    test('Flow 6: Adaptive Resource Governor Live Throttling & Self-Balancing Loop',
        () async {
      final mockModel = MockModelClient();
      final harness = DefaultDeviceHarness(
        initialStatus: const DeviceStatus(
          batteryLevel: 0.55,
          isCharging: false,
          thermalState: ThermalState.severe,
          availableRamMb: 3200,
          totalRamMb: 8192,
        ),
      );

      // Step 1: Agent inspects device headroom
      mockModel.queueToolCall(
        toolName: 'assessResourceHeadroom',
        arguments: const {},
        thought: 'Inspecting device thermals and RAM.',
      );

      // Step 2: Agent reacts to severe thermal state by applying cloud offload policy
      mockModel.queueToolCall(
        toolName: 'applyGovernorPolicy',
        arguments: const {
          'targetModelTier': 'cloudOffload',
          'maxConcurrent': 1,
          'pacingDelayMs': 300,
        },
        thought: 'Applying thermal cooling policy.',
      );

      mockModel.queueText('Self-governance active: Switched to cloudOffload with 300ms pacing delay.');

      final agent = Quickstart.createAgent(
        () => AutonomousDeviceAgent(),
        harness: HarnessApi(device: harness),
        model: mockModel,
      );

      final result = await agent.ellipsis<String>(
        'Assess thermals and prevent device overdraw',
        maxSteps: 4,
      );

      expect(result, contains('Self-governance active'));
      final policy = agent.getState('governor_policy') as Map?;
      expect(policy, isNotNull);
      expect(policy!['targetModelTier'], equals('cloudOffload'));
      expect(policy['pacingDelayMs'], equals(300));
    });

    test('Flow 7: CodeAct Sandboxed AST Execution & Direct Heap Handle Arithmetic',
        () async {
      final heap = ObjectHeap();
      final harness = HarnessApi();
      final rawNumbers = [10, 20, 30, 40, 50];
      final handle = heap.put(rawNumbers, label: 'Array of 5 numbers');

      final env = SandboxedEnvironment(heap: heap, harness: harness);
      env.setVar('raw_handle', handle.handle);

      const snippet = '''
        a = 100
        b = 50
        result = a + b
        return result
      ''';

      // Security check
      const guardrails = AstGuardrails();
      final validation = guardrails.validate(snippet);
      expect(validation.isValid, isTrue);

      final codeAct = CodeActEngine(env, guardrails: guardrails);
      final evalResult = await codeAct.execute(snippet);

      expect(evalResult.success, isTrue);
      expect(evalResult.returnValue, equals(150));

      // Wrap output back in heap
      final outputRef = heap.maybeWrap(evalResult.returnValue);
      expect(outputRef, equals(150)); // Small primitive is inlined, not wrapped
    });

    test('Flow 8: Full End-to-End Android Bridge Dispatcher Protocol Execution',
        () async {
      final mockModel = MockModelClient();
      mockModel.queueToolCall(
        toolName: 'getDeviceInfo',
        arguments: const {},
        thought: 'Fetching battery info over bridge.',
      );
      mockModel.queueText('Battery is 85%. Bridge execution successful.');

      final dispatcher = AgentBridgeDispatcher.withDefaults();
      dispatcher.registerModelProvider('mock', (config) => mockModel);

      final request = {
        'action': 'runAgentLoop',
        'agentName': 'AutonomousDeviceAgent',
        'model': {'provider': 'mock'},
        'goal': 'Check battery status via bridge',
        'maxSteps': 3,
      };

      final response = await dispatcher.handle(request);

      expect(response['result'], contains('Battery is 85%'));
      expect(response['agentName'], equals('AutonomousDeviceAgent'));
      expect(response['trace'], isNotNull);
      final traceEvents = response['trace'] as List;
      expect(traceEvents.isNotEmpty, isTrue);
    });
  });
}
