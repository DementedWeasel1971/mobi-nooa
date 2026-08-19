
/// Represents a pass-by-reference handle to a live in-memory object on the mobile harness.
///
/// In NOOA (arXiv:2607.20709), complex or large data structures (dataframes, binary buffers,
/// API responses) are stored in the execution environment rather than serialized verbatim
/// into the LLM prompt. The LLM receives an [ObjectReference] containing the handle ID,
/// type, and a bounded preview.
class ObjectReference {
  /// Unique identifier of the object in the [ObjectHeap] (e.g. `#ref_001`).
  final String handle;

  /// Dart type name of the referenced object.
  final String typeName;

  /// Human-readable description or label for the object.
  final String label;

  /// Bounded text preview for prompt injection.
  final String preview;

  /// Approximate memory size in bytes, if known.
  final int byteSize;

  /// Timestamp when object was registered into the heap.
  final DateTime createdAt;

  /// Optional metadata tags.
  final Map<String, dynamic> metadata;

  ObjectReference({
    required this.handle,
    required this.typeName,
    required this.preview,
    this.label = '',
    this.byteSize = 0,
    DateTime? createdAt,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  /// Formats the reference for inclusion in LLM prompts and CodeAct environments.
  String toPromptString() {
    return '[ObjectRef handle="$handle" type="$typeName"${label.isNotEmpty ? ' label="$label"' : ''} preview="$preview"]';
  }

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'typeName': typeName,
        'label': label,
        'preview': preview,
        'byteSize': byteSize,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
      };

  factory ObjectReference.fromJson(Map<String, dynamic> json) =>
      ObjectReference(
        handle: json['handle'] as String,
        typeName: json['typeName'] as String,
        label: (json['label'] as String?) ?? '',
        preview: json['preview'] as String,
        byteSize: (json['byteSize'] as int?) ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      );

  @override
  String toString() => toPromptString();
}
