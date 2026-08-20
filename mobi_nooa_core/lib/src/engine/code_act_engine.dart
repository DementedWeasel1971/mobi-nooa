import 'sandboxed_environment.dart';
import 'ast_evaluator.dart';
import '../heap/object_reference.dart';
import '../security/ast_guardrails.dart';

/// Result of executing a CodeAct snippet.
class CodeActResult {
  final bool success;
  final dynamic returnValue;
  final ObjectReference? returnedObjectRef;
  final List<String> stdout;
  final String? error;
  final Duration executionDuration;

  CodeActResult({
    required this.success,
    this.returnValue,
    this.returnedObjectRef,
    this.stdout = const [],
    this.error,
    required this.executionDuration,
  });

  /// Formats the execution output for injection back into the LLM loop.
  String toPromptOutput() {
    final buffer = StringBuffer();
    if (stdout.isNotEmpty) {
      buffer.writeln('--- STDOUT ---');
      buffer.writeln(stdout.join('\n'));
    }
    if (error != null) {
      buffer.writeln('--- ERROR ---');
      buffer.writeln(error);
    } else if (returnedObjectRef != null) {
      buffer.writeln('--- RESULT (Stored in ObjectHeap) ---');
      buffer.writeln(returnedObjectRef!.toPromptString());
    } else if (returnValue != null) {
      buffer.writeln('--- RESULT ---');
      buffer.writeln(returnValue.toString());
    } else {
      buffer.writeln('--- RESULT: Execution completed with no return value ---');
    }
    return buffer.toString().trim();
  }

  @override
  String toString() => toPromptOutput();
}

/// Mobile CodeAct execution engine with defense-in-depth AST security guardrails.
///
/// Implements NOOA Principle 3: "Code as action (CodeAct)".
class CodeActEngine {
  final SandboxedEnvironment environment;
  final AstGuardrails guardrails;
  final AstEvaluator _evaluator;

  CodeActEngine(
    this.environment, {
    AstGuardrails? guardrails,
  })  : guardrails = guardrails ?? const AstGuardrails(),
        _evaluator = AstEvaluator(environment);

  /// Executes code extracted from LLM responses after verifying AST guardrails.
  Future<CodeActResult> execute(String codeSnippet) async {
    final cleanCode = extractCodeBlock(codeSnippet);
    final stopwatch = Stopwatch()..start();
    environment.stdout.clear();

    // 1. Enforce AST Security Guardrails before evaluation
    final validation = guardrails.validate(cleanCode);
    if (!validation.isValid) {
      stopwatch.stop();
      return CodeActResult(
        success: false,
        error: 'Security Guardrails Violation: ${validation.violations.join("; ")}',
        stdout: [],
        executionDuration: stopwatch.elapsed,
      );
    }

    try {
      final rawResult = _evaluator.executeScript(cleanCode);
      stopwatch.stop();

      ObjectReference? ref;
      dynamic finalVal = rawResult;

      if (rawResult != null) {
        final wrapped = environment.heap.maybeWrap(rawResult);
        if (wrapped is ObjectReference) {
          ref = wrapped;
          finalVal = wrapped;
        }
      }

      return CodeActResult(
        success: true,
        returnValue: finalVal,
        returnedObjectRef: ref,
        stdout: List.from(environment.stdout),
        executionDuration: stopwatch.elapsed,
      );
    } catch (e, stack) {
      stopwatch.stop();
      return CodeActResult(
        success: false,
        error: '$e\n$stack',
        stdout: List.from(environment.stdout),
        executionDuration: stopwatch.elapsed,
      );
    }
  }

  /// Extracts code from markdown fences (```dart, ```python, etc.) or returns the raw text.
  static String extractCodeBlock(String text) {
    final fenceRegex = RegExp(r'```(?:dart|python|js|json|code)?\s*([\s\S]*?)```', multiLine: true);
    final match = fenceRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return text.trim();
  }
}
