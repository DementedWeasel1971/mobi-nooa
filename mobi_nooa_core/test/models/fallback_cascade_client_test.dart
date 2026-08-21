import 'dart:async';
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class FailingModelClient implements ModelClient {
  @override
  final String modelName;
  final Exception errorToThrow;
  int callCount = 0;

  FailingModelClient({
    required this.modelName,
    required this.errorToThrow,
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
    throw errorToThrow;
  }
}

class SuccessfulModelClient implements ModelClient {
  @override
  final String modelName;
  final String responseText;
  int callCount = 0;

  SuccessfulModelClient({
    required this.modelName,
    this.responseText = 'Success from fallback provider',
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
    return ModelResponse(text: responseText);
  }
}

void main() {
  group('FallbackCascadeClient Unit & Traceability Tests', () {
    test('succeeds on primary provider without cascade', () async {
      final primary = SuccessfulModelClient(modelName: 'primary-fast');
      final secondary = SuccessfulModelClient(modelName: 'secondary-backup');

      final cascadeClient = FallbackCascadeClient(
        cascade: [primary, secondary],
      );

      final response = await cascadeClient.generate(
        messages: [ModelMessage.user('Hello')],
      );

      expect(response.text, equals('Success from fallback provider'));
      expect(primary.callCount, equals(1));
      expect(secondary.callCount, equals(0));
      expect(cascadeClient.failureRecords, isEmpty);
      expect(cascadeClient.activeClientIndex, equals(0));
    });

    test('cascades to secondary provider when primary throws 503 and records trace and session events', () async {
      final tracer = Tracer('TestAgent');
      final sessionLog = SessionEventLog(sessionId: 'test_session_01');
      final cascadeEvents = <FallbackCascadeEvent>[];

      final primary = FailingModelClient(
        modelName: 'deepseek-reasoner',
        errorToThrow: Exception('HTTP 503 Service Unavailable: High cluster load'),
      );
      final secondary = SuccessfulModelClient(
        modelName: 'meta/llama-3.3-70b-instruct',
        responseText: 'Triage complete via NVIDIA fallback',
      );

      final cascadeClient = FallbackCascadeClient(
        cascade: [primary, secondary],
        maxRetriesPerProvider: 0,
        tracer: tracer,
        sessionLog: sessionLog,
        onCascadeEvent: (event) => cascadeEvents.add(event),
      );

      final response = await cascadeClient.generate(
        messages: [ModelMessage.user('Triage device')],
      );

      expect(response.text, equals('Triage complete via NVIDIA fallback'));
      expect(primary.callCount, equals(1));
      expect(secondary.callCount, equals(1));
      expect(cascadeClient.activeClientIndex, equals(1));
      expect(cascadeClient.modelName, equals('meta/llama-3.3-70b-instruct'));
      expect(cascadeClient.failureRecords.length, equals(1));
      expect(cascadeClient.failureRecords.first.providerName, equals('deepseek-reasoner'));
      expect(cascadeClient.failureRecords.first.statusCode, equals(503));

      // Verify Dispatch Events
      expect(cascadeEvents.length, equals(3));
      expect(cascadeEvents[0].type, equals(CascadeEventType.failure));
      expect(cascadeEvents[1].type, equals(CascadeEventType.cascade));
      expect(cascadeEvents[1].failedProvider, equals('deepseek-reasoner'));
      expect(cascadeEvents[1].fallbackProvider, equals('meta/llama-3.3-70b-instruct'));
      expect(cascadeEvents[2].type, equals(CascadeEventType.recovery));

      // Verify Tracer Events
      final traceTypes = tracer.events.map((e) => e.type).toList();
      expect(traceTypes, contains(TraceEventType.providerError));
      expect(traceTypes, contains(TraceEventType.providerFallback));
      expect(traceTypes, contains(TraceEventType.providerRecovered));

      // Verify Session Log Events
      final sessionTypes = sessionLog.events.map((e) => e.type).toList();
      expect(sessionTypes, contains(SessionEventType.providerError));
      expect(sessionTypes, contains(SessionEventType.providerCascade));
      expect(sessionTypes, contains(SessionEventType.providerRecovered));
    });

    test('cascades across 3 tiers (Primary -> Secondary -> Tertiary)', () async {
      final tier1 = FailingModelClient(
        modelName: 'tier1-cloud',
        errorToThrow: Exception('HTTP 429 Rate Limit Exceeded'),
      );
      final tier2 = FailingModelClient(
        modelName: 'tier2-cloud',
        errorToThrow: Exception('SocketException: Connection timed out'),
      );
      final tier3 = SuccessfulModelClient(
        modelName: 'tier3-on-device',
        responseText: 'Recovered on local quantized 3B model',
      );

      final cascadeClient = FallbackCascadeClient(
        cascade: [tier1, tier2, tier3],
        maxRetriesPerProvider: 0,
      );

      final response = await cascadeClient.generate(
        messages: [ModelMessage.user('Run task')],
      );

      expect(response.text, equals('Recovered on local quantized 3B model'));
      expect(tier1.callCount, equals(1));
      expect(tier2.callCount, equals(1));
      expect(tier3.callCount, equals(1));
      expect(cascadeClient.activeClientIndex, equals(2));
      expect(cascadeClient.failureRecords.length, equals(2));
      expect(cascadeClient.failureRecords[0].statusCode, equals(429));
    });

    test('throws AllProvidersExhaustedException when all providers fail', () async {
      final tier1 = FailingModelClient(
        modelName: 'tier1',
        errorToThrow: Exception('HTTP 500 Internal Error'),
      );
      final tier2 = FailingModelClient(
        modelName: 'tier2',
        errorToThrow: Exception('HTTP 502 Bad Gateway'),
      );

      final cascadeClient = FallbackCascadeClient(
        cascade: [tier1, tier2],
        maxRetriesPerProvider: 0,
      );

      expect(
        () => cascadeClient.generate(messages: [ModelMessage.user('Test')]),
        throwsA(isA<AllProvidersExhaustedException>()),
      );
    });

    test('integrates seamlessly into AgentLoop via LoopConfig.fallbackClients', () async {
      final sessionLog = SessionEventLog(sessionId: 'loop_session_01');
      final primary = FailingModelClient(
        modelName: 'failing-primary',
        errorToThrow: Exception('HTTP 503 Server Busy'),
      );
      final secondary = MockModelClient()
        ..queueText('{"thought": "Resolved via fallback", "answer": "Task successfully triaged via secondary fallback provider"}');

      final agent = Quickstart.createAgent(
        () => GeneralMobileAgent(),
        model: primary,
        sessionLog: sessionLog,
      );

      final loop = AgentLoop(
        agent: agent,
        context: agent.context,
        config: LoopConfig(
          fallbackClients: [secondary],
          sessionLog: sessionLog,
        ),
      );

      final result = await loop.run('Triage mobile system');
      expect(result, isNotNull);
      expect(primary.callCount, greaterThanOrEqualTo(1));
      
      // Verify session logged the fallback transition
      final eventTypes = sessionLog.events.map((e) => e.type).toList();
      expect(eventTypes, contains(SessionEventType.providerError));
      expect(eventTypes, contains(SessionEventType.providerCascade));
      expect(eventTypes, contains(SessionEventType.providerRecovered));
    });
  });
}
