import 'benchmark_suite.dart';

/// Preconfigured SWE-bench Verified coding benchmark tasks.
class SweBenchSuite {
  static BenchmarkSuite create() {
    final suite = BenchmarkSuite('SWE-bench-Verified-Mobile');

    suite.addTask(BenchmarkTask(
      id: 'swe_task_001',
      title: 'Fix off-by-one index error in array chunking',
      prompt:
          'Locate the bug in /workspace/chunker.py where chunking misses the final remainder slice, and fix it so all tests pass.',
      initialFiles: {
        '/workspace/chunker.py': '''
def chunk_list(items, size):
    chunks = []
    for i in range(0, len(items) - size, size):
        chunks.append(items[i:i + size])
    return chunks
''',
        '/workspace/test_chunker.py': '''
from chunker import chunk_list
def test():
    assert chunk_list([1, 2, 3, 4, 5], 2) == [[1, 2], [3, 4], [5]]
''',
      },
      expectedOutputSubstring: 'fix',
      maxSteps: 8,
    ));

    suite.addTask(BenchmarkTask(
      id: 'swe_task_002',
      title: 'Implement missing JSON configuration loader',
      prompt:
          'Create a config loader in /workspace/config.py that parses config.json and returns the app_name string.',
      initialFiles: {
        '/workspace/config.json': '{"app_name": "mobi-nooa", "version": "1.0.0"}',
      },
      expectedOutputSubstring: 'mobi-nooa',
      maxSteps: 6,
    ));

    return suite;
  }
}
