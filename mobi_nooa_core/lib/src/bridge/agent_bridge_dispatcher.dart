import 'dart:async';
import '../agent/nooa_agent.dart';
import '../agent/general_mobile_agent.dart';
import '../agent/bench_agent.dart';
import '../agent/autonomous_device_agent.dart';
import '../agent/data_analyst_agent.dart';
import '../agent/autonomous_coding_agent.dart';
import '../agent/operating_mode.dart';
import '../models/model_client.dart';
import '../models/mock_client.dart';
import '../models/gemini_client.dart';
import '../models/openai_client.dart';
import '../models/anthropic_client.dart';
import '../models/ollama_client.dart';
import '../models/on_device_client.dart';
import '../models/nvidia_client.dart';
import '../models/deepseek_client.dart';
import '../models/fallback_cascade_client.dart';
import '../util/quickstart.dart';

import '../harness/harness_api.dart';
import '../harness/device_harness.dart';
import '../harness/sqlite_harness.dart';
import '../storage/agent_checkpoint.dart';
import '../storage/state_storage_manager.dart';
import '../security/permission_policy.dart';
import '../security/permission_manager.dart';
import '../plugin/plugin_registry.dart';
import '../session/session_event_log.dart';

/// Factory for constructing a fresh [NooaAgent] instance by name.
typedef AgentFactory = NooaAgent Function();

/// Factory for constructing a [ModelClient] from a JSON-decoded config map
/// (e.g. `{"provider": "gemini", "apiKey": "..."}`).
typedef ModelClientFactory = ModelClient Function(Map<String, dynamic> config);

/// Transport-agnostic request/response dispatcher for driving mobi-nooa
/// agents from a host platform (Android/Kotlin, iOS/Swift, a CLI, or a test
/// harness) over a plain JSON-serializable message protocol.
class AgentBridgeDispatcher {
  final Map<String, AgentFactory> _agentFactories = {};
  final Map<String, ModelClientFactory> _modelFactories = {};
  final Map<String, SessionEventLog> _sessions = {};
  final PluginRegistry pluginRegistry;
  PermissionManager permissionManager;
  DeviceHarness? deviceHarness;
  final StateStorageManager storage;

  AgentBridgeDispatcher({
    DeviceHarness? deviceHarness,
    NativeDeviceBridge? deviceBridge,
    StateStorageManager? storage,
    PermissionManager? permissionManager,
    PluginRegistry? pluginRegistry,
  })  : deviceHarness = deviceHarness ??
            (deviceBridge != null
                ? NativeBridgeDeviceHarness(deviceBridge)
                : null),
        storage = storage ?? StateStorageManager(sqlite: InMemorySqliteHarness()),
        permissionManager = permissionManager ?? PermissionManager(),
        pluginRegistry = pluginRegistry ?? PluginRegistry();

  /// Registers an agent constructor under [name].
  void registerAgent(String name, AgentFactory factory) {
    _agentFactories[name] = factory;
  }

  /// Registers a model provider constructor under [providerName].
  void registerModelProvider(String providerName, ModelClientFactory factory) {
    _modelFactories[providerName] = factory;
  }

  /// Names of all agents currently registered on this dispatcher.
  List<String> get registeredAgentNames => _agentFactories.keys.toList();

