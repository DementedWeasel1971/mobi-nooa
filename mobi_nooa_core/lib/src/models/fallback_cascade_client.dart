import 'dart:async';
import 'model_client.dart';
import '../tracing/tracer.dart';
import '../tracing/trace_event.dart';
import '../session/session_event.dart';
import '../session/session_event_log.dart';

/// Event type for provider cascade transitions.
enum CascadeEventType {
  failure,
  cascade,
  recovery,
  allExhausted,
}

/// Structured record of a single provider failure during a cascade.
class FallbackFailureRecord {
  final String providerName;
  final String errorMessage;
  final int? statusCode;
  final DateTime timestamp;
  final Duration duration;
  final int attempt;

  FallbackFailureRecord({
    required this.providerName,
    required this.errorMessage,
    this.statusCode,
    required this.timestamp,
    required this.duration,
    this.attempt = 1,
  });

  Map<String, dynamic> toJson() => {
        'providerName': providerName,
        'errorMessage': errorMessage,
        if (statusCode != null) 'statusCode': statusCode,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'attempt': attempt,
      };

  @override
  String toString() =>
      'FallbackFailureRecord(provider: $providerName, error: $errorMessage, duration: ${duration.inMilliseconds}ms)';
}

/// Observable notification event dispatched during provider fallback cascades.
class FallbackCascadeEvent {
  final CascadeEventType type;
  final String failedProvider;
  final String? fallbackProvider;
  final String errorMessage;
  final int attempt;
  final Duration latency;
  final DateTime timestamp;

