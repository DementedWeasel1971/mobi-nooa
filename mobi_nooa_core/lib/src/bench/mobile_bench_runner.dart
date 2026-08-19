import 'benchmark_suite.dart';

/// Preconfigured Mobile Agent Benchmark tasks evaluating device actions, memory, and sensors.
class MobileBenchSuite {
  static BenchmarkSuite create() {
    final suite = BenchmarkSuite('Mobile-Bench-Autonomous');

    suite.addTask(BenchmarkTask(
      id: 'mob_task_001',
      title: 'Device battery health audit and eco-mode trigger',
      prompt: 'Audit device battery state and notify if below 20%.',
      expectedOutputSubstring: 'Battery',
      maxSteps: 5,
    ));

    suite.addTask(BenchmarkTask(
      id: 'mob_task_002',
      title: 'Pass-by-reference on-device dataset analytics',
      prompt: 'Generate 1000 items in ObjectHeap and calculate mean score.',
      expectedOutputSubstring: 'score',
      maxSteps: 6,
    ));

    return suite;
  }
}
