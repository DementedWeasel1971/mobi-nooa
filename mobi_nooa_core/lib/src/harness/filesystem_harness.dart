import 'dart:async';
import 'dart:io';

/// Sandboxed file system harness for mobile agent workspace access.
abstract class FileSystemHarness {
  Future<String> readFile(String path);
  Future<void> writeFile(String path, String content);
  Future<bool> exists(String path);
  Future<List<String>> listFiles(String path, {bool recursive = false});
  Future<void> deleteFile(String path);
}

/// In-memory sandboxed filesystem implementation.
class MemoryFileSystemHarness implements FileSystemHarness {
  final Map<String, String> _files = {};

  MemoryFileSystemHarness([Map<String, String>? initialFiles]) {
    if (initialFiles != null) {
      _files.addAll(initialFiles);
    }
  }

  @override
  Future<String> readFile(String path) async {
    final normalized = _normalize(path);
    if (!_files.containsKey(normalized)) {
      throw FileSystemException('File not found: $path');
    }
    return _files[normalized]!;
  }

  @override
  Future<void> writeFile(String path, String content) async {
    _files[_normalize(path)] = content;
  }

  @override
  Future<bool> exists(String path) async {
    return _files.containsKey(_normalize(path));
  }

  @override
  Future<List<String>> listFiles(String path, {bool recursive = false}) async {
    final prefix = _normalize(path);
    return _files.keys
        .where((k) => k.startsWith(prefix))
        .toList();
  }

  @override
  Future<void> deleteFile(String path) async {
    _files.remove(_normalize(path));
  }

  String _normalize(String path) => path.replaceAll('\\', '/').trim();
}
