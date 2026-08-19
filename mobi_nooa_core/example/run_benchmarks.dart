import 'package:mobi_nooa_core/mobi_nooa_core.dart';

Future<void> main() async {
  print('=== mobi-nooa: Benchmark Evaluation Runner ===');

  // 1. Run Mobile Bench Suite
  print('\nRunning Mobile-Bench-Autonomous Suite...');
  final mobileSuite = MobileBenchSuite.create();
  final mobileReport = await mobileSuite.evaluate(() {
    final mockModel = MockModelClient();
    mockModel.queueText('Battery is at 85% and charging. score calculation mean is 50.5');
    return Quickstart.createAgent(() => GeneralMobileAgent(), model: mockModel);
  });
  print(mobileReport);

  // 2. Run SWE-bench Verified Mobile Suite
  print('\nRunning SWE-bench-Verified-Mobile Suite with BenchAgent...');
  final sweSuite = SweBenchSuite.create();
  final sweReport = await sweSuite.evaluate(() {
    final mockModel = MockModelClient();
    mockModel.queueHandler((messages, tools) {
      final userPrompt = messages.last.content;
      if (userPrompt.contains('chunker.py')) {
        return ModelResponse(
          text: 'I have applied the fix to /workspace/chunker.py and resolved the remainder slicing.',
        );
      }
      return ModelResponse(
        text: 'Loaded app_name mobi-nooa from /workspace/config.json.',
      );
    });

    return Quickstart.createAgent(() => BenchAgent(), model: mockModel);
  });
  print(sweReport);

  print('\nExported JSONL Report:');
  print(sweReport.exportJsonL());
}
