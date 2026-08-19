import 'act_r_memory.dart';

/// Scope guard enforcing owner-gated memory access control (NOOA Security & Multi-Agent isolation).
class OwnerGatedMemoryScope {
  final String ownerId;
  final CognitiveMemoryStore _store;

  OwnerGatedMemoryScope({
    required this.ownerId,
    required CognitiveMemoryStore store,
  }) : _store = store;

  /// Saves a memory strictly owned by this agent.
  void remember({
    required String id,
    required String content,
    List<String> tags = const [],
    double importance = 0.5,
    List<double> embedding = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    _store.remember(
      id: id,
      ownerId: ownerId,
      content: content,
      tags: tags,
      importance: importance,
      embedding: embedding,
      metadata: metadata,
    );
  }

  /// Recalls memories strictly belonging to this owner.
  List<CognitiveMemoryRecord> recall({
    String? tag,
    List<double>? queryEmbedding,
    int topK = 5,
    double minActivation = -10.0,
  }) {
    return _store.recall(
      ownerId: ownerId,
      tag: tag,
      queryEmbedding: queryEmbedding,
      topK: topK,
      minActivation: minActivation,
    );
  }
}
