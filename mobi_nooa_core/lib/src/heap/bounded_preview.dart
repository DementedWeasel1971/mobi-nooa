import 'dart:typed_data';

/// Generates token-bounded previews of complex objects for the LLM context.
///
/// Implements NOOA Principle 2: "Pass-by-reference over live objects".
/// Prevents large data structures from flooding the model's token context
/// while providing sufficient structural details (types, counts, head/tail samples).
class BoundedPreviewGenerator {
  final int maxStringLength;
  final int maxListItems;
  final int maxMapEntries;

  const BoundedPreviewGenerator({
    this.maxStringLength = 200,
    this.maxListItems = 5,
    this.maxMapEntries = 6,
  });

  /// Generates a bounded preview string for any given Dart object.
  String generate(dynamic object) {
    if (object == null) return 'null';
    if (object is num || object is bool) return object.toString();

    if (object is String) {
      if (object.length <= maxStringLength) {
        return '"$object"';
      }
      return '"${object.substring(0, maxStringLength)}..." (length: ${object.length} chars)';
    }

    if (object is Uint8List) {
      return '<Uint8List: ${object.lengthInBytes} bytes>';
    }

    if (object is List) {
      final total = object.length;
      if (total == 0) return '[]';
      final previewCount = total > maxListItems ? maxListItems : total;
      final samples = object
          .take(previewCount)
          .map((item) => generateSample(item))
          .join(', ');

      if (total > maxListItems) {
        return '[$samples, ... and ${total - maxListItems} more items] (total length: $total)';
      }
      return '[$samples] (length: $total)';
    }

    if (object is Set) {
      final total = object.length;
      if (total == 0) return '{}';
      final samples = object
          .take(maxListItems)
          .map((item) => generateSample(item))
          .join(', ');
      if (total > maxListItems) {
        return '{$samples, ... and ${total - maxListItems} more} (size: $total)';
      }
      return '{$samples} (size: $total)';
    }

    if (object is Map) {
      final total = object.length;
      if (total == 0) return '{}';
      final entries = object.entries.take(maxMapEntries).map((e) {
        final keyStr = e.key.toString();
        final valStr = generateSample(e.value);
        return '$keyStr: $valStr';
      }).join(', ');

      if (total > maxMapEntries) {
        return '{$entries, ... and ${total - maxMapEntries} more keys} (keys: $total)';
      }
      return '{$entries}';
    }

    // Custom objects or structured datasets
    try {
      if (object is Map<String, dynamic>) {
        return generate(object);
      }
      final str = object.toString();
      if (str.length <= maxStringLength) {
        return str;
      }
      return '${str.substring(0, maxStringLength)}...';
    } catch (_) {
      return '<Instance of ${object.runtimeType}>';
    }
  }

  /// Compact single-element preview for nested collections.
  String generateSample(dynamic item) {
    if (item == null) return 'null';
    if (item is num || item is bool) return item.toString();
    if (item is String) {
      return item.length > 30 ? '"${item.substring(0, 27)}..."' : '"$item"';
    }
    if (item is List) return 'List(${item.length})';
    if (item is Map) return 'Map(${item.keys.take(3).join(',')})';
    return item.runtimeType.toString();
  }
}
