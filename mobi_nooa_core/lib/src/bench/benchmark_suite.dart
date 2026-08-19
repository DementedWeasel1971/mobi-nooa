import 'dart:async';
import 'dart:convert';
import '../agent/nooa_agent.dart';
import '../models/model_client.dart';

/// A single benchmark problem instance (SWE-bench / MobileBench task).
class BenchmarkTask {
  final String id;
  final String title;
  final String prompt;
  final Map<String, String> initialFiles;
  final String? verificationCommand;
  final String? expectedOutputSubstring;
  final int maxSteps;

  BenchmarkTask({
    required this.id,
    required this.title,
    required this.prompt,
    this.initialFiles = const {},
    this.verificationCommand,
    this.expectedOutputSubstring,
    this.maxSteps = 10,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'prompt': prompt,
        'initialFiles': initialFiles,
        if (verificationCommand != null)
          'verificationCommand': verificationCommand,
        if (expectedOutputSubstring != null)
          'expectedOutputSubstring': expectedOutputSubstring,
        'maxSteps': maxSteps,
      };
}

/// Evaluation result for a benchmark task.
class BenchmarkTaskResult {
  final String taskId;
  final bool isResolved;
  final int stepsUsed;
  final TokenUsage tokenUsage;
  final Duration duration;
  final String? agentOutput;
  final String? error;

  BenchmarkTaskResult({
    required this.taskId,
    required this.isResolved,
    required this.stepsUsed,
    required this.tokenUsage,
    required this.duration,
    this.agentOutput,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'isResolved': isResolved,
        'stepsUsed': stepsUsed,
        'promptTokens': tokenUsage.promptTokens,
        'completionTokens': tokenUsage.completionTokens,
        'totalTokens': tokenUsage.totalTokens,
        'durationMs': duration.inMilliseconds,
        if (agentOutput != null) 'agentOutput': agentOutput,
        if (error != null) 'error': error,
      };
}

/// Aggregate report of a benchmark evaluation run.
class BenchmarkReport {
  final String suiteName;
  final DateTime startTime;
  final int totalTasks;
  final int resolvedTasks;
  final double passRate;
  final double avgSteps;
  final int totalTokens;
  final List<BenchmarkTaskResult> results;

  BenchmarkReport({
    required this.suiteName,
    required this.startTime,
    required this.totalTasks,
    required this.resolvedTasks,
    required this.passRate,
    required this.avgSteps,
    required this.totalTokens,
    required this.results,
  });

  Map<String, dynamic> toJson() => {
        'suiteName': suiteName,
        'startTime': startTime.toIso8601String(),
        'totalTasks': totalTasks,
        'resolvedTasks': resolvedTasks,
        'passRate': double.parse(passRate.toStringAsFixed(2)),
        'avgSteps': double.parse(avgSteps.toStringAsFixed(2)),
        'totalTokens': totalTokens,
        'results': results.map((r) => r.toJson()).toList(),
      };

  String exportJsonL() {
    return results.map((r) => jsonEncode(r.toJson())).join('\n');
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Benchmark Report: $suiteName ===');
    buffer.writeln('Pass Rate: ${(passRate * 100).toStringAsFixed(1)}% ($resolvedTasks / $totalTasks)');
    buffer.writeln('Avg Steps per Task: ${avgSteps.toStringAsFixed(2)}');
    buffer.writeln('Total Tokens: $totalTokens');
    return buffer.toString();
  }
}

/// Evaluation runner for benchmark datasets.
class BenchmarkSuite {
  final String name;
  final List<BenchmarkTask> tasks = [];

  BenchmarkSuite(this.name);

  void addTask(BenchmarkTask task) {
    tasks.add(task);
  }

  /// Runs all tasks against an agent instance.
  Future<BenchmarkReport> evaluate(NooaAgent Function() agentFactory) async {
    final startTime = DateTime.now();
    final results = <BenchmarkTaskResult>[];

    for (final task in tasks) {
      final taskStopwatch = Stopwatch()..start();
      final agent = agentFactory();

      // Populate initial workspace files if any
      for (final entry in task.initialFiles.entries) {
        await agent.context.harness.fs.writeFile(entry.key, entry.value);
      }

      try {
        final output = await agent.ellipsis<String>(
          task.prompt,
          maxSteps: task.maxSteps,
        );
        taskStopwatch.stop();

        bool resolved = true;
        if (task.expectedOutputSubstring != null) {
          resolved = output.contains(task.expectedOutputSubstring!);
        }

        results.add(BenchmarkTaskResult(
          taskId: task.id,
          isResolved: resolved,
          stepsUsed: agent.context.tracer.events
              .where((e) => e.stepIndex > 0)
              .map((e) => e.stepIndex)
              .fold(0, (max, i) => i > max ? i : max),
          tokenUsage: agent.context.tracer.cumulativeUsage,
          duration: taskStopwatch.elapsed,
          agentOutput: output,
        ));
      } catch (e) {
        taskStopwatch.stop();
        results.add(BenchmarkTaskResult(
          taskId: task.id,
          isResolved: false,
          stepsUsed: task.maxSteps,
          tokenUsage: agent.context.tracer.cumulativeUsage,
          duration: taskStopwatch.elapsed,
          error: e.toString(),
        ));
      }
    }

    final resolvedCount = results.where((r) => r.isResolved).length;
    final totalSteps = results.fold<int>(0, (sum, r) => sum + r.stepsUsed);
    final totalTokens = results.fold<int>(
      0,
      (sum, r) => sum + r.tokenUsage.totalTokens,
    );

    return BenchmarkReport(
      suiteName: name,
      startTime: startTime,
      totalTasks: tasks.length,
      resolvedTasks: resolvedCount,
      passRate: tasks.isEmpty ? 0.0 : resolvedCount / tasks.length,
      avgSteps: tasks.isEmpty ? 0.0 : totalSteps / tasks.length,
      totalTokens: totalTokens,
      results: results,
    );
  }
}
