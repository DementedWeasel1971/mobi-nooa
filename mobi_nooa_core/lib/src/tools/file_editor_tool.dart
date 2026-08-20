import 'dart:async';
import '../harness/filesystem_harness.dart';
import '../security/ast_guardrails.dart';

/// Result of a file editor operation.
class FileEditorResult {
  final bool success;
  final String output;
  final String? error;

  FileEditorResult({
    required this.success,
    required this.output,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'output': output,
        if (error != null) 'error': error,
      };

  @override
  String toString() => success ? output : 'Error: $error\n$output';
}

/// Robust file editing tool suite used by BenchAgent and mobile coding agents
/// with built-in path traversal security guardrails.
class FileEditorTool {
  final FileSystemHarness fs;
  final int maxViewLines;

  FileEditorTool({
    required this.fs,
    this.maxViewLines = 250,
  });

  /// Views contents of a file with optional line-number slicing.
  Future<FileEditorResult> viewFile(
    String path, {
    int startLine = 1,
    int? endLine,
  }) async {
    try {
      if (!AstGuardrails.isPathSafe(path)) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'Security Error: Path traversal attempt detected in "$path".',
        );
      }

      if (!await fs.exists(path)) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'File does not exist: $path',
        );
      }

      final content = await fs.readFile(path);
      final lines = content.split('\n');
      final totalLines = lines.length;

      final start = startLine < 1 ? 1 : startLine;
      final end = (endLine == null || endLine > totalLines)
          ? (start + maxViewLines - 1 > totalLines ? totalLines : start + maxViewLines - 1)
          : endLine;

      if (start > totalLines) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'startLine ($start) is greater than total lines ($totalLines).',
        );
      }

      final buffer = StringBuffer();
      buffer.writeln('File: $path (Lines $start-$end of $totalLines)');
      for (int i = start; i <= end; i++) {
        final lineNum = i.toString().padLeft(4, ' ');
        buffer.writeln('$lineNum | ${lines[i - 1]}');
      }

      if (end < totalLines) {
        buffer.writeln('... [${totalLines - end} more lines not shown]');
      }

      return FileEditorResult(success: true, output: buffer.toString().trim());
    } catch (e) {
      return FileEditorResult(
        success: false,
        output: '',
        error: 'Failed to read file: $e',
      );
    }
  }

  /// Replaces unique substring in a file (similar to NOOA / SWE-bench str_replace).
  Future<FileEditorResult> strReplace(
    String path, {
    required String oldStr,
    required String newStr,
  }) async {
    try {
      if (!AstGuardrails.isPathSafe(path)) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'Security Error: Path traversal attempt detected in "$path".',
        );
      }

      if (!await fs.exists(path)) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'File does not exist: $path',
        );
      }

      final content = await fs.readFile(path);

      final count = RegExp(RegExp.escape(oldStr)).allMatches(content).length;
      if (count == 0) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'Target text not found in $path. Make sure exact whitespace matches.',
        );
      }

      if (count > 1) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'Target text found $count times in $path. Replacement must be unique. Provide more surrounding context.',
        );
      }

      final updatedContent = content.replaceFirst(oldStr, newStr);
      await fs.writeFile(path, updatedContent);

      return FileEditorResult(
        success: true,
        output: 'Successfully replaced occurrence in $path.',
      );
    } catch (e) {
      return FileEditorResult(
        success: false,
        output: '',
        error: 'Failed to replace in file: $e',
      );
    }
  }

  /// Creates or overwrites a file.
  Future<FileEditorResult> createFile(
    String path, {
    required String content,
  }) async {
    try {
      if (!AstGuardrails.isPathSafe(path)) {
        return FileEditorResult(
          success: false,
          output: '',
          error: 'Security Error: Path traversal attempt detected in "$path".',
        );
      }

      await fs.writeFile(path, content);
      return FileEditorResult(
        success: true,
        output: 'Successfully created/updated file: $path (${content.length} characters).',
      );
    } catch (e) {
      return FileEditorResult(
        success: false,
        output: '',
        error: 'Failed to create file: $e',
      );
    }
  }
}