  /// Convenience constructor pre-registering the reference agents
  /// and model providers (including DeepSeek and Nvidia).
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
    dispatcher.registerModelProvider(
      'nvidia',
      (config) => NvidiaClient(
        apiKey: config['apiKey'] as String? ?? '',
        modelName: config['modelName'] as String? ?? 'meta/llama-3.3-70b-instruct',
        baseUrl: config['baseUrl'] as String? ?? 'https://integrate.api.nvidia.com/v1',
      ),
    );
    dispatcher.registerModelProvider(
      'deepseek',
      (config) => DeepSeekClient(
        apiKey: config['apiKey'] as String? ?? '',
        modelName: config['modelName'] as String? ?? 'deepseek-chat',
        baseUrl: config['baseUrl'] as String? ?? 'https://api.deepseek.com',
      ),
    );
    dispatcher.registerModelProvider(
      'cascade',
      (config) {
        final rawCascade = (config['cascade'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .map((cfg) {
              final pName = cfg['provider'] as String? ?? 'mock';
              final f = dispatcher._modelFactories[pName];
              return f != null ? f(cfg) : MockModelClient();
            })
            .toList();
        final timeoutSec = (config['providerTimeoutSeconds'] as num?)?.toInt() ?? 25;
        final retries = (config['maxRetriesPerProvider'] as num?)?.toInt() ?? 1;
        return FallbackCascadeClient(
          cascade: rawCascade.isNotEmpty ? rawCascade : [MockModelClient()],
          providerTimeout: Duration(seconds: timeoutSec),
          maxRetriesPerProvider: retries,
        );
      },
    );

    return dispatcher;
  }

  /// Handles one decoded JSON request and returns a JSON-serializable response map.
  Future<Map<String, dynamic>> handle(Map<String, dynamic> request) async {
    try {
      final action = request['action'] as String?;
      switch (action) {
        case 'listAgents':
          return {'agents': registeredAgentNames};
        case 'listModelProviders':
          return {'providers': _modelFactories.keys.toList()};
        case 'listModels':
          final provider = request['provider'] as String? ?? 'nvidia';
          final apiKey = request['apiKey'] as String? ?? '';
          final baseUrl = request['baseUrl'] as String? ?? 'https://integrate.api.nvidia.com/v1';
          if (provider == 'nvidia') {
            final models = await NvidiaClient.fetchModels(apiKey: apiKey, baseUrl: baseUrl);
            return {'models': models};
          }
          return {'models': []};
        case 'runAgentLoop':
          return await _runAgentLoop(request);
        case 'createSession':
          final sessionId = request['sessionId'] as String? ??
              'session_${DateTime.now().millisecondsSinceEpoch}';
          final sessionLog = SessionEventLog(sessionId: sessionId);
          _sessions[sessionId] = sessionLog;
          return {'sessionId': sessionId, 'created': true};
        case 'replaySession':
          final sessionId = request['sessionId'] as String?;
          if (sessionId == null || !_sessions.containsKey(sessionId)) {
            return {'error': 'Session not found: $sessionId'};
          }
          final toStep = (request['toStepIndex'] as num?)?.toInt() ?? 999;
          final replay = _sessions[sessionId]!.replay(toStep);
          return {
            'sessionId': sessionId,
            'stepIndex': replay.stepIndex,
            'state': replay.state,
            'eventCount': replay.eventHistory.length,
          };
        case 'forkSession':
          final sourceId = request['sourceSessionId'] as String?;
          final newSessionId = request['newSessionId'] as String? ??
              'fork_${DateTime.now().millisecondsSinceEpoch}';
          if (sourceId == null || !_sessions.containsKey(sourceId)) {
            return {'error': 'Source session not found: $sourceId'};
          }
          final fromStep = (request['fromStepIndex'] as num?)?.toInt();
          final forked = _sessions[sourceId]!.fork(
            newSessionId: newSessionId,
            fromStepIndex: fromStep,
          );
          _sessions[newSessionId] = forked;
          return {
            'newSessionId': newSessionId,
            'eventCount': forked.events.length,
          };
        case 'listPlugins':
          return {
            'plugins': pluginRegistry.plugins.map((p) => {
                  'name': p.name,
                  'version': p.version,
                  'description': p.description,
                  'enabled': p.isEnabled,
                }).toList(),
          };
        case 'setPermissionPolicy':
          final policyName = request['policy'] as String? ?? 'defaultMobile';
          if (policyName == 'strictAudit') {
            permissionManager = PermissionManager(policy: PermissionPolicy.strictAudit());
          } else if (policyName == 'permissive') {
            permissionManager = PermissionManager(policy: PermissionPolicy.permissive());
          } else {
            permissionManager = PermissionManager(policy: PermissionPolicy.defaultMobile());
          }
          return {'success': true, 'policy': policyName};
        case 'saveCheckpoint':
          final checkpointJson = request['checkpoint'] as Map<String, dynamic>?;
          if (checkpointJson == null) return {'error': 'Missing checkpoint payload'};
          await storage.initialize();
          final checkpoint = AgentCheckpoint.fromJson(checkpointJson);
          await storage.saveCheckpoint(checkpoint);
          return {'success': true, 'checkpointId': checkpoint.checkpointId};
        case 'getLatestCheckpoint':
          final agentName = request['agentName'] as String?;
          if (agentName == null) return {'error': 'Missing agentName'};
          await storage.initialize();
          final checkpoint = await storage.getLatestCheckpoint(agentName);
          return {'checkpoint': checkpoint?.toJson()};
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

    // Optional session logging
    SessionEventLog? sessionLog;
    final sessionId = request['sessionId'] as String?;
    if (sessionId != null) {
      sessionLog = _sessions.putIfAbsent(sessionId, () => SessionEventLog(sessionId: sessionId));
    }

    final modelConfig = Map<String, dynamic>.from(
      (request['model'] as Map?) ?? {},
    );
    ModelClient model;
    if (modelConfig.containsKey('cascade') && modelConfig['cascade'] is List) {
      final rawCascade = (modelConfig['cascade'] as List)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .map((cfg) {
            final pName = cfg['provider'] as String? ?? 'mock';
            final f = _modelFactories[pName];
            return f != null ? f(cfg) : MockModelClient();
          })
          .toList();
      final timeoutSec = (modelConfig['providerTimeoutSeconds'] as num?)?.toInt() ?? 25;
      final retries = (modelConfig['maxRetriesPerProvider'] as num?)?.toInt() ?? 1;
      model = FallbackCascadeClient(
        cascade: rawCascade.isNotEmpty ? rawCascade : [MockModelClient()],
        providerTimeout: Duration(seconds: timeoutSec),
        maxRetriesPerProvider: retries,
        sessionLog: sessionLog,
      );
    } else {
      final providerName = modelConfig['provider'] as String? ?? 'mock';
      final modelFactory = _modelFactories[providerName];
      model = modelFactory != null
          ? modelFactory(modelConfig)
          : MockModelClient();
    }

    final modeName = request['operatingMode'] as String? ?? 'autonomous';
    final operatingMode = AgentOperatingMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => AgentOperatingMode.autonomous,
    );

    final harness = HarnessApi(
      device: deviceHarness ?? DefaultDeviceHarness(),
    );

    final agent = Quickstart.createAgent(
      factory,
      model: model,
      harness: harness,
      permissionManager: permissionManager,
      plugins: pluginRegistry,
      sessionLog: sessionLog,
      operatingMode: operatingMode,
    );

    if (request.containsKey('initialState') && request['initialState'] is Map) {
      final initialState = Map<String, dynamic>.from(request['initialState'] as Map);
      agent.restoreState(initialState);
    }

    try {
      final result = await agent.ellipsis<dynamic>(
        goal,
        inputs: inputs,
        maxSteps: maxSteps,
      );

      return {
        'result': result,
        'agentName': agent.name,
        'state': agent.getStateSnapshot(),
        'heapHandles': agent.context.heap.handles,
        'trace': agent.context.tracer.events.map((e) => e.toJson()).toList(),
        if (sessionLog != null) 'sessionEventCount': sessionLog.events.length,
      };
    } catch (e, stack) {
      return {
        'error': e.toString(),
        'stack': stack.toString(),
        'state': agent.getStateSnapshot(),
        'heapHandles': agent.context.heap.handles,
        'trace': agent.context.tracer.events.map((e) => e.toJson()).toList(),
      };
    } finally {
      agent.dispose();
    }
  }
}
