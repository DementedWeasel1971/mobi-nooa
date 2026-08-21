import 'dart:async';
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// Simulates a model client that fails a specified number of times before succeeding,
/// or fails indefinitely if failureCount is large.
class MockFailingModelClient implements ModelClient {
  @override
  final String modelName;
  final Exception errorToThrow;
  final int maxFailures;
  final String successText;
  final Duration delay;
  int callCount = 0;

  MockFailingModelClient({
    required this.modelName,
    required this.errorToThrow,
    this.maxFailures = 999,
    this.successText = 'Success after recovery',
    this.delay = Duration.zero,
  });

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    callCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (callCount <= maxFailures) {
      throw errorToThrow;
    }
    return ModelResponse(text: successText);
  }
}

/// Simulates a successful model client that can optionally return tool calls,
/// reasoning tokens, or custom text.
class MockConfigurableModelClient implements ModelClient {
  @override
  final String modelName;
  final List<ModelResponse> responses;
  int callCount = 0;
  List<ToolDefinition>? receivedTools;
  List<ModelMessage>? lastMessages;

  MockConfigurableModelClient({
    required this.modelName,
    required this.responses,
  });

  factory MockConfigurableModelClient.single({
    required String modelName,
    String text = 'Default response',
    String? reasoningContent,
    List<ToolCall>? toolCalls,
  }) {
    return MockConfigurableModelClient(
      modelName: modelName,
      responses: [
        ModelResponse(
          text: text,
          reasoningContent: reasoningContent,
          toolCalls: toolCalls ?? const [],
        ),
      ],
    );
  }

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    lastMessages = messages;
    receivedTools = tools;
    if (callCount < responses.length) {
      return responses[callCount++];
    }
    return ModelResponse(text: 'Exhausted responses (call ${++callCount})');
  }
}

class _TwoStepCrashingClient implements ModelClient {
  @override
  final String modelName = 'primary-step-crashing';
  int callCount = 0;

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    callCount++;
    if (callCount == 1) {
      return ModelResponse(
        text: 'I will inspect device battery.',
        toolCalls: [
          ToolCall(id: 'call_01', name: 'getBatteryStatus', arguments: {}),
        ],
      );
    }
    throw Exception('HTTP 500 Internal Error on Step 2 synthesis');
  }
}

