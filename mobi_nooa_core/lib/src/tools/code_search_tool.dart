import 'dart:async';
import '../harness/filesystem_harness.dart';

/// Represents a matched line in a file search.
class GrepMatch {
  final String path;
  final int lineNumber;
  final String lineContent;

  GrepMatch({
    required this.path,
    required this.lineNumber,
    required this.lineContent,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'lineNumber': lineNumber,
        'lineContent': lineContent,
      };

  @override
  String toString() => '$path:$lineNumber: $lineContent';
}

/// Represents an extracted code symbol (class, method, function).
class CodeSymbol {
  final String name;
  final String kind; // 'class', 'function', 'method', 'enum'
  final String path;
  final int lineNumber;

  CodeSymbol({
    required this.name,
    required this.kind,
    required this.path,
    required this.lineNumber,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind,
        'path': path,
        'lineNumber': lineNumber,
      };

  @override
  String toString() => '[$kind] $name ($path:$lineNumber)';
}

/// Codebase exploration tool for file discovery, regex grep, and symbol navigation.
class CodeSearchTool {
  final FileSystemHarness fs;

  CodeSearchTool({required this.fs});

  /// Finds files matching pattern or extension.
  Future<List<String>> findFiles({
    String rootPath = '',
    String? pattern,
    String? extension,
  }) async {
    final allFiles = await fs.listFiles(rootPath, recursive: true);
    return allFiles.where((file) {
      if (extension != null && !file.endsWith('.$extension') && !file.endsWith(extension)) {
        return false;
      }
      if (pattern != null && !file.toLowerCase().contains(pattern.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Searches for regex pattern across files.
  Future<List<GrepMatch>> grep({
    required String query,
    String rootPath = '',
    String? extension,
    bool caseInsensitive = true,
    int maxMatches = 100,
  }) async {
    final files = await findFiles(rootPath: rootPath, extension: extension);
    final regex = RegExp(query, caseSensitive: !caseInsensitive);
    final matches = <GrepMatch>[];

    for (final file in files) {
      if (matches.length >= maxMatches) break;
      try {
        final content = await fs.readFile(file);
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (regex.hasMatch(lines[i])) {
            matches.add(GrepMatch(
              path: file,
              lineNumber: i + 1,
              lineContent: lines[i].trim(),
            ));
            if (matches.length >= maxMatches) break;
          }
        }
      } catch (_) {}
    }

    return matches;
  }

  /// Extracts class and function symbol outlines from files.
  Future<List<CodeSymbol>> extractSymbols({
    String rootPath = '',
    String? extension,
  }) async {
    final files = await findFiles(rootPath: rootPath, extension: extension);
    final symbols = <CodeSymbol>[];

    final classRegex = RegExp(r'^\s*(?:abstract\s+)?(?:class|enum|mixin|interface|struct)\s+([A-Za-z0-9_]+)');
    final funcRegex = RegExp(r'^\s*(?:(?:def|fun|function|fn|void|Future|int|double|String|bool|[A-Za-z0-9_<>,?]+)\s+)?([A-Za-z0-9_]+)\s*\([^)]*\)\s*(?:async\s*)?[:{;]');

    for (final file in files) {
      try {
        final content = await fs.readFile(file);
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];

          final classMatch = classRegex.firstMatch(line);
          if (classMatch != null) {
            symbols.add(CodeSymbol(
              name: classMatch.group(1)!,
              kind: 'class',
              path: file,
              lineNumber: i + 1,
            ));
            continue;
          }

          final funcMatch = funcRegex.firstMatch(line);
          if (funcMatch != null && !line.trim().startsWith('if') && !line.trim().startsWith('for') && !line.trim().startsWith('while')) {
            symbols.add(CodeSymbol(
              name: funcMatch.group(1)!,
              kind: 'function',
              path: file,
              lineNumber: i + 1,
            ));
          }
        }
      } catch (_) {}
    }

    return symbols;
  }
}
