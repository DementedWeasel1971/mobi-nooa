import 'dart:async';
import 'dart:math';

/// A document record with an embedding vector for semantic search.
class MemoryDocument {
  final String id;
  final String content;
  final List<double> embedding;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  MemoryDocument({
    required this.id,
    required this.content,
    this.embedding = const [],
    this.metadata = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Interface for persistent agent memory, key-value storage, and vector retrieval.
abstract class MemoryHarness {
  Future<void> set(String key, dynamic value);
  Future<dynamic> get(String key);
  Future<bool> has(String key);
  Future<void> delete(String key);
  Future<List<String>> keys();

  // Vector / Semantic Indexing
  Future<void> indexDocument(MemoryDocument doc);
  Future<List<MemoryDocument>> searchSimilar(
    List<double> queryVector, {
    int topK = 5,
    double minSimilarity = 0.0,
  });
}

/// In-memory implementation of Key-Value and Cosine Similarity Vector search.
class DefaultMemoryHarness implements MemoryHarness {
  final Map<String, dynamic> _store = {};
  final List<MemoryDocument> _vectorIndex = [];

  @override
  Future<void> set(String key, dynamic value) async => _store[key] = value;

  @override
  Future<dynamic> get(String key) async => _store[key];

  @override
  Future<bool> has(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<List<String>> keys() async => _store.keys.toList();

  @override
  Future<void> indexDocument(MemoryDocument doc) async {
    _vectorIndex.removeWhere((d) => d.id == doc.id);
    _vectorIndex.add(doc);
  }

  @override
  Future<List<MemoryDocument>> searchSimilar(
    List<double> queryVector, {
    int topK = 5,
    double minSimilarity = 0.0,
  }) async {
    if (queryVector.isEmpty || _vectorIndex.isEmpty) return [];

    final scored = <MapEntry<MemoryDocument, double>>[];
    for (final doc in _vectorIndex) {
      if (doc.embedding.isEmpty) continue;
      final score = _cosineSimilarity(queryVector, doc.embedding);
      if (score >= minSimilarity) {
        scored.add(MapEntry(doc, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topK).map((e) => e.key).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
