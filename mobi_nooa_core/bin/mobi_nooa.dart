import 'dart:io';
import 'package:args/args.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';
import '../example/data_scientist_agent.dart' as data_demo;
import '../example/mobile_assistant_agent.dart' as assistant_demo;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('demo', abbr: 'd', help: 'Run demo: data_analysis | mobile_assistant | code_act')
    ..addOption('model', abbr: 'm', defaultsTo: 'mock', help: 'Model backend: mock | gemini | openai | ollama')
    ..addOption('api-key', abbr: 'k', help: 'API Key for remote models')
    ..addFlag('trace', abbr: 't', defaultsTo: false, help: 'Print full JSONL trace at finish')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final results = parser.parse(arguments);

  if (results['help'] as bool) {
    print('mobi-nooa: Mobile Object-Oriented Agent Harness CLI\n');
    print(parser.usage);
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

  if (modelType == 'gemini') {
    final apiKey = results['api-key'] as String? ?? Platform.environment['GEMINI_API_KEY'];
    if (apiKey == null) {
      print('Error: GEMINI_API_KEY is required for Gemini model.');
      exit(1);
    }
    model = GeminiClient(apiKey: apiKey);
  } else if (modelType == 'openai') {
    final apiKey = results['api-key'] as String? ?? Platform.environment['OPENAI_API_KEY'];
    if (apiKey == null) {
      print('Error: OPENAI_API_KEY is required for OpenAI model.');
      exit(1);
    }
    model = OpenAIClient(apiKey: apiKey);
  } else {
    model = MockModelClient();
    (model as MockModelClient).queueText('Hello! mobi-nooa harness is ready to execute agents on this device.');
  }

  final agent = DefaultGeneralAgent();
  final context = AgentContext(
    heap: heap,
    model: model,
    harness: harness,
    tracer: tracer,
  );
  agent.attachContext(context);

  print('Agent initialized: ${agent.name}');
  print('Actions: ${agent.declaredActions.map((a) => a.name).join(', ')}');

  final result = await agent.ellipsis<String>('Say hello and report harness status.');
  print('\nResponse:\n$result');

  if (results['trace'] as bool) {
    print('\n=== Tracing JSONL ===');
    print(tracer.exportJsonL());
  }
}

class DefaultGeneralAgent extends NooaAgent {
  DefaultGeneralAgent()
      : super(
          name: 'GeneralMobiAgent',
          role: 'General Purpose Android Agent',
          description: 'General purpose agent executing tools and CodeAct on mobile device.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'getDeviceInfo',
      description: 'Retrieves live battery, network, and storage telemetry.',
      invoker: (args) async {
        final status = await context.harness.device.getStatus();
        return status.toJson();
      },
    );
  }
}
