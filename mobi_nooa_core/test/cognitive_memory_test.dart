import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('nooa-memory Cognitive ACT-R & Owner-Gating Tests', () {
    late CognitiveMemoryStore memoryStore;

    setUp(() {
      memoryStore = CognitiveMemoryStore();
    });

    test('Owner-gated memory isolation prevents cross-agent leakage', () {
      final agentAScope = OwnerGatedMemoryScope(ownerId: 'agent_A', store: memoryStore);
      final agentBScope = OwnerGatedMemoryScope(ownerId: 'agent_B', store: memoryStore);

      agentAScope.remember(
        id: 'mem_1',
        content: 'Agent A private API token: secret_123',
        tags: ['auth', 'credentials'],
      );

      agentBScope.remember(
        id: 'mem_2',
        content: 'Agent B internal device configuration',
        tags: ['config'],
      );

      // Agent A recalls only their own memories
      final aRecalls = agentAScope.recall();
      expect(aRecalls.length, equals(1));
      expect(aRecalls.first.content, contains('secret_123'));

      // Agent B cannot see Agent A's memory
      final bRecalls = agentBScope.recall();
      expect(bRecalls.length, equals(1));
      expect(bRecalls.first.content, contains('Agent B'));
      expect(bRecalls.any((m) => m.content.contains('secret_123')), isFalse);
    });

    test('ACT-R activation increases with practice/recall (reinforcement)', () {
      final now = DateTime.now();
      final record = CognitiveMemoryRecord(
        id: 'item_1',
        ownerId: 'user_1',
        content: 'Frequently accessed contact',
        createdAt: now.subtract(const Duration(hours: 10)),
        accessHistory: [
          now.subtract(const Duration(hours: 10)),
        ],
      );

      const calc = ActRActivationCalculator();
      final initialActivation = calc.calculateActivation(record, referenceTime: now);

      // Add multiple access events (practice / reinforcement)
      record.recordAccess(now.subtract(const Duration(hours: 2)));
      record.recordAccess(now.subtract(const Duration(minutes: 5)));

      final reinforcedActivation = calc.calculateActivation(record, referenceTime: now);
      expect(reinforcedActivation, greaterThan(initialActivation));
    });

    test('Ebbinghaus decay weakens retrieval rank over time without reinforcement', () {
      final now = DateTime.now();
      final oldRecord = CognitiveMemoryRecord(
        id: 'old_item',
        ownerId: 'user_1',
        content: 'Old unreferenced fact',
        createdAt: now.subtract(const Duration(days: 30)),
        accessHistory: [now.subtract(const Duration(days: 30))],
      );

      final freshRecord = CognitiveMemoryRecord(
        id: 'fresh_item',
        ownerId: 'user_1',
        content: 'Recent observation',
        createdAt: now.subtract(const Duration(minutes: 10)),
        accessHistory: [now.subtract(const Duration(minutes: 10))],
      );

      const calc = ActRActivationCalculator();
      final oldAct = calc.calculateActivation(oldRecord, referenceTime: now);
      final freshAct = calc.calculateActivation(freshRecord, referenceTime: now);

      expect(freshAct, greaterThan(oldAct));
    });
  });
}