  FallbackCascadeEvent({
    required this.type,
    required this.failedProvider,
    this.fallbackProvider,
    required this.errorMessage,
    this.attempt = 1,
    required this.latency,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'failedProvider': failedProvider,
        if (fallbackProvider != null) 'fallbackProvider': fallbackProvider,
        'errorMessage': errorMessage,
        'attempt': attempt,
        'latencyMs': latency.inMilliseconds,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Exception thrown when all model providers in the cascade are exhausted.
class AllProvidersExhaustedException implements Exception {
  final List<FallbackFailureRecord> failureRecords;
  final String message;

  AllProvidersExhaustedException(this.failureRecords)
      : message = 'All ${failureRecords.length} LLM provider(s) in the cascade failed: ' +
            failureRecords.map((r) => '[${r.providerName}: ${r.errorMessage}]').join(', ');

  @override
  String toString() => 'AllProvidersExhaustedException: $message';
}

/// A resilient, multi-tiered [ModelClient] wrapper that cascades through a list
/// of candidate LLM providers upon connectivity failure, rate limiting, or server error.
///
/// Ensures full end-to-end traceability into [Tracer] and [SessionEventLog]
/// from the exact point of provider failure to fallback recovery.
class FallbackCascadeClient implements ModelClient {
  final List<ModelClient> cascade;
  final Duration providerTimeout;
  final int maxRetriesPerProvider;
  final Tracer? tracer;
  final SessionEventLog? sessionLog;
  final void Function(FallbackCascadeEvent event)? onCascadeEvent;

  final List<FallbackFailureRecord> _failureRecords = [];
  int _activeClientIndex = 0;

  FallbackCascadeClient({
    required this.cascade,
    this.providerTimeout = const Duration(seconds: 25),
    this.maxRetriesPerProvider = 1,
    this.tracer,
    this.sessionLog,
    this.onCascadeEvent,
  }) {
    if (cascade.isEmpty) {
      throw ArgumentError('FallbackCascadeClient requires at least one candidate ModelClient.');
    }
  }

  /// The currently active [ModelClient] in the cascade.
  ModelClient get activeClient => cascade[_activeClientIndex];

  /// The 0-based index of the currently active candidate.
  int get activeClientIndex => _activeClientIndex;

  /// Full history of provider failure records encountered during session.
  List<FallbackFailureRecord> get failureRecords => List.unmodifiable(_failureRecords);

  @override
  String get modelName => activeClient.modelName;

  /// Resets the active client back to the primary candidate (index 0).
  void resetToPrimary() {
    _activeClientIndex = 0;
  }

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    final sessionFailures = <FallbackFailureRecord>[];
    int candidateIndex = _activeClientIndex;

    while (candidateIndex < cascade.length) {
      final candidate = cascade[candidateIndex];
      int attempt = 0;
      bool candidateSucceeded = false;
      ModelResponse? successfulResponse;

      while (attempt <= maxRetriesPerProvider && !candidateSucceeded) {
        attempt++;
        final stopwatch = Stopwatch()..start();

        try {
          final response = await candidate
              .generate(
                messages: messages,
                tools: tools,
                temperature: temperature,
                maxTokens: maxTokens,
                stopSequences: stopSequences,
              )
              .timeout(providerTimeout);

          stopwatch.stop();
          candidateSucceeded = true;
          successfulResponse = response;

          // If we recovered from earlier failures or escalated tiers, record recovery
          if (sessionFailures.isNotEmpty || candidateIndex > 0) {
            final recoveryEvent = FallbackCascadeEvent(
              type: CascadeEventType.recovery,
              failedProvider: sessionFailures.isNotEmpty ? sessionFailures.last.providerName : 'primary',
              fallbackProvider: candidate.modelName,
              errorMessage: 'Successfully resolved on fallback candidate',
              attempt: attempt,
              latency: stopwatch.elapsed,
            );

            onCascadeEvent?.call(recoveryEvent);

            tracer?.record(
              type: TraceEventType.providerRecovered,
              description: 'Recovered execution on fallback provider: ${candidate.modelName}',
              data: recoveryEvent.toJson(),
              duration: stopwatch.elapsed,
            );

            sessionLog?.append(
              SessionEvent(
                sessionId: sessionLog?.sessionId ?? 'session',
                stepIndex: 0,
                type: SessionEventType.providerRecovered,
                data: recoveryEvent.toJson(),
                summary: 'Recovered on fallback provider: ${candidate.modelName}',
              ),
            );
          }

          _activeClientIndex = candidateIndex;
          return successfulResponse;
        } catch (error) {
          stopwatch.stop();
          final errorMessage = error.toString();
          final statusCode = _extractStatusCode(error);

          final failureRecord = FallbackFailureRecord(
            providerName: candidate.modelName,
            errorMessage: errorMessage,
            statusCode: statusCode,
            timestamp: DateTime.now(),
            duration: stopwatch.elapsed,
            attempt: attempt,
          );

          _failureRecords.add(failureRecord);
          sessionFailures.add(failureRecord);

          // Dispatched single failure event
          final failEvent = FallbackCascadeEvent(
            type: CascadeEventType.failure,
            failedProvider: candidate.modelName,
            errorMessage: errorMessage,
            attempt: attempt,
            latency: stopwatch.elapsed,
          );
          onCascadeEvent?.call(failEvent);

          tracer?.record(
            type: TraceEventType.providerError,
            description: 'Provider "${candidate.modelName}" failed (Attempt $attempt): $errorMessage',
            data: failureRecord.toJson(),
            duration: stopwatch.elapsed,
          );

          sessionLog?.append(
            SessionEvent(
              sessionId: sessionLog?.sessionId ?? 'session',
              stepIndex: 0,
              type: SessionEventType.providerError,
              data: failureRecord.toJson(),
              summary: 'Provider "${candidate.modelName}" error: $errorMessage',
            ),
          );

          // If retry attempts remain on this candidate, apply brief exponential backoff
          if (attempt <= maxRetriesPerProvider) {
            await Future.delayed(Duration(milliseconds: 300 * attempt));
          }
        }
      }

      // Candidate exhausted all retries -> Cascade to next candidate
      candidateIndex++;
      if (candidateIndex < cascade.length) {
        final nextCandidate = cascade[candidateIndex];

        final cascadeEvent = FallbackCascadeEvent(
          type: CascadeEventType.cascade,
          failedProvider: candidate.modelName,
          fallbackProvider: nextCandidate.modelName,
          errorMessage: 'Exhausted retries on ${candidate.modelName}. Cascading to ${nextCandidate.modelName}',
          attempt: attempt,
          latency: Duration.zero,
        );

        onCascadeEvent?.call(cascadeEvent);

        tracer?.record(
          type: TraceEventType.providerFallback,
          description: 'Cascading from "${candidate.modelName}" to fallback "${nextCandidate.modelName}"',
          data: cascadeEvent.toJson(),
        );

        sessionLog?.append(
          SessionEvent(
            sessionId: sessionLog?.sessionId ?? 'session',
            stepIndex: 0,
            type: SessionEventType.providerCascade,
            data: cascadeEvent.toJson(),
            summary: 'Provider cascade: ${candidate.modelName} -> ${nextCandidate.modelName}',
          ),
        );
      }
    }

    // All cascade candidates exhausted
    final exhaustedEvent = FallbackCascadeEvent(
      type: CascadeEventType.allExhausted,
      failedProvider: cascade.last.modelName,
      errorMessage: 'All ${cascade.length} providers in cascade failed.',
      latency: Duration.zero,
    );
    onCascadeEvent?.call(exhaustedEvent);

    throw AllProvidersExhaustedException(sessionFailures);
  }

  int? _extractStatusCode(dynamic error) {
    if (error == null) return null;
    final str = error.toString();
    final match = RegExp(r'\b(400|401|403|404|429|500|502|503|504)\b').firstMatch(str);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Resets active candidate index back to 0 and clears failure records.
  void reset() {
    _activeClientIndex = 0;
    _failureRecords.clear();
  }
}
