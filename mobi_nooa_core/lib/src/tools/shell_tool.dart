import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../security/ast_guardrails.dart';

/// Execution output from a shell invocation.
class ShellExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool isTruncated;

  ShellExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.isTruncated = false,
  });

  bool get isSuccess => exitCode == 0;

  Map<String, dynamic> toJson() => {
        'exitCode': exitCode,
        'stdout': stdout,
        'stderr': stderr,
        'durationMs': duration.inMilliseconds,
        'isTruncated': isTruncated,
      };

  @override
  String toString() => stdout.isNotEmpty && stderr.isEmpty
      ? stdout
      : (stderr.isNotEmpty ? '$stdout\nSTDERR: $stderr' : '[Exit code: $exitCode]');
}

/// Abstract Shell Harness supporting both native OS process execution and simulated in-memory shells.
abstract class ShellHarness {
  String get workingDirectory;
  Future<ShellExecutionResult> execute(
    String command, {
    Duration timeout = const Duration(seconds: 60),
  });
}

/// Local/Mobile OS process shell runner with AST security guardrails.
class LocalShellHarness implements ShellHarness {
  @override
  String workingDirectory;
  final int maxOutputChars;
  final AstGuardrails guardrails;

  LocalShellHarness({
    String? initialWorkingDirectory,
    this.maxOutputChars = 50000,
    AstGuardrails? guardrails,
  })  : workingDirectory = initialWorkingDirectory ?? Directory.current.path,
        guardrails = guardrails ?? const AstGuardrails();

  @override
  Future<ShellExecutionResult> execute(
    String command, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Enforce AST Guardrails on command string to prevent command injection / dangerous attacks
    final validation = guardrails.validate(command);
    if (!validation.isValid) {
      stopwatch.stop();
      return ShellExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Command rejected by AstGuardrails: ${validation.violations.join("; ")}',
        duration: stopwatch.elapsed,
      );
    }

    // Check for cd command
    final trimmed = command.trim();
    if (trimmed.startsWith('cd ')) {
      final target = trimmed.substring(3).trim();
      final resolved = Directory(target).isAbsolute
          ? Directory(target)
          : Directory('$workingDirectory/$target');
      if (await resolved.exists()) {
        workingDirectory = resolved.path;
        return ShellExecutionResult(
          exitCode: 0,
          stdout: 'Changed directory to $workingDirectory',
          stderr: '',
          duration: stopwatch.elapsed,
        );
      } else {
        return ShellExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: 'Directory does not exist: $target',
          duration: stopwatch.elapsed,
        );
      }
    }

    try {
      final isWindows = Platform.isWindows;
      final executable = isWindows ? 'powershell' : 'bash';
      final args = isWindows ? ['-NoProfile', '-Command', command] : ['-c', command];

      final process = await Process.start(
        executable,
        args,
        workingDirectory: workingDirectory,
        runInShell: true,
      );

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      });

      stopwatch.stop();
      var outStr = await stdoutFuture;
      var errStr = await stderrFuture;

      bool truncated = false;
      if (outStr.length > maxOutputChars) {
        outStr = '${outStr.substring(0, maxOutputChars)}\n... [Output truncated after $maxOutputChars characters]';
        truncated = true;
      }

      return ShellExecutionResult(
        exitCode: exitCode,
        stdout: outStr,
        stderr: errStr,
        duration: stopwatch.elapsed,
        isTruncated: truncated,
      );
    } catch (e) {
      stopwatch.stop();
      return ShellExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Shell execution error: $e',
        duration: stopwatch.elapsed,
      );
    }
  }
}
