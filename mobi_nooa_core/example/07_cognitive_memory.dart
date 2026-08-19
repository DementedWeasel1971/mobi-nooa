import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 07: Cognitive Long-Term Memory (nooa-memory)
///
/// Demonstrates ACT-R activation and Ebbinghaus forgetting curve decay
/// alongside Owner-Gated memory isolation.
Future<void> main() async {
  print('=== mobi-nooa Tutorial 07: Cognitive ACT-R Memory ===\n');

  final memoryStore = CognitiveMemoryStore();
  final agentScope = OwnerGatedMemoryScope(ownerId: 'mobile_user_01', store: memoryStore);

  // 1. Remember user preferences
  agentScope.remember(
    id: 'pref_battery',
    content: 'User prefers Eco Power Mode when battery is below 25%',
    tags: ['power', 'preferences'],
    importance: 0.9,
  );

  agentScope.remember(
    id: 'pref_theme',
    content: 'User prefers Dark Mode at night',
    tags: ['ui', 'preferences'],
    importance: 0.4,
  );

  print('Total Memories Stored: ${memoryStore.size}');

  // 2. Recall memory using ACT-R cognitive ranking
  final recalls = agentScope.recall(tag: 'power');
  print('\nRecalled Power Memories for mobile_user_01:');
  for (final mem in recalls) {
    print('- [ID: ${mem.id}] Importance: ${mem.importance} | Content: "${mem.content}"');
    print('  Access History Count: ${mem.accessHistory.length}');
  }

  // 3. Test Owner-Gating Isolation
  final otherScope = OwnerGatedMemoryScope(ownerId: 'mobile_user_99', store: memoryStore);
  final unauthorizedRecalls = otherScope.recall();
  print('\nRecalls for mobile_user_99 (Isolated Boundary):');
  print('Count: ${unauthorizedRecalls.length} (Expected 0 - Cross-tenant leakage prevented)');
}
