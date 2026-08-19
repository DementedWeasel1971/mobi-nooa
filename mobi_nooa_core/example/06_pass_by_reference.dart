import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 06: Pass-by-Reference on Large Datasets
///
/// Demonstrates NOOA Principle 2: Instead of passing huge 5000-item arrays
/// into LLM prompt contexts, ObjectHeap stores them and generates compact,
/// token-bounded previews while providing handle-based access (`#ref_xxx`).
class BigDataAgent extends NooaAgent {
  BigDataAgent()
      : super(
          name: 'BigDataAgent',
          role: 'On-Device Data Analyst',
          description: 'Performs statistical calculations over large in-memory arrays.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'loadSensorTelemetry',
      description: 'Simulates reading 2000 sensor readings from on-device cache.',
      returnType: 'ObjectReference',
      invoker: (args) async {
        final dataset = List<Map<String, dynamic>>.generate(
          2000,
          (i) => {'index': i, 'temp': 20.0 + (i % 15) * 0.5, 'humidity': 40 + (i % 20)},
        );
        // Returns heap handle rather than raw 2000-item payload
        return context.heap.put(
          dataset,
          label: '2000 Sensor Readings',
        );
      },
    );

    registerAction(
      name: 'computeMeanTemp',
      description: 'Calculates mean temperature for a dataset handle.',
      parameters: const [
        ToolParameter(
          name: 'handle',
          type: 'string',
          description: 'ObjectHeap reference handle (#ref_xxx)',
          required: true,
        ),
      ],
      returnType: 'double',
      invoker: (args) async {
        final handle = args['handle'] as String;
        final list = context.heap.resolveHandleOrValue(handle) as List<Map<String, dynamic>>;
        final sum = list.fold<double>(0.0, (acc, r) => acc + (r['temp'] as double));
        return double.parse((sum / list.length).toStringAsFixed(2));
      },
    );
  }
}

Future<void> main() async {
  print('=== mobi-nooa Tutorial 06: Pass-by-Reference over Live Objects ===\n');

  final mockModel = MockModelClient();
  mockModel.queueToolCall(
    toolName: 'loadSensorTelemetry',
    arguments: {},
    thought: 'Loading 2000 sensor samples into ObjectHeap.',
  );
  mockModel.queueToolCall(
    toolName: 'computeMeanTemp',
    arguments: {'handle': '#ref_1'},
    thought: 'Computing mean temperature using heap handle #ref_1.',
  );
  mockModel.queueText('Analysis complete. Average temperature across 2,000 readings: 23.5°C');

  final agent = Quickstart.createAgent(
    () => BigDataAgent(),
    model: mockModel,
  );

  final analysis = await agent.ellipsis<String>('Load sensor data and report average temperature.');
  print('Model Response:\n$analysis\n');

  print('=== ObjectHeap Summary Table ===');
  print(agent.context.heap.toPromptSummary());
}
