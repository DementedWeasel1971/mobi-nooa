import 'dart:math';

/// A cognitively grounded memory record in mobi-nooa (inspired by nooa-memory & ACT-R).
///
/// Combines content, owner-gating, semantic embeddings, and access history
/// to compute dynamic retrieval strength based on human cognitive principles (Ebbinghaus decay).
class CognitiveMemoryRecord {
  final String id;
  final String ownerId; // Owner / Agent ID for owner-gated scoping
  final String content;
  final List<String> tags;
  final double importance; // 0.0 to 1.0 baseline importance weight
  final DateTime createdAt;
  final List<DateTime> accessHistory;
  final List<double> embedding;
  final Map<String, dynamic> metadata;

  CognitiveMemoryRecord({
    required this.id,
    required this.ownerId,
    required this.content,
    this.tags = const [],
    this.importance = 0.5,
    DateTime? createdAt,
    List<DateTime>? accessHistory,
    this.embedding = const [],
    this.metadata = const {},
  })  : createdAt = createdAt ?? DateTime.now(),
        accessHistory = accessHistory != null
            ? List.from(accessHistory)
            : [createdAt ?? DateTime.now()];

  /// Records an access event (reinforcement).
  void recordAccess([DateTime? time]) {
    accessHistory.add(time ?? DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'content': content,
        'tags': tags,
        'importance': importance,
        'createdAt': createdAt.toIso8601String(),
        'accessHistory': accessHistory.map((t) => t.toIso8601String()).toList(),
        'embedding': embedding,
        'metadata': metadata,
      };

  factory CognitiveMemoryRecord.fromJson(Map<String, dynamic> json) =>
      CognitiveMemoryRecord(
        id: json['id'] as String,
        ownerId: (json['ownerId'] as String?) ?? 'default_owner',
        content: json['content'] as String,
        tags: List<String>.from((json['tags'] as List?) ?? []),
        importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        accessHistory: ((json['accessHistory'] as List?) ?? [])
            .map((t) => DateTime.tryParse(t.toString()) ?? DateTime.now())
            .toList(),
        embedding: List<double>.from(
          ((json['embedding'] as List?) ?? []).map((e) => (e as num).toDouble()),
        ),
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      );
}

/// Computes ACT-R activation scores with Ebbinghaus power-law forgetting curve.
///
/// Mathematical Model:
/// Base-level activation: B_i = ln( sum_{k=1}^n (t - t_k)^{-d} )
/// Total Activation: A_i = B_i + W_importance * Importance + S_context + Noise
class ActRActivationCalculator {
  /// Decay parameter (typically d = 0.5 in ACT-R theory).
  final double decayRate;

  /// Weight given to importance score.
  final double importanceWeight;

  const ActRActivationCalculator({
    this.decayRate = 0.5,
    this.importanceWeight = 1.2,
  });

  /// Calculates activation score for a memory item at a given reference time.
  double calculateActivation(
    CognitiveMemoryRecord record, {
    DateTime? referenceTime,
    double contextSimilarity = 0.0,
  }) {
    final now = referenceTime ?? DateTime.now();

    // Base-level activation (Ebbinghaus Power-Law of Practice & Forgetting)
    double timeSum = 0.0;
    for (final accessTime in record.accessHistory) {
      final elapsedSeconds =
          max(1.0, now.difference(accessTime).inMilliseconds / 1000.0);
      timeSum += pow(elapsedSeconds, -decayRate);
    }

    final baseLevel = log(max(1e-6, timeSum));
    final importanceBonus = record.importance * importanceWeight;
    final contextBonus = contextSimilarity * 2.0;

    return baseLevel + importanceBonus + contextBonus;
  }
}

/// Owner-gated, cognitively grounded long-term memory store.
///
/// Implements NOOA's `nooa-memory` subsystem for persistent, human-like agent memory.
class CognitiveMemoryStore {
  final Map<String, CognitiveMemoryRecord> _records = {};
  final ActRActivationCalculator _calculator;

  CognitiveMemoryStore({
    ActRActivationCalculator? calculator,
  }) : _calculator = calculator ?? const ActRActivationCalculator();

  /// Adds or updates a memory record.
  void remember({
    required String id,
    required String ownerId,
    required String content,
    List<String> tags = const [],
    double importance = 0.5,
    List<double> embedding = const [],
    Map<String, dynamic> metadata = const {},
  }) {
    if (_records.containsKey(id)) {
      final existing = _records[id]!;
      existing.recordAccess();
      return;
    }

    _records[id] = CognitiveMemoryRecord(
      id: id,
      ownerId: ownerId,
      content: content,
      tags: tags,
      importance: importance,
      embedding: embedding,
      metadata: metadata,
    );
  }

  /// Retrieves memories for a specific owner, ranked by ACT-R cognitive activation.
  List<CognitiveMemoryRecord> recall({
    required String ownerId,
    String? tag,
    List<double>? queryEmbedding,
    int topK = 5,
    double minActivation = -10.0,
  }) {
    // 1. Owner-gating filter (Strict isolation)
    final ownerRecords =
        _records.values.where((r) => r.ownerId == ownerId).toList();

    if (tag != null) {
      ownerRecords.removeWhere((r) => !r.tags.contains(tag));
    }

    final scored = <MapEntry<CognitiveMemoryRecord, double>>[];

    for (final record in ownerRecords) {
      double similarity = 0.0;
      if (queryEmbedding != null &&
          record.embedding.isNotEmpty &&
          queryEmbedding.length == record.embedding.length) {
        similarity = _cosineSimilarity(queryEmbedding, record.embedding);
      }

      final activation = _calculator.calculateActivation(
        record,
        contextSimilarity: similarity,
      );

      if (activation >= minActivation) {
        scored.add(MapEntry(record, activation));
      }
    }

    // Sort by descending activation strength
    scored.sort((a, b) => b.value.compareTo(a.value));

    final results = scored.take(topK).map((e) {
      e.key.recordAccess(); // Recall reinforces the memory
      return e.key;
    }).toList();

    return results;
  }

  /// Total stored memory records across all owners.
  int get size => _records.length;

  /// Clears all memories.
  void clear() => _records.clear();

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }
}
