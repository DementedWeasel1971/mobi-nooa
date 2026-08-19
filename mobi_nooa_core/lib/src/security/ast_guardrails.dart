/// Validation result from AST security analysis.
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
  String toString() => isValid ? 'AST Validation Passed' : 'Violations: ${violations.join(", ")}';
}

/// Defense-in-depth AST & script validator for CodeAct execution on mobile.
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
    ],
    this.maxCodeLength = 100000,
  });

  /// Validates a code snippet before execution in CodeAct.
  AstValidationResult validate(String code) {
    final violations = <String>[];

    if (code.length > maxCodeLength) {
      violations.add('Code length (${code.length}) exceeds maximum allowable ($maxCodeLength).');
    }

    // Check denied identifiers
    for (final id in deniedIdentifiers) {
      if (code.contains(id)) {
        violations.add('Use of forbidden identifier/module: "$id"');
      }
    }

    // Check denied regex patterns
    for (final pattern in deniedPatterns) {
      if (RegExp(pattern).hasMatch(code)) {
        violations.add('Detected dangerous execution pattern: "$pattern"');
      }
    }

    if (violations.isNotEmpty) {
      return AstValidationResult.violation(violations);
    }
    return AstValidationResult.pass();
  }
}
