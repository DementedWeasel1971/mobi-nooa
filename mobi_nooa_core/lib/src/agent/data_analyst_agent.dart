import 'nooa_agent.dart';
import '../models/model_client.dart';

/// Autonomous on-device data analytics and tabular reasoning agent.
///
/// Implements NOOA Principle 2 (Pass-by-Reference Object Heap) to handle large
/// datasets without LLM prompt context bloat, alongside SQLite data queries.
class DataAnalystAgent extends NooaAgent {
  DataAnalystAgent({
    String? name,
    String? role,
    String? description,
  }) : super(
          name: name ?? 'DataAnalystAgent',
          role: role ?? 'On-Device Data Analyst Agent',
          description: description ??
              'Performs tabular data analysis, statistics, and SQLite queries using pass-by-reference object handles.',
          customPromptInstructions:
              'Datasets are referenced by handle (#ref_xxx). Never ask to dump full datasets; '
              'invoke computeSummary or filterDataset using their object reference handles.',
        );

  @override
  void initAgent() {
    setState('active_handles', <String>[]);
    setState('query_history', <String>[]);

    registerAction(
      name: 'loadSampleDataset',
      description: 'Generates a synthetic telemetry dataset of N rows into the ObjectHeap and returns its #ref handle.',
      parameters: const [
        ToolParameter(
          name: 'rowCount',
          type: 'integer',
          description: 'Number of rows to generate (default: 100)',
          required: false,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final count = (args['rowCount'] as num?)?.toInt() ?? 100;
        final rows = List.generate(count, (i) => {
              'id': i + 1,
              'cpu_usage': (15 + (i * 7) % 80).toDouble(),
              'ram_mb': 1200 + (i * 23) % 1800,
              'battery_pct': (100 - (i * 0.5)).clamp(5.0, 100.0),
              'network': i % 3 == 0 ? 'wifi' : 'cellular',
            });

        final ref = context.heap.put(
          rows,
          label: 'Dataset ($count rows)',
        );

        final active = List<String>.from(getState('active_handles') as List? ?? [])..add(ref.handle);
        setState('active_handles', active);

        return ref.handle;
      },
    );

    registerAction(
      name: 'computeSummary',
      description: 'Computes statistical aggregates (row count, mean cpu, mean ram) for a dataset handle (#ref_xxx).',
      parameters: const [
        ToolParameter(
          name: 'handle',
          type: 'string',
          description: 'Object reference handle (e.g. "#ref_1")',
          required: true,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final handle = args['handle'] as String;
        final data = context.heap.resolveHandleOrValue(handle);

        if (data is! List) {
          return {'error': 'Handle $handle does not contain a list of rows.'};
        }

        final rows = data.whereType<Map>().toList();
        final count = rows.length;
        if (count == 0) return {'rowCount': 0};

        double totalCpu = 0.0;
        double totalRam = 0.0;
        for (final r in rows) {
          totalCpu += (r['cpu_usage'] as num?)?.toDouble() ?? 0.0;
          totalRam += (r['ram_mb'] as num?)?.toDouble() ?? 0.0;
        }

        return {
          'handle': handle,
          'rowCount': count,
          'avgCpu': (totalCpu / count).toStringAsFixed(2),
          'avgRamMb': (totalRam / count).toStringAsFixed(2),
        };
      },
    );

    registerAction(
      name: 'filterDataset',
      description: 'Filters rows in a dataset handle where column equals a target value, returning a new #ref handle.',
      parameters: const [
        ToolParameter(
          name: 'handle',
          type: 'string',
          description: 'Source dataset object handle',
          required: true,
        ),
        ToolParameter(
          name: 'column',
          type: 'string',
          description: 'Column name to filter on (e.g. "network")',
          required: true,
        ),
        ToolParameter(
          name: 'value',
          type: 'string',
          description: 'Target value to match',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final handle = args['handle'] as String;
        final col = args['column'] as String;
        final val = args['value'] as String;

        final data = context.heap.resolveHandleOrValue(handle);
        if (data is! List) {
          return 'Error: Handle $handle is not a list';
        }

        final filtered = data
            .whereType<Map>()
            .where((r) => r[col]?.toString() == val)
            .toList();

        final ref = context.heap.put(
          filtered,
          label: 'Filtered ($col == $val, ${filtered.length} rows)',
        );

        final active = List<String>.from(getState('active_handles') as List? ?? [])..add(ref.handle);
        setState('active_handles', active);

        return ref.handle;
      },
    );

    registerAction(
      name: 'querySql',
      description: 'Executes a SQL query against the on-device SQLite database.',
      parameters: const [
        ToolParameter(
          name: 'sql',
          type: 'string',
          description: 'SQL statement (e.g. "SELECT * FROM metrics")',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final sql = args['sql'] as String;
        final history = List<String>.from(getState('query_history') as List? ?? [])..add(sql);
        setState('query_history', history);

        final result = await context.harness.sqlite.query(sql);
        return result.toString();
      },
    );
  }
}
