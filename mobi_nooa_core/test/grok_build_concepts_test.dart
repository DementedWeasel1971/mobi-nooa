import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('xAI Grok Build Winning Harness Concepts Suite', () {
    // -------------------------------------------------------------
    // Concept 1: GrokClient (xAI API with Reasoning Extraction)
    // -------------------------------------------------------------
    test('GrokClient parses tool calls and extracts <think> reasoning tokens', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://api.x.ai/v1/chat/completions'));
        expect(request.headers['Authorization'], equals('Bearer xai-test-key'));

        final responseBody = {
          'id': 'chatcmpl-grok-99',
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content': '<think>User requested battery diagnostics.</think>Inspecting device status.',
                'tool_calls': [
                  {
                    'id': 'call_grok_01',
                    'type': 'function',
                    'function': {
                      'name': 'getBatteryStatus',
                      'arguments': '{"detailed": true}',
                    },
                  }
                ],
              }
            }
          ],
          'usage': {
            'prompt_tokens': 42,
            'completion_tokens': 18,
            'total_tokens': 60,
          },
        };

        return http.Response(jsonEncode(responseBody), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final grok = GrokClient(
        apiKey: 'xai-test-key',
        modelName: 'grok-2-1212',
        httpClient: mockHttpClient,
      );

      final res = await grok.generate(
        messages: [ModelMessage.user('Triage battery drain')],
      );

      expect(res.text, equals('Inspecting device status.'));
      expect(res.reasoningContent, equals('User requested battery diagnostics.'));
      expect(res.toolCalls, isNotEmpty);
      expect(res.toolCalls.first.name, equals('getBatteryStatus'));
      expect(res.toolCalls.first.arguments['detailed'], isTrue);
      expect(res.usage.totalTokens, equals(60));
    });

    // -------------------------------------------------------------
    // Concept 2: Agent Client Protocol (ACP) JSON-RPC 2.0 Dispatcher
    // -------------------------------------------------------------
    test('AcpDispatcher negotiates ACP initialize and dispatches session operations', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();
      final acp = AcpDispatcher(bridgeDispatcher: dispatcher);

      // 1. ACP Handshake
      final initRes = await acp.handleJsonRpc({
        'jsonrpc': '2.0',
        'id': '1',
        'method': 'initialize',
      });
      expect(initRes.id, equals('1'));
      expect(initRes.error, isNull);
      expect(initRes.result!['protocolVersion'], equals('1.0.0'));
      expect(initRes.result!['capabilities']['subagents'], isTrue);
      expect(initRes.result!['capabilities']['planMode'], isTrue);

      // 2. Agents list via ACP
      final agentsRes = await acp.handleJsonRpc({
        'jsonrpc': '2.0',
        'id': '2',
        'method': 'agents/list',
      });
      expect(agentsRes.result!['agents'], contains('AutonomousDeviceAgent'));

      // 3. Models list via ACP (including grok)
      final modelsRes = await acp.handleJsonRpc({
        'jsonrpc': '2.0',
        'id': '3',
        'method': 'models/list',
      });
      expect(modelsRes.result!['providers'], contains('grok'));
      expect(modelsRes.result!['providers'], contains('deepseek'));

      // 4. Session run via ACP
      final sessionRes = await acp.handleJsonRpc({
        'jsonrpc': '2.0',
        'id': '4',
        'method': 'session/run',
        'params': {
          'agentName': 'GeneralMobileAgent',
          'goal': 'Ping through ACP',
          'modelConfig': {'provider': 'mock'},
        },
      });
      expect(sessionRes.result!['success'], isTrue);

      // 5. Governor Telemetry via ACP
      final telemRes = await acp.handleJsonRpc({
        'jsonrpc': '2.0',
        'id': '5',
        'method': 'governor/telemetry',
      });
      expect(telemRes.result!['telemetry'], isNotNull);

      // 6. Unknown method returns JSON-RPC -32601 error
      final unknownRes = await acp.handleJsonRpc({
        'jsonrpc': '2.0',
        'id': '6',
        'method': 'invalid/method',
      });
      expect(unknownRes.error, isNotNull);
      expect(unknownRes.error!.code, equals(-32601));
    });

    // -------------------------------------------------------------
    // Concept 3: Parallel Subagents & Isolated Workspaces
    // -------------------------------------------------------------
    test('SubagentOrchestrator runs 8-way parallel subagents with isolated workspaces', () async {
      final mockModel = MockModelClient();
      for (int i = 0; i < 8; i++) {
        mockModel.queueText('Subagent task $i finished.');
      }
      final orchestrator = SubagentOrchestrator(
        model: mockModel,
        maxConcurrency: 8,
      );

      final tasks = List.generate(
        8,
        (i) => SubagentTaskSpec(
          id: 'subagent_$i',
          role: 'Worker-$i',
          prompt: 'Execute subtask $i',
          workspaceMode: SubagentWorkspaceMode.isolated,
          maxSteps: 2,
        ),
      );

      final results = await orchestrator.runParallelBatch(tasks);
      expect(results.length, equals(8));
      expect(results.every((r) => r.isSuccess), isTrue);
      expect(results.first.id, equals('subagent_0'));
    });

    // -------------------------------------------------------------
    // Concept 4: Plan-First Mode & Diff Preview
    // -------------------------------------------------------------
    test('PlanModeManager creates plans with diff previews and enforces approval gates', () async {
      bool approvedRequested = false;
      final planManager = PlanModeManager(
        onApprovalRequired: (step) async {
          approvedRequested = true;
          return true; // Human approves the step
        },
      );

      final plan = planManager.createPlan(
        goal: 'Refactor Authentication Module',
        steps: [
          PlanStep(
            id: 'step_1',
            title: 'Read Auth Config',
            description: 'Inspect auth_config.json',
            targetFiles: ['lib/auth_config.json'],
          ),
          PlanStep(
            id: 'step_2',
            title: 'Apply Security Token Hash',
            description: 'Update hash logic with SHA-256',
            targetFiles: ['lib/auth_token.dart'],
            diffPreview: '+ final hash = sha256.convert(token);',
            requiresApproval: true,
          ),
        ],
      );

      expect(plan.totalSteps, equals(2));
      expect(plan.completedSteps, equals(0));
      expect(plan.progressPercentage, equals(0.0));

      // Step 1: No approval required
      final ok1 = await planManager.verifyStepExecution(plan.steps[0]);
      expect(ok1, isTrue);
      planManager.markStepCompleted('step_1', 'Config read successfully.');
      expect(plan.completedSteps, equals(1));
      expect(plan.progressPercentage, equals(50.0));

      // Step 2: Approval required and granted
      final ok2 = await planManager.verifyStepExecution(plan.steps[1]);
      expect(ok2, isTrue);
      expect(approvedRequested, isTrue);
      planManager.markStepCompleted('step_2', 'Applied hash.');
      expect(plan.isComplete, isTrue);
      expect(plan.progressPercentage, equals(100.0));
    });

    // -------------------------------------------------------------
    // Concept 5: Declarative Lifecycle Hooks (hooks.json)
    // -------------------------------------------------------------
    test('AgentLifecycleHooksPlugin executes pre/post step and tool hooks from JSON', () async {
      final hooksPlugin = AgentLifecycleHooksPlugin();

      int preStepCount = 0;
      int postStepCount = 0;

      hooksPlugin.registerHook(HookEventType.preStep, (payload) {
        preStepCount++;
      });
      hooksPlugin.registerHook(HookEventType.postStep, (payload) {
        postStepCount++;
      });

      // Load hooks from hooks.json config
      hooksPlugin.loadFromJson({
        'hooks': [
          {'id': 'hook_decl_1', 'event': 'preStep'},
          {'id': 'hook_decl_2', 'event': 'postStep'},
        ]
      });

      await hooksPlugin.trigger(HookPayload(eventType: HookEventType.preStep));
      expect(preStepCount, equals(1));

      await hooksPlugin.trigger(HookPayload(eventType: HookEventType.postStep));
      expect(postStepCount, equals(1));
    });

    // -------------------------------------------------------------
    // Concept 6: /skillify (Trajectory to Skill Synthesizer)
    // -------------------------------------------------------------
    test('SkillifySynthesizer extracts multi-step session trajectory into reusable Skill', () async {
      final sessionLog = SessionEventLog(sessionId: 'session_triage_01');

      // Simulate a multi-step session
      sessionLog.append(SessionEvent(
        sessionId: 'session_triage_01',
        stepIndex: 0,
        type: SessionEventType.userMessage,
        data: {'prompt': 'Triage high battery drain and vibration alerts'},
      ));
      sessionLog.append(SessionEvent(
        sessionId: 'session_triage_01',
        stepIndex: 1,
        type: SessionEventType.toolCall,
        data: {
          'toolName': 'getBatteryStatus',
          'arguments': {'threshold': 20},
        },
      ));
      sessionLog.append(SessionEvent(
        sessionId: 'session_triage_01',
        stepIndex: 2,
        type: SessionEventType.toolCall,
        data: {
          'toolName': 'vibrateAlert',
          'arguments': {'durationMs': 500},
        },
      ));

      final synthesizedSkill = SkillifySynthesizer.distillSession(
        sessionLog: sessionLog,
        customSkillName: 'battery-vibration-triage',
      );

      expect(synthesizedSkill.name, equals('battery-vibration-triage'));
      expect(synthesizedSkill.description, contains('getBatteryStatus'));
      expect(synthesizedSkill.instructions, contains('Step 1: Execute `getBatteryStatus`'));
      expect(synthesizedSkill.instructions, contains('Step 2: Execute `vibrateAlert`'));
      expect(synthesizedSkill.tags, contains('battery'));

      // Test saving to SkillStore
      final store = InMemorySkillStore();
      await store.saveSkill(synthesizedSkill);
      final loaded = await store.getSkill(synthesizedSkill.id);
      expect(loaded, isNotNull);
      expect(loaded!.name, equals('battery-vibration-triage'));
    });
  });
}
