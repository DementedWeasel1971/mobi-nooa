import 'dart:io';
import 'package:args/args.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';
import '../example/data_scientist_agent.dart' as data_demo;
import '../example/mobile_assistant_agent.dart' as assistant_demo;

Map<String, String> _loadEnv() {
  final env = <String, String>{};
  for (final path in ['.env', '../.env', 'mobi_nooa_core/.env']) {
    final file = File(path);
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx != -1) {
          final key = trimmed.substring(0, eqIdx).trim();
          final val = trimmed.substring(eqIdx + 1).trim();
          env[key] = val;
        }
      }
      break;
    }
  }
  return env;
}

void main(List<String> arguments) async {
  final env = _loadEnv();

  final parser = ArgParser()
    ..addOption('demo', abbr: 'd', help: 'Run demo: data_analysis | mobile_assistant | code_act')
    ..addOption('agent', abbr: 'a', defaultsTo: 'device', help: 'Agent type: device | analyst | coding | general')
    ..addOption('model', abbr: 'm', defaultsTo: 'nvidia', help: 'Model backend: nvidia | gemini | openai | mock')
    ..addOption('prompt', abbr: 'p', help: 'Custom prompt or goal to ask the agent')
    ..addOption('api-key', abbr: 'k', help: 'API Key for remote models')
    ..addFlag('list-models', abbr: 'l', defaultsTo: false, help: 'Query and list all available models from the provider')
    ..addOption('filter', abbr: 'f', help: 'Filter substring when listing models')
    ..addFlag('trace', abbr: 't', defaultsTo: false, help: 'Print full JSONL trace at finish')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    print('mobi-nooa: Mobile Object-Oriented Agent Harness CLI\n');
    print(parser.usage);
    return;
  }

  if (results['list-models'] as bool) {
    final apiKey = results['api-key'] as String? ?? env['NVIDIA_API_KEY'] ?? Platform.environment['NVIDIA_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Error: NVIDIA_API_KEY is required to list available models.');
      exit(1);
    }
    final baseUrl = env['NVIDIA_BASE_URL'] ?? 'https://integrate.api.nvidia.com/v1';
    final filter = (results['filter'] as String?)?.toLowerCase();

    print('Fetching available models from $baseUrl...');
    final models = await NvidiaClient.fetchModels(apiKey: apiKey, baseUrl: baseUrl);
    final filtered = filter != null && filter.isNotEmpty
        ? models.where((m) => m.toLowerCase().contains(filter)).toList()
        : models;

    print('\n=== Available Models (${filtered.length}/${models.length} total) ===');
    for (final m in filtered) {
      print('  • $m');
    }
    return;
  }

  final demo = results['demo'] as String?;

  if (demo == 'data_analysis') {
    await data_demo.main();
    return;
  } else if (demo == 'mobile_assistant') {
    await assistant_demo.main();
    return;
  }

  print('=== mobi-nooa Mobile Agent Interactive CLI ===');
  print('Running on modern mobile runtime (Dart SDK ${Platform.version.split(' ').first})');
  print('Faithful implementation of NVIDIA Object-Oriented Agents (NOOA)\n');

  final heap = ObjectHeap();
  final harness = HarnessApi();
  final tracer = Tracer('InteractiveCLI');

  ModelClient model;
  final modelType = results['model'] as String;

  if (modelType == 'nvidia') {
    final apiKey = results['api-key'] as String? ?? env['NVIDIA_API_KEY'] ?? Platform.environment['NVIDIA_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Warning: NVIDIA_API_KEY not found in .env or arguments. Falling back to MockModelClient.');
      model = MockModelClient();
      (model as MockModelClient).queueText('Hello! mobi-nooa harness is ready to execute agents on this device.');
    } else {
      model = NvidiaClient(
        apiKey: apiKey,
        baseUrl: env['NVIDIA_BASE_URL'] ?? 'https://integrate.api.nvidia.com/v1',
        modelName: env['NVIDIA_MODEL'] ?? 'meta/llama-3.3-70b-instruct',
      );
      print('Connected to NVIDIA NIM Model: ${model.modelName}');
    }
  } else if (modelType == 'gemini') {
    final apiKey = results['api-key'] as String? ?? env['GEMINI_API_KEY'] ?? Platform.environment['GEMINI_API_KEY'];
    if (apiKey == null) {
      print('Error: GEMINI_API_KEY is required for Gemini model.');
      exit(1);
    }
    model = GeminiClient(apiKey: apiKey);
  } else if (modelType == 'openai') {
    final apiKey = results['api-key'] as String? ?? env['OPENAI_API_KEY'] ?? Platform.environment['OPENAI_API_KEY'];
    if (apiKey == null) {
      print('Error: OPENAI_API_KEY is required for OpenAI model.');
      exit(1);
    }
    model = OpenAIClient(apiKey: apiKey);
  } else {
    model = MockModelClient();
    (model as MockModelClient).queueText('Hello! mobi-nooa harness is ready to execute agents on this device.');
  }

  final agentType = results['agent'] as String;
  NooaAgent agent;
  switch (agentType) {
    case 'analyst':
      agent = DataAnalystAgent();
      break;
    case 'coding':
      agent = AutonomousCodingAgent();
      break;
    case 'general':
      agent = GeneralMobileAgent();
      break;
    case 'device':
    default:
      agent = AutonomousDeviceAgent();
      break;
  }

  final context = AgentContext(
    heap: heap,
    model: model,
    harness: harness,
    tracer: tracer,
  );
  agent.attachContext(context);

  print('Agent initialized: ${agent.name} (${agent.role})');
  print('Declared Actions (${agent.declaredActions.length}): ${agent.declaredActions.map((a) => a.name).join(', ')}');

  final prompt = results['prompt'] as String? ?? 'Introduce yourself, check device telemetry, and report your capabilities.';
  print('\n>>> User Prompt: "$prompt"\n');

  final stopwatch = Stopwatch()..start();
  final result = await agent.ellipsis<String>(prompt, maxSteps: 10);
  stopwatch.stop();

  print('<<< Agent Response (${stopwatch.elapsedMilliseconds}ms):\n$result\n');
  print('Agent Explicit State: ${agent.getStateSnapshot()}');

  if (results['trace'] as bool) {
    print('\n=== Tracing JSONL ===');
    print(tracer.exportJsonL());
  }
}
