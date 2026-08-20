/// Validation result from AST and security analysis.
class AstValidationResult {
  final bool isValid;
  final List<String> violations;

  const AstValidationResult({
    required this.isValid,
    this.violations = const [],
  });

  factory AstValidationResult.pass() => const AstValidationResult(isValid: true);

  factory AstValidationResult.violation(List<String> violations) =>
      AstValidationResult(isValid: false, violations: violations);

  @override
  String toString() => isValid ? 'Security Validation Passed' : 'Violations: ${violations.join(", ")}';
}

/// Comprehensive defense-in-depth security guardrails for mobi-nooa:
/// - CodeAct AST script validation (denied identifiers & modules)
/// - Shell command injection & dangerous pattern filtering
/// - Path traversal & sandbox boundary enforcement
/// - Prompt injection delimiter sanitization
class AstGuardrails {
  final List<String> deniedIdentifiers;
  final List<String> deniedPatterns;
  final int maxCodeLength;

  const AstGuardrails({
    this.deniedIdentifiers = const [
      'exit',
      'Process.kill',
      'dart:mirrors',
      'dart:isolate.spawnUri',
      'System.exit',
      'Runtime.getRuntime',
    ],
    this.deniedPatterns = const [
      r'rm\s+-rf\s+/',
      r'format\s+[A-Z]:',
      r':\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;', // Fork bomb
      r'dd\s+if=.*of=/dev/',
      r'mkfs\..*',
      r'chmod\s+-R\s+777\s+/',
    ],
    this.maxCodeLength = 100000,
  });

  /// Validates a code snippet or shell command before execution.
  AstValidationResult validate(String code) {
    final violations = <String>[];

    if (code.length > maxCodeLength) {
      violations.add('Input length (${code.length}) exceeds maximum allowable ($maxCodeLength).');
    }

    // Check denied identifiers
    for (final id in deniedIdentifiers) {
      if (code.contains(id)) {
        violations.add('Use of forbidden identifier/module: "$id"');
      }
    }

    // Check denied regex patterns
    for (final pattern in deniedPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(code)) {
        violations.add('Detected dangerous execution pattern: "$pattern"');
      }
    }

    if (violations.isNotEmpty) {
      return AstValidationResult.violation(violations);
    }
    return AstValidationResult.pass();
  }

  /// Validates file paths to prevent Path Traversal attacks (e.g. `../../../../etc/passwd`).
  static bool isPathSafe(String path, {String? allowedRoot}) {
    final normalized = path.replaceAll('\\', '/');

    // Reject explicit directory traversal components
    if (normalized.contains('/../') || normalized.startsWith('../') || normalized.endsWith('/..') || normalized == '..') {
      return false;
    }

    // If an allowedRoot is specified, verify the path stays within it
    if (allowedRoot != null) {
      final normalizedRoot = allowedRoot.replaceAll('\\', '/');
      if (!normalized.startsWith(normalizedRoot)) {
        return false;
      }
    }

    return true;
  }

  /// Sanitizes text to prevent indirect prompt injection and control token escapes.
  static String sanitizePromptText(String text) {
    // Strip common LLM chat delimiters and control tags that could hijack model roles
    return text
        .replaceAll('<|im_start|>', '[im_start]')
        .replaceAll('<|im_end|>', '[im_end]')
        .replaceAll('<|system|>', '[system]')
        .replaceAll('<|user|>', '[user]')
        .replaceAll('<|assistant|>', '[assistant]')
        .replaceAll('<start_of_turn>', '[start_of_turn]')
        .replaceAll('<end_of_turn>', '[end_of_turn]');
  }
}
