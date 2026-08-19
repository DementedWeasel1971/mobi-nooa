import 'object_reference.dart';
import 'bounded_preview.dart';

/// In-memory Object Heap for live pass-by-reference agent execution on mobile.
///
/// Implements NOOA's live object environment:
/// Complex objects (dataframes, images, result sets, file buffers) are stored here.
/// The model interacts with them using handles (e.g. `#ref_1`).
class ObjectHeap {
  final Map<String, dynamic> _objects = {};
  final Map<String, ObjectReference> _references = {};
  final BoundedPreviewGenerator _previewGenerator;
  int _counter = 0;

  /// Auto-reference threshold: strings or collections exceeding this size in bytes/elements
  /// are automatically converted to heap references when returned by actions.
  final int autoReferenceThresholdBytes;

  ObjectHeap({
    BoundedPreviewGenerator? previewGenerator,
    this.autoReferenceThresholdBytes = 300,
  }) : _previewGenerator = previewGenerator ?? const BoundedPreviewGenerator();

  /// Registers an object into the heap and returns its [ObjectReference].
  ObjectReference put(
    dynamic object, {
    String? label,
    String? preferredHandle,
    Map<String, dynamic> metadata = const {},
  }) {
    final handle = preferredHandle ?? '#ref_${++_counter}';
    _objects[handle] = object;

    final typeName = object == null ? 'Null' : object.runtimeType.toString();
    final preview = _previewGenerator.generate(object);
    final size = _estimateSize(object);

    final ref = ObjectReference(
      handle: handle,
      typeName: typeName,
      label: label ?? '',
      preview: preview,
      byteSize: size,
      metadata: metadata,
    );

    _references[handle] = ref;
    return ref;
  }

  /// Retrieves the live object by handle.
  dynamic get(String handle) {
    if (!_objects.containsKey(handle)) {
      throw ArgumentError('Object handle "$handle" not found in ObjectHeap.');
    }
    return _objects[handle];
  }

  /// Checks if handle exists in heap.
  bool contains(String handle) => _objects.containsKey(handle);

  /// Retrieves the metadata reference by handle.
  ObjectReference? getReference(String handle) => _references[handle];

  /// Removes an object from heap.
  dynamic remove(String handle) {
    _references.remove(handle);
    return _objects.remove(handle);
  }

  /// All currently registered object references.
  List<ObjectReference> get references =>
      List.unmodifiable(_references.values);

  /// Total count of objects in heap.
  int get size => _objects.length;

  /// Clears all objects from heap.
  void clear() {
    _objects.clear;
    _references.clear();
    _counter = 0;
  }

  /// Analyzes a returned value: if it is large/complex, stores it in heap and returns
  /// an [ObjectReference]; otherwise returns the raw value.
  dynamic maybeWrap(dynamic value, {String? label}) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is ObjectReference) {
      return value;
    }

    if (value is String) {
      if (value.length > autoReferenceThresholdBytes) {
        return put(value, label: label ?? 'TextBuffer');
      }
      return value;
    }

    if (value is List) {
      if (value.length > 5 || _estimateSize(value) > autoReferenceThresholdBytes) {
        return put(value, label: label ?? 'List(${value.length})');
      }
      return value;
    }

    if (value is Map) {
      if (value.length > 5 || _estimateSize(value) > autoReferenceThresholdBytes) {
        return put(value, label: label ?? 'Map(${value.length})');
      }
      return value;
    }

    // Default for arbitrary custom objects
    return put(value, label: label ?? value.runtimeType.toString());
  }

  /// Helper to substitute `#ref_xxx` patterns in an expression/string with their actual object values.
  dynamic resolveHandleOrValue(dynamic input) {
    if (input is String && input.startsWith('#ref_') && contains(input)) {
      return get(input);
    }
    return input;
  }

  /// Generates a summary markdown table of the live heap for the agent's system prompt.
  String toPromptSummary() {
    if (_references.isEmpty) {
      return 'No live heap objects.';
    }

    final buffer = StringBuffer();
    buffer.writeln('| Handle | Type | Label | Preview |');
    buffer.writeln('| --- | --- | --- | --- |');
    for (final ref in _references.values) {
      final safePreview = ref.preview.replaceAll('|', '\\|').replaceAll('\n', ' ');
      buffer.writeln('| `${ref.handle}` | `${ref.typeName}` | ${ref.label} | $safePreview |');
    }
    return buffer.toString();
  }

  int _estimateSize(dynamic object) {
    if (object == null) return 0;
    if (object is String) return object.length * 2;
    if (object is List) {
      return object.fold<int>(0, (prev, elem) => prev + _estimateSize(elem));
    }
    if (object is Map) {
      return object.entries.fold<int>(
        0,
        (prev, e) => prev + _estimateSize(e.key) + _estimateSize(e.value),
      );
    }
    return 64; // Default baseline object overhead
  }
}
