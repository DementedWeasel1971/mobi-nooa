import 'package:test/test.dart';
import 'package:mobi_nooa_core/src/session/session_event.dart';
import 'package:mobi_nooa_core/src/session/session_event_log.dart';

void main() {
  group('SessionEventLog & Time-Travel / Forking (TDD)', () {
    test('appends events in chronological order and preserves immutability', () {
      final log = SessionEventLog(sessionId: 'session_001');

      log.append(SessionEvent(
        sessionId: 'session_001',
        stepIndex: 0,
        type: SessionEventType.userMessage,
        data: {'content': 'Analyze network connectivity'},
      ));

      log.append(SessionEvent(
        sessionId: 'session_001',
        stepIndex: 1,
        type: SessionEventType.assistantThought,
        data: {'thought': 'I need to check wifi and cellular status.'},
      ));

      log.append(SessionEvent(
        sessionId: 'session_001',
        stepIndex: 1,
        type: SessionEventType.toolCall,
        data: {'tool': 'getNetworkStatus', 'args': {}},
      ));

      log.append(SessionEvent(
        sessionId: 'session_001',
        stepIndex: 1,
        type: SessionEventType.toolResult,
        data: {'tool': 'getNetworkStatus', 'result': '{"connected": true, "type": "wifi"}'},
      ));

      log.append(SessionEvent(
        sessionId: 'session_001',
        stepIndex: 1,
        type: SessionEventType.stateChange,
        data: {'key': 'networkType', 'value': 'wifi'},
      ));

      expect(log.events.length, equals(5));
      expect(log.sessionId, equals('session_001'));
      expect(log.filterByType(SessionEventType.toolCall).length, equals(1));
    });

    test('replays state up to a specified step index (Time-Travel)', () {
      final log = SessionEventLog(sessionId: 'session_002');

      // Step 1: Set state var 'counter' = 10
      log.append(SessionEvent(
        sessionId: 'session_002',
        stepIndex: 1,
        type: SessionEventType.stateChange,
        data: {'key': 'counter', 'value': 10},
      ));

      // Step 2: Set state var 'counter' = 20, 'status' = 'in_progress'
      log.append(SessionEvent(
        sessionId: 'session_002',
        stepIndex: 2,
        type: SessionEventType.stateChange,
        data: {'key': 'counter', 'value': 20},
      ));
      log.append(SessionEvent(
        sessionId: 'session_002',
        stepIndex: 2,
        type: SessionEventType.stateChange,
        data: {'key': 'status', 'value': 'in_progress'},
      ));

      // Step 3: Set state var 'counter' = 30, 'status' = 'completed'
      log.append(SessionEvent(
        sessionId: 'session_002',
        stepIndex: 3,
        type: SessionEventType.stateChange,
        data: {'key': 'counter', 'value': 30},
      ));
      log.append(SessionEvent(
        sessionId: 'session_002',
        stepIndex: 3,
        type: SessionEventType.stateChange,
        data: {'key': 'status', 'value': 'completed'},
      ));

      // Replay at Step 1
      final replayStep1 = log.replay(1);
      expect(replayStep1.state['counter'], equals(10));
      expect(replayStep1.state.containsKey('status'), isFalse);

      // Replay at Step 2
      final replayStep2 = log.replay(2);
      expect(replayStep2.state['counter'], equals(20));
      expect(replayStep2.state['status'], equals('in_progress'));

      // Replay at Step 3
      final replayStep3 = log.replay(3);
      expect(replayStep3.state['counter'], equals(30));
      expect(replayStep3.state['status'], equals('completed'));
    });

    test('forks session from a historical step into an independent branch', () {
      final original = SessionEventLog(sessionId: 'main_session');

      original.append(SessionEvent(
        sessionId: 'main_session',
        stepIndex: 1,
        type: SessionEventType.stateChange,
        data: {'key': 'branch_point', 'value': 'v1'},
      ));

      original.append(SessionEvent(
        sessionId: 'main_session',
        stepIndex: 2,
        type: SessionEventType.stateChange,
        data: {'key': 'main_only', 'value': 'alpha'},
      ));

      // Fork from Step 1 into 'experiment_session'
      final forked = original.fork(newSessionId: 'experiment_session', fromStepIndex: 1);
      expect(forked.sessionId, equals('experiment_session'));
      expect(forked.events.length, equals(1));
      expect(forked.replay(1).state['branch_point'], equals('v1'));
      expect(forked.replay(1).state.containsKey('main_only'), isFalse);

      // Mutate forked branch
      forked.append(SessionEvent(
        sessionId: 'experiment_session',
        stepIndex: 2,
        type: SessionEventType.stateChange,
        data: {'key': 'fork_only', 'value': 'beta'},
      ));

      expect(forked.events.length, equals(2));
      expect(original.events.length, equals(2));
    });

    test('serializes and deserializes session log to JSON and JSONL', () {
      final log = SessionEventLog(sessionId: 'json_session');
      log.append(SessionEvent(
        sessionId: 'json_session',
        stepIndex: 1,
        type: SessionEventType.userMessage,
        data: {'text': 'Hello agent'},
      ));

      final jsonMap = log.toJson();
      final restored = SessionEventLog.fromJson(jsonMap);

      expect(restored.sessionId, equals('json_session'));
      expect(restored.events.length, equals(1));
      expect(restored.events.first.type, equals(SessionEventType.userMessage));

      final jsonl = log.toJsonLines();
      expect(jsonl, contains('json_session'));

      final fromJsonl = SessionEventLog.fromJsonLines('json_session', jsonl);
      expect(fromJsonl.events.length, equals(1));
    });
  });
}
