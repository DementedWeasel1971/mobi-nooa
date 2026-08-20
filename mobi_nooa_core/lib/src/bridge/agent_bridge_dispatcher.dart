import 'dart:async';
import '../agent/nooa_agent.dart';
import '../agent/general_mobile_agent.dart';
import '../agent/bench_agent.dart';
import '../agent/autonomous_device_agent.dart';
import '../agent/data_analyst_agent.dart';
import '../agent/autonomous_coding_agent.dart';
import '../models/model_client.dart';
import '../models/mock_client.dart';
import '../models/gemini_client.dart';
import '../models/openai_client.dart';
import '../models/anthropic_client.dart';
import '../models/ollama_client.dart';
import '../models/on_device_client.dart';
import '../util/quickstart.dart';

import '../harness/harness_api.dart';
import '../harness/device_harness.dart';

/// Factory for constructing a fresh [NooaAgent] instance by name.
typedef AgentFactory = NooaAgent Function();

/// Factory for constructing a [ModelClient] from a JSON-decoded config map
/// (e.g. `{"provider": "gemini", "apiKey": "..."}`).
typedef ModelClientFactory = ModelClient Function(Map<String, dynamic> config);

/// Transport-agnostic request/response dispatcher for driving mobi-nooa
/// agents from a host platform (Android/Kotlin, iOS/Swift, a CLI, or a test
/// harness) over a plain JSON-serializable message protocol.
///
/// This class deliberately has **no Flutter/platform-channel dependency** —
/// it is pure Dart, so it stays inside `mobi_nooa_core` without violating
/// the "no Flutter/dart:ui in core" invariant (see `DESIGN.md`). A thin
/// platform-specific shim (e.g. a Flutter `MethodChannel` handler, or an
/// HTTP/stdio server) is expected to decode incoming messages into a
/// `Map<String, dynamic>`, call [handle], and re-encode the response.
///
/// Supported actions (`request['action']`):
/// - `'listAgents'` → `{'agents': [...]}`
/// - `'runAgentLoop'` → runs `agent.ellipsis(goal, ...)` to completion and
///   returns `{'result': ..., 'trace': [...]}` or `{'error': ...}`.
/// - `'getDeviceStatus'` → returns `{'status': {...}}`
/// - `'sendNotification'` → emits system notification via device harness
/// - `'vibrate'` → triggers device haptic vibration
class AgentBridgeDispatcher {
  final Map<String, AgentFactory> _agentFactories = {};
  final Map<String, ModelClientFactory> _modelFactories = {};
  DeviceHarness? deviceHarness;

  AgentBridgeDispatcher({
    DeviceHarness? deviceHarness,
    NativeDeviceBridge? deviceBridge,
  }) : deviceHarness = deviceHarness ??
            (deviceBridge != null
                ? NativeBridgeDeviceHarness(deviceBridge)
                : null);

  /// Registers an agent constructor under [name], callable from the bridge
  /// via `{"action": "runAgentLoop", "agentName": name, ...}`.
  void registerAgent(String name, AgentFactory factory) {
    _agentFactories[name] = factory;
  }

  /// Registers a model provider constructor under [providerName], callable
  /// via `request['model'] = {"provider": providerName, ...config}`.
  void registerModelProvider(String providerName, ModelClientFactory factory) {
    _modelFactories[providerName] = factory;
  }

  /// Names of all agents currently registered on this dispatcher.
  List<String> get registeredAgentNames => _agentFactories.keys.toList();

