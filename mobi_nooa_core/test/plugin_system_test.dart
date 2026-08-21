import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class CustomTestPlugin extends AgentPlugin {
  bool initialized = false;
  bool disposed = false;
  final List<String> hookCalls = [];

  CustomTestPlugin()
      : super(
          name: 'test_plugin',
          version: '1.0.0',
          description: 'A test plugin for validation',
        );

  @override
  Future<void> initialize(PluginContext context) async {
    initialized = true;
    hookCalls.add('initialize');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    hookCalls.add('dispose');
  }

  @override
  Future<void> onBeforeStep(int stepIndex, List<ModelMessage> messages) async {
    hookCalls.add('beforeStep_$stepIndex');
  }

  @override
  Future<void> onBeforeToolExecution(String toolName, Map<String, dynamic> arguments) async {
    hookCalls.add('beforeTool_$toolName');
  }

  @override
  List<ActionMetadata> get providedActions => [
        ActionMetadata(
          name: 'pluginCustomAction',
          description: 'An action provided dynamically by plugin',
          parameters: const [],
          invoker: (args) async => 'PluginActionResult: 42',
        ),
      ];
}

void main() {
  group('Plugin Architecture & Service Seam (TDD)', () {
    test('PluginRegistry registers, initializes, and collects provided actions', () async {
      final registry = PluginRegistry();
      final plugin = CustomTestPlugin();

      registry.register(plugin);
      expect(registry.plugins.length, equals(1));
      expect(registry.getPlugin('test_plugin'), equals(plugin));

      final agent = GeneralMobileAgent();
      final mockModel = MockModelClient();
      final context = AgentContext(
        heap: ObjectHeap(),
        model: mockModel,
        harness: HarnessApi(),
        tracer: Tracer('TestAgent'),
      );

      final pluginContext = PluginContext(
        agent: agent,
        agentContext: context,
      );

      await registry.initializeAll(pluginContext);
      expect(plugin.initialized, isTrue);
      expect(plugin.hookCalls, contains('initialize'));

      final actions = registry.collectActions();
      expect(actions.length, equals(1));
      expect(actions.first.name, equals('pluginCustomAction'));

      final result = await actions.first.invoker({});
      expect(result, equals('PluginActionResult: 42'));

      await registry.disposeAll();
      expect(plugin.disposed, isTrue);
    });

    test('DynamicToolPlugin registers dynamic tool functions at runtime', () async {
      final dynamicPlugin = DynamicToolPlugin(name: 'math_tools');
      dynamicPlugin.registerAction(
        name: 'computeFactorial',
        description: 'Computes factorial of n',
        parameters: const [
          ToolParameter(name: 'n', type: 'integer', description: 'Number'),
        ],
        invoker: (args) async {
          final n = (args['n'] as num).toInt();
          int fact = 1;
          for (int i = 1; i <= n; i++) {
            fact *= i;
          }
          return fact;
        },
      );

      expect(dynamicPlugin.providedActions.length, equals(1));
      expect(dynamicPlugin.providedActions.first.name, equals('computeFactorial'));

      final res = await dynamicPlugin.providedActions.first.invoker({'n': 5});
      expect(res, equals(120));
    });

    test('TelemetryLoggerPlugin captures structured events', () async {
      final telemetryPlugin = TelemetryLoggerPlugin();
      final registry = PluginRegistry()..register(telemetryPlugin);

      final agent = GeneralMobileAgent();
      final context = AgentContext(
        heap: ObjectHeap(),
        model: MockModelClient(),
        harness: HarnessApi(),
        tracer: Tracer('TestAgent'),
      );

      await registry.initializeAll(PluginContext(agent: agent, agentContext: context));
      await registry.dispatchBeforeStep(1, [ModelMessage.user('Test task')]);
      await registry.dispatchBeforeToolExecution('getDeviceInfo', {});
      await registry.dispatchAfterToolExecution('getDeviceInfo', {}, '{"model": "Pixel 9 Pro"}');
      await registry.dispatchAfterStep(1, ModelResponse(text: 'Done'));

      expect(telemetryPlugin.records.length, equals(4));
      expect(telemetryPlugin.records[0]['event'], equals('beforeStep'));
      expect(telemetryPlugin.records[1]['event'], equals('beforeToolExecution'));
      expect(telemetryPlugin.records[2]['event'], equals('afterToolExecution'));
      expect(telemetryPlugin.records[3]['event'], equals('afterStep'));
    });
  });
}
