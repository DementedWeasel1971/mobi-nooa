import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 04: Tracing and JSONL Telemetry
///
/// Demonstrates observability in mobi-nooa where all prompt synthesis,
/// model calls, tool executions, and state mutations generate structured JSONL trace events.
class AnalyticsAgent extends NooaAgent {
  AnalyticsAgent()
      : super(
          name: 'AnalyticsAgent',
          role: 'Telemetry Demonstrator',
          description: 'Demonstrates observable telemetry traces.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'computeHash',
      description: 'Calculates length-based hash for input text.',
      parameters: const [
        ToolParameter(name: 'input', type: 'string', description: 'Raw text', required: true),
      ],
      returnType: 'int',
      invoker: (args) async => (args['input'] as String).length * 7,
    );
  }
}

Future<void> main() async {
  print('=== mobi-nooa Tutorial 04: Tracing & Telemetry ===\n');

  final mockModel = MockModelClient();
  mockModel.queueToolCall(
    toolName: 'computeHash',
    arguments: {'input': 'mobile-ai'},
    thought: 'Computing hash of input identifier.',
  );
  mockModel.queueText('Calculated hash value: 63');

  final agent = Quickstart.createAgent(
    () => AnalyticsAgent(),
    model: mockModel,
    tracerName: 'AnalyticsSession',
  );

  final result = await agent.ellipsis<String>('Hash the text "mobile-ai"');
  print('Result: $result\n');

  print('=== Exported Telemetry JSONL ===');
  print(agent.context.tracer.exportJsonL());
}
