import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  String toString() {
    final buffer = StringBuffer();
    if (stdout.isNotEmpty) buffer.writeln(stdout);
    if (stderr.isNotEmpty) buffer.writeln('STDERR: $stderr');
    buffer.writeln('[Exit code: $exitCode]');
    return buffer.toString().trim();
  }
}

/// Abstract Shell Harness supporting both native OS process execution and simulated in-memory shells.
abstract class ShellHarness {
  String get workingDirectory;
  Future<ShellExecutionResult> execute(
    String command, {
    Duration timeout = const Duration(seconds: 60),
  });
}

/// Local/Mobile OS process shell runner.
class LocalShellHarness implements ShellHarness {
  @override
  String workingDirectory;
  final int maxOutputChars;

  LocalShellHarness({
    String? initialWorkingDirectory,
    this.maxOutputChars = 50000,
  }) : workingDirectory = initialWorkingDirectory ?? Directory.current.path;

  @override
  Future<ShellExecutionResult> execute(
    String command, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final stopwatch = Stopwatch()..start();

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