void main() {
  group('Fallback Cascade Scenario Permutations Suite', () {
    // ------------------------------------------------------------------------
    // Permutation 1: Nominal Case (Primary Provider Succeeds)
    // ------------------------------------------------------------------------
    test('Permutation 1: Primary provider succeeds immediately on step 1 (0 failures, 0 cascade)', () async {
      final primary = MockConfigurableModelClient.single(
        modelName: 'primary-cloud',
        text: 'Immediate primary success',
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'secondary-cloud',
        text: 'Secondary fallback',
      );

      final cascade = FallbackCascadeClient(cascade: [primary, secondary]);
      final response = await cascade.generate(messages: [ModelMessage.user('Task')]);

      expect(response.text, equals('Immediate primary success'));
      expect(primary.callCount, equals(1));
      expect(secondary.callCount, equals(0));
      expect(cascade.failureRecords, isEmpty);
      expect(cascade.activeClientIndex, equals(0));
    });

    // ------------------------------------------------------------------------
    // Permutation 2: In-Tier Transient Retry (Primary Provider Recovers)
    // ------------------------------------------------------------------------
    test('Permutation 2: Transient error on Primary provider with in-tier retry success (no cascade)', () async {
      final tracer = Tracer('TestAgent');
      final primary = MockFailingModelClient(
        modelName: 'primary-flaky',
        errorToThrow: Exception('SocketException: Connection reset by peer'),
        maxFailures: 1, // Fails call 1, succeeds on retry 2
        successText: 'Recovered on primary retry',
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'secondary-cloud',
        text: 'Secondary fallback',
      );

      final cascade = FallbackCascadeClient(
        cascade: [primary, secondary],
        maxRetriesPerProvider: 2,
        tracer: tracer,
      );

      final response = await cascade.generate(messages: [ModelMessage.user('Task')]);

      expect(response.text, equals('Recovered on primary retry'));
      expect(primary.callCount, equals(2));
      expect(secondary.callCount, equals(0)); // Never cascaded to secondary
      expect(cascade.activeClientIndex, equals(0));
      expect(cascade.failureRecords.length, equals(1)); // First attempt recorded in diagnostic history
    });

    // ------------------------------------------------------------------------
    // Permutation 3: 503 / 500 HTTP Server Error Cascades to Tier 2
    // ------------------------------------------------------------------------
    test('Permutation 3: Primary exhausts retries on HTTP 503 -> Cascades to Secondary and emits full telemetry', () async {
      final tracer = Tracer('TestAgent');
      final sessionLog = SessionEventLog(sessionId: 'session_p3');
      final events = <FallbackCascadeEvent>[];

      final primary = MockFailingModelClient(
        modelName: 'deepseek-chat',
        errorToThrow: Exception('HTTP 503 Service Unavailable: High load'),
        maxFailures: 99,
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'meta/llama-3.3-70b-instruct',
        text: 'Recovered via NVIDIA Tier 2',
      );

      final cascade = FallbackCascadeClient(
        cascade: [primary, secondary],
        maxRetriesPerProvider: 1,
        tracer: tracer,
        sessionLog: sessionLog,
        onCascadeEvent: (e) => events.add(e),
      );

      final response = await cascade.generate(messages: [ModelMessage.user('Run inference')]);

      expect(response.text, equals('Recovered via NVIDIA Tier 2'));
      expect(primary.callCount, equals(2)); // Initial try + 1 retry
      expect(secondary.callCount, equals(1));
      expect(cascade.activeClientIndex, equals(1));
      expect(cascade.failureRecords.length, equals(2)); // 2 failed attempts on primary
      expect(cascade.failureRecords.first.providerName, equals('deepseek-chat'));
      expect(cascade.failureRecords.first.statusCode, equals(503));

      // Assert Event Sequence
      expect(events.map((e) => e.type), equals([
        CascadeEventType.failure,
        CascadeEventType.failure,
        CascadeEventType.cascade,
        CascadeEventType.recovery,
      ]));

      // Assert Tracer Records
      final traceTypes = tracer.events.map((e) => e.type).toList();
      expect(traceTypes, contains(TraceEventType.providerError));
      expect(traceTypes, contains(TraceEventType.providerFallback));
      expect(traceTypes, contains(TraceEventType.providerRecovered));

      // Assert Session Log Records
      final sessionTypes = sessionLog.events.map((e) => e.type).toList();
      expect(sessionTypes, contains(SessionEventType.providerError));
      expect(sessionTypes, contains(SessionEventType.providerCascade));
      expect(sessionTypes, contains(SessionEventType.providerRecovered));
    });

    // ------------------------------------------------------------------------
    // Permutation 4: TimeoutException Cascades to Tier 2
    // ------------------------------------------------------------------------
    test('Permutation 4: Primary provider times out (TimeoutException) -> Cascades to Secondary', () async {
      final primary = MockFailingModelClient(
        modelName: 'slow-primary',
        errorToThrow: TimeoutException('Model generation timed out after 50ms'),
        delay: Duration(milliseconds: 60),
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'fast-on-device',
        text: 'Synthesized quickly on device',
      );

      final cascade = FallbackCascadeClient(
        cascade: [primary, secondary],
        providerTimeout: Duration(milliseconds: 30),
        maxRetriesPerProvider: 0,
      );

      final response = await cascade.generate(messages: [ModelMessage.user('Quick query')]);

      expect(response.text, equals('Synthesized quickly on device'));
      expect(cascade.activeClientIndex, equals(1));
      expect(cascade.failureRecords.length, equals(1));
      expect(cascade.failureRecords.first.errorMessage, contains('TimeoutException'));
    });

    // ------------------------------------------------------------------------
    // Permutation 5: Multi-Tier N-Way Cascade (4 Tiers)
    // ------------------------------------------------------------------------
    test('Permutation 5: 4-Tier cascade (Tier 1 RateLimit -> Tier 2 Timeout -> Tier 3 ServerError -> Tier 4 Quantized Model)', () async {
      final tier1 = MockFailingModelClient(
        modelName: 'tier1-cloud',
        errorToThrow: Exception('HTTP 429 Rate Limit Exceeded'),
        maxFailures: 99,
      );
      final tier2 = MockFailingModelClient(
        modelName: 'tier2-cloud',
        errorToThrow: TimeoutException('Connection timed out'),
        delay: Duration(milliseconds: 50),
      );
      final tier3 = MockFailingModelClient(
        modelName: 'tier3-cloud',
        errorToThrow: Exception('HTTP 502 Bad Gateway'),
        maxFailures: 99,
      );
      final tier4 = MockConfigurableModelClient.single(
        modelName: 'tier4-quantized-on-device',
        text: 'Local quantized 3B execution complete',
      );

      final cascade = FallbackCascadeClient(
        cascade: [tier1, tier2, tier3, tier4],
        providerTimeout: Duration(milliseconds: 20),
        maxRetriesPerProvider: 0,
      );

      final response = await cascade.generate(messages: [ModelMessage.user('Run multi-tier test')]);

      expect(response.text, equals('Local quantized 3B execution complete'));
      expect(tier1.callCount, equals(1));
      expect(tier2.callCount, equals(1));
      expect(tier3.callCount, equals(1));
      expect(tier4.callCount, equals(1));
      expect(cascade.activeClientIndex, equals(3));
      expect(cascade.failureRecords.length, equals(3));
      expect(cascade.failureRecords[0].statusCode, equals(429));
      expect(cascade.failureRecords[1].errorMessage, contains('TimeoutException'));
      expect(cascade.failureRecords[2].statusCode, equals(502));
    });

    // ------------------------------------------------------------------------
    // Permutation 6: All Providers Exhausted Exception
    // ------------------------------------------------------------------------
    test('Permutation 6: All providers in cascade fail -> Emits allExhausted and throws AllProvidersExhaustedException', () async {
      final events = <FallbackCascadeEvent>[];
      final tier1 = MockFailingModelClient(
        modelName: 'tier1',
        errorToThrow: Exception('HTTP 500 Internal Error'),
        maxFailures: 99,
      );
      final tier2 = MockFailingModelClient(
        modelName: 'tier2',
        errorToThrow: Exception('HTTP 503 Unavailable'),
        maxFailures: 99,
      );

      final cascade = FallbackCascadeClient(
        cascade: [tier1, tier2],
        maxRetriesPerProvider: 0,
        onCascadeEvent: (e) => events.add(e),
      );

      expect(
        () => cascade.generate(messages: [ModelMessage.user('Test failure')]),
        throwsA(isA<AllProvidersExhaustedException>()),
      );

      try {
        await cascade.generate(messages: [ModelMessage.user('Test failure')]);
      } catch (e) {
        expect(e, isA<AllProvidersExhaustedException>());
        final ex = e as AllProvidersExhaustedException;
        expect(ex.failureRecords.length, equals(2));
        expect(ex.message, contains('All 2 LLM provider(s) in the cascade failed'));
      }

      expect(events.any((e) => e.type == CascadeEventType.allExhausted), isTrue);
    });

    // ------------------------------------------------------------------------
    // Permutation 7: Multi-Step Agent Tool-Calling with Mid-Trajectory Fallback
    // ------------------------------------------------------------------------
    test('Permutation 7: Mid-trajectory fallback: Step 1 tool call succeeds on Primary -> Step 2 Primary crashes -> Secondary synthesizes answer with full conversation context', () async {
      final sessionLog = SessionEventLog(sessionId: 'mid_trajectory_session');

      // Primary succeeds on step 1 (issues tool call), but crashes on step 2 (final answer synthesis)
      final primary = MockFailingModelClient(
        modelName: 'primary-cloud',
        errorToThrow: Exception('HTTP 500 Internal Error on Step 2 synthesis'),
      );
      // We configure a two-step client
      int primaryCalls = 0;
      final dynamicPrimary = MockConfigurableModelClient(
        modelName: 'primary-cloud',
        responses: [],
      );

      final cascadePrimary = MockConfigurableModelClient(
        modelName: 'primary-cloud',
        responses: [
          ModelResponse(
            text: 'I will inspect device battery.',
            toolCalls: [
              ToolCall(id: 'call_01', name: 'getBatteryStatus', arguments: {}),
            ],
          ),
        ],
      );

      // Primary client that throws on call 2
      final stepTwoCrashingPrimary = _TwoStepCrashingClient();

      // Secondary picks up on Step 2 with full conversation history and produces final answer
      final secondary = MockModelClient()
        ..queueText('{"thought": "Analyzed tool output", "answer": "Battery is at 85% charging nominal"}');

      final agent = Quickstart.createAgent(
        () => AutonomousDeviceAgent(),
        model: stepTwoCrashingPrimary,
        sessionLog: sessionLog,
      );

      final loop = AgentLoop(
        agent: agent,
        context: agent.context,
        config: LoopConfig(
          fallbackClients: [secondary],
          sessionLog: sessionLog,
          maxSteps: 3,
        ),
      );

      final result = await loop.run('Check battery status');
      expect(result, isNotNull);
      expect(result.toString(), contains('nominal'));
    });

    // ------------------------------------------------------------------------
    // Permutation 8: Tool Definition & Parameter Forwarding Compatibility
    // ------------------------------------------------------------------------
    test('Permutation 8: Tool definitions and schema are preserved identically during cascade to fallback provider', () async {
      final primary = MockFailingModelClient(
        modelName: 'primary-failing',
        errorToThrow: Exception('HTTP 503 Service Unavailable'),
        maxFailures: 99,
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'secondary-model',
        text: 'Received tools successfully',
      );

      final cascade = FallbackCascadeClient(
        cascade: [primary, secondary],
        maxRetriesPerProvider: 0,
      );

      final tools = [
        ToolDefinition(
          name: 'queryDatabase',
          description: 'Runs SQL query',
          parameters: [
            ToolParameter(
              name: 'sql',
              type: 'string',
              description: 'SQL query to execute',
            ),
          ],
        ),
      ];

      await cascade.generate(
        messages: [ModelMessage.user('Query stats')],
        tools: tools,
      );

      expect(secondary.receivedTools, isNotNull);
      expect(secondary.receivedTools!.length, equals(1));
      expect(secondary.receivedTools!.first.name, equals('queryDatabase'));
    });

    // ------------------------------------------------------------------------
    // Permutation 9: DeepSeek-R1 <think> Reasoning Content Preservation
    // ------------------------------------------------------------------------
    test('Permutation 9: Fallback provider DeepSeek-R1 reasoning content extraction is preserved', () async {
      final primary = MockFailingModelClient(
        modelName: 'primary-cloud',
        errorToThrow: Exception('HTTP 500 Internal Error'),
        maxFailures: 99,
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'deepseek-reasoner',
        text: '<think>\nEvaluating device triage priority\n</think>\nTriage complete.',
        reasoningContent: 'Evaluating device triage priority',
      );

      final cascade = FallbackCascadeClient(
        cascade: [primary, secondary],
        maxRetriesPerProvider: 0,
      );

      final response = await cascade.generate(messages: [ModelMessage.user('Triage device')]);

      expect(response.reasoningContent, equals('Evaluating device triage priority'));
      expect(response.text, contains('Triage complete'));
    });

    // ------------------------------------------------------------------------
    // Permutation 10: AgentBridgeDispatcher JSON Dispatch with Fallback Cascade
    // ------------------------------------------------------------------------
    test('Permutation 10: AgentBridgeDispatcher executes agent loop with cascade model configuration from JSON', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();

      final request = {
        'action': 'runAgentLoop',
        'agentName': 'GeneralMobileAgent',
        'goal': 'Test dispatcher fallback cascade',
        'model': {
          'provider': 'cascade',
          'cascade': [
            {'provider': 'mock'},
            {'provider': 'on_device'},
          ],
          'providerTimeoutSeconds': 10,
          'maxRetriesPerProvider': 1,
        },
      };

      final response = await dispatcher.handle(request);
      expect(response['error'], isNull);
      expect(response['result'], isNotNull);
      expect(response['trace'], isA<List>());
    });

    // ------------------------------------------------------------------------
    // Permutation 11: Single-Element & Empty Cascade List Handling
    // ------------------------------------------------------------------------
    test('Permutation 11: Single-element cascade acts as standard pass-through', () async {
      final singleClient = MockConfigurableModelClient.single(
        modelName: 'sole-provider',
        text: 'Sole provider output',
      );

      final cascade = FallbackCascadeClient(cascade: [singleClient]);
      final response = await cascade.generate(messages: [ModelMessage.user('Hello')]);

      expect(response.text, equals('Sole provider output'));
      expect(singleClient.callCount, equals(1));
      expect(cascade.activeClientIndex, equals(0));
    });

    // ------------------------------------------------------------------------
    // Permutation 12: Manual Reset of Fallback Client
    // ------------------------------------------------------------------------
    test('Permutation 12: reset() restores active client index to 0 and clears failure records', () async {
      final primary = MockFailingModelClient(
        modelName: 'primary-cloud',
        errorToThrow: Exception('HTTP 503'),
        maxFailures: 99,
      );
      final secondary = MockConfigurableModelClient.single(
        modelName: 'secondary-cloud',
        text: 'Secondary',
      );

      final cascade = FallbackCascadeClient(cascade: [primary, secondary], maxRetriesPerProvider: 0);
      await cascade.generate(messages: [ModelMessage.user('Run 1')]);

      expect(cascade.activeClientIndex, equals(1));
      expect(cascade.failureRecords.length, equals(1));

      // Reset
      cascade.reset();
      expect(cascade.activeClientIndex, equals(0));
      expect(cascade.failureRecords, isEmpty);
    });
  });
}