  /// Convenience constructor pre-registering the reference agents
  /// (`GeneralMobileAgent`, `BenchAgent`) and known model providers
  /// (`gemini`, `openai`, `anthropic`, `ollama`, `on_device`, `mock`).
  factory AgentBridgeDispatcher.withDefaults({
    DeviceHarness? deviceHarness,
    NativeDeviceBridge? deviceBridge,
  }) {
    final dispatcher = AgentBridgeDispatcher(
      deviceHarness: deviceHarness,
      deviceBridge: deviceBridge,
    );

    dispatcher.registerAgent('GeneralMobileAgent', () => GeneralMobileAgent());
    dispatcher.registerAgent('BenchAgent', () => BenchAgent());
    dispatcher.registerAgent('AutonomousDeviceAgent', () => AutonomousDeviceAgent());
    dispatcher.registerAgent('DataAnalystAgent', () => DataAnalystAgent());
    dispatcher.registerAgent('AutonomousCodingAgent', () => AutonomousCodingAgent());

    dispatcher.registerModelProvider('mock', (config) => MockModelClient());
    dispatcher.registerModelProvider(
      'gemini',
      (config) => GeminiClient(apiKey: config['apiKey'] as String? ?? ''),
    );
    dispatcher.registerModelProvider(
      'openai',
      (config) => OpenAIClient(apiKey: config['apiKey'] as String? ?? ''),
    );
    dispatcher.registerModelProvider(
      'anthropic',
      (config) => AnthropicClient(apiKey: config['apiKey'] as String? ?? ''),
    );
    dispatcher.registerModelProvider(
      'ollama',
      (config) => OllamaClient(
        modelName: config['modelName'] as String? ?? 'llama3.2',
        baseUrl: config['baseUrl'] as String? ?? 'http://localhost:11434',
      ),
    );
    dispatcher.registerModelProvider(
      'on_device',
      (config) {
        final templateName = config['template'] as String? ?? 'llama3';
        PromptTemplate template;
        switch (templateName.toLowerCase()) {
          case 'chatml':
            template = PromptTemplate.chatMl;
            break;
          case 'gemma':
            template = PromptTemplate.gemma;
            break;
          case 'raw':
            template = PromptTemplate.raw;
            break;
          case 'llama3':
          default:
            template = PromptTemplate.llama3;
            break;
        }
        return OnDeviceModelClient(
          modelName: config['modelName'] as String? ?? 'on-device-mobile-llm',
          template: template,
        );
      },
    );

    return dispatcher;
  }

  /// Handles one decoded JSON request and returns a JSON-serializable
  /// response map. Never throws — all errors are captured into
  /// `{'error': ..., 'stack': ...}` so a platform bridge can always encode
  /// a response back to the caller.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> request) async {
    try {
      final action = request['action'] as String?;
      switch (action) {
        case 'listAgents':
          return {'agents': registeredAgentNames};
        case 'runAgentLoop':
          return await _runAgentLoop(request);
        case 'getDeviceStatus':
          final targetDevice = deviceHarness ?? DefaultDeviceHarness();
          final status = await targetDevice.getStatus();
          return {'status': status.toJson()};
        case 'sendNotification':
          final targetDevice = deviceHarness ?? DefaultDeviceHarness();
          final title = request['title'] as String? ?? '';
          final body = request['body'] as String? ?? '';
          final id = (request['id'] as num?)?.toInt();
          await targetDevice.sendNotification(title: title, body: body, id: id);
          return {'success': true};
        case 'vibrate':
          final targetDevice = deviceHarness ?? DefaultDeviceHarness();
          final durationMs = (request['durationMs'] as num?)?.toInt() ?? 200;
          await targetDevice.vibrate(durationMs: durationMs);
          return {'success': true};
        default:
          return {'error': 'Unknown or missing action: $action'};
      }
    } catch (e, stack) {
      return {'error': e.toString(), 'stack': stack.toString()};
    }
  }

  Future<Map<String, dynamic>> _runAgentLoop(
    Map<String, dynamic> request,
  ) async {
    final agentName = request['agentName'] as String? ?? 'GeneralMobileAgent';
    final factory = _agentFactories[agentName];
    if (factory == null) {
      return {
        'error':
            'Unknown agent "$agentName". Registered agents: $registeredAgentNames',
      };
    }

    final goal = request['goal'] as String? ?? '';
    final inputs = Map<String, dynamic>.from(
      (request['inputs'] as Map?) ?? {},
    );
    final maxSteps = (request['maxSteps'] as num?)?.toInt() ?? 10;

    final modelConfig = Map<String, dynamic>.from(
      (request['model'] as Map?) ?? {},
    );
    final providerName = modelConfig['provider'] as String? ?? 'mock';
    final modelFactory = _modelFactories[providerName];
    final model = modelFactory != null
        ? modelFactory(modelConfig)
        : MockModelClient();

    final harness = HarnessApi(
      device: deviceHarness ?? DefaultDeviceHarness(),
    );

    final agent = Quickstart.createAgent(
      factory,
      model: model,
      harness: harness,
    );

    try {
      final result = await agent.ellipsis<dynamic>(
        goal,
        inputs: inputs,
        maxSteps: maxSteps,
      );

      return {
        'result': result,
        'agentName': agent.name,
        'trace': agent.context.tracer.events.map((e) => e.toJson()).toList(),
      };
    } catch (e, stack) {
      return {
        'error': e.toString(),
        'stack': stack.toString(),
        'trace': agent.context.tracer.events.map((e) => e.toJson()).toList(),
      };
    } finally {
      agent.dispose();
    }
  }
}

