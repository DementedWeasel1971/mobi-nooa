import 'dart:math';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// Reference Mobile Data Science Agent demonstrating NOOA Principle 2 (Pass-by-Reference over Live Objects)
/// and Principle 3 (Code as Action).
class DataScientistAgent extends NooaAgent {
  DataScientistAgent()
      : super(
          name: 'DataScientistAgent',
          role: 'Mobile Data Scientist & Analyst',
          description:
              'Analyzes large on-device datasets by reference without prompt bloating.',
        );

  @override
  void initAgent() {
    // Register actions
    registerAction(
      name: 'generateSyntheticDataset',
      description: 'Generates a dataset of N numeric records and stores it in ObjectHeap.',
      parameters: const [
        ToolParameter(
          name: 'count',
          type: 'integer',
          description: 'Number of rows to generate',
          required: true,
        ),
      ],
      returnType: 'ObjectReference',
      invoker: (args) async {
        final count = (args['count'] as num?)?.toInt() ?? 1000;
        final rng = Random(42);
        final dataset = List.generate(count, (i) {
          final age = 18 + rng.nextInt(60);
          final score = (rng.nextDouble() * 100).roundToDouble();
          final category = ['A', 'B', 'C'][rng.nextInt(3)];
          return {'id': i, 'age': age, 'score': score, 'category': category};
        });

        // Large dataset is automatically placed into ObjectHeap (Pass-by-Reference)
        return dataset;
      },
    );

    registerAction(
      name: 'calculateStats',
      description: 'Calculates summary metrics (count, mean, min, max) for a dataset handle.',
      parameters: const [
        ToolParameter(
          name: 'dataHandle',
          type: 'string',
          description: 'ObjectHeap handle (e.g. #ref_1) of the dataset',
          required: true,
        ),
        ToolParameter(
          name: 'column',
          type: 'string',
          description: 'Numeric column name to aggregate (e.g. score or age)',
          required: true,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final raw = args['dataHandle'];
        final column = args['column'] as String;

        List list;
        if (raw is List) {
          list = raw;
        } else if (raw is String && context.heap.contains(raw)) {
          list = context.heap.get(raw) as List;
        } else {
          throw ArgumentError('Invalid dataset handle: $raw');
        }

        final values = list
            .map((row) => (row as Map)[column])
            .whereType<num>()
            .toList();

        if (values.isEmpty) {
          return {'count': 0, 'mean': 0.0};
        }

        final sum = values.reduce((a, b) => a + b);
        final minVal = values.reduce((a, b) => a < b ? a : b);
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        final mean = sum / values.length;

        final stats = {
          'column': column,
          'count': values.length,
          'mean': double.parse(mean.toStringAsFixed(2)),
          'min': minVal,
          'max': maxVal,
        };

        // Update explicit agent state
        setState('lastAnalysis', stats);
        return stats;
      },
    );
  }
}

Future<void> main() async {
  print('=== mobi-nooa: DataScientistAgent Demo ===');

  final heap = ObjectHeap();
  final harness = HarnessApi();
  final tracer = Tracer('DataScientistDemo');
  final model = MockModelClient();

  final agent = DataScientistAgent();
  final context = AgentContext(
    heap: heap,
    model: model,
    harness: harness,
    tracer: tracer,
  );
  agent.attachContext(context);

  // Step 1: Model calls generateSyntheticDataset(count: 5000)
  model.queueToolCall(
    toolName: 'generateSyntheticDataset',
    arguments: {'count': 5000},
    thought: 'I will generate 5000 synthetic records.',
  );

  // Step 2: Model calls calculateStats(dataHandle: '#ref_1', column: 'score')
  model.queueToolCall(
    toolName: 'calculateStats',
    arguments: {'dataHandle': '#ref_1', 'column': 'score'},
    thought: 'Now analyzing score stats by referencing #ref_1 directly.',
  );

  // Step 3: Model returns final conclusion
  model.queueText('Successfully analyzed 5000 records. Mean score is around 50.');

  print('Running agent loop...');
  final result = await agent.ellipsis<String>(
    'Generate 5000 records and compute score statistics.',
  );

  print('\nResult:\n$result');
  print('\nAgent Explicit State:\n${agent.getStateSnapshot()}');
  print('\nObject Heap Table:\n${heap.toPromptSummary()}');
}
