---
name: add-nooa-plugin
description: 'Create a new AgentPlugin in mobi_nooa_core following the DeepSeek Harness service seam architecture, with lifecycle hooks, dynamic tool injection, middleware interception, and telemetry collection.'
---

# Add a NOOA Agent Plugin

Use this skill when asked to create a new plugin in `mobi_nooa_core` (under `lib/src/plugin/` or custom application packages) to dynamically extend agent capabilities, intercept reasoning loops, enforce enterprise security policies, or stream custom telemetry.

Plugins in `mobi-nooa` implement the **"Everything is a Plugin" (Service Seam)** architectural pattern from DeepSeek Harness (`deepseek-ai/deepseek-harness`):
- **Lifecycle Management**: Plugins initialize with `PluginContext` (giving access to `agent`, `agentContext`, `heap`, `harness`, `tracer`, and `permissionManager`) and clean up via `dispose()`.
- **Dynamic Tool Injection**: Plugins can expose `List<ActionMetadata> get providedActions` to inject new tools into any host agent at runtime without modifying the agent class.
- **Middleware Hooks**: Intercept before/after LLM steps (`onBeforeStep`, `onAfterStep`), before/after tool execution (`onBeforeToolExecution`, `onAfterToolExecution`), on agent completion (`onAgentFinished`), or on error (`onError`).
- **Security Interception**: Validate arguments and enforce fine-grained constraints before tools execute.

---

## Reference implementations

- `mobi_nooa_core/lib/src/plugin/agent_plugin.dart` — base `AgentPlugin` contract
- `mobi_nooa_core/lib/src/plugin/plugin_registry.dart` — central plugin lifecycle & hook dispatcher
- `mobi_nooa_core/lib/src/plugin/plugin_context.dart` — runtime execution context provided to plugins
- `mobi_nooa_core/lib/src/plugin/built_in_plugins.dart` — reference implementations (`DynamicToolPlugin`, `TelemetryLoggerPlugin`, `AuditSecurityPlugin`)

---

## Step-by-Step Implementation Guide

### 1. File Placement
Place core library plugins in `mobi_nooa_core/lib/src/plugin/<plugin_name>_plugin.dart` and export them in `mobi_nooa_core/lib/mobi_nooa_core.dart`.

### 2. Implement `AgentPlugin` Subclass

```dart
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

class NetworkAuditorPlugin extends AgentPlugin {
  PluginContext? _context;
  final List<String> networkAuditLogs = [];

  NetworkAuditorPlugin({
    String name = 'network_auditor',
    String version = '1.0.0',
  }) : super(
          name: name,
          version: version,
          description: 'Audits network connectivity and logs external API calls.',
        );

  @override
  Future<void> initialize(PluginContext context) async {
    _context = context;
  }

  @override
  Future<void> dispose() async {
    networkAuditLogs.clear();
    _context = null;
  }

  /// 1. Inject custom tools into host agent
  @override
  List<ActionMetadata> get providedActions => [
        ActionMetadata(
          name: 'pingEndpoint',
          description: 'Pings an external HTTP endpoint to check latency.',
          parameters: const [
            ToolParameter(
              name: 'url',
              type: 'string',
              description: 'Target URL to ping',
            ),
          ],
          invoker: (args) async {
            final url = args['url']?.toString() ?? '';
            // Harness network access
            return {'url': url, 'reachable': true, 'latencyMs': 45};
          },
        ),
      ];

  /// 2. Intercept before tool execution for safety
  @override
  Future<void> onBeforeToolExecution(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    if (toolName == 'execShell' || toolName.startsWith('net')) {
      networkAuditLogs.add('Tool $toolName invoked with $arguments at ${DateTime.now()}');
    }
  }

  /// 3. Intercept after LLM step returns
  @override
  Future<void> onAfterStep(int stepIndex, ModelResponse response) async {
    if (response.hasReasoning) {
      networkAuditLogs.add('Step $stepIndex DeepSeek thought: ${response.reasoningContent}');
    }
  }
}
```

### 3. Register Plugin on Agent or Bridge

#### Option A: Via `Quickstart.createAgent`
```dart
final plugins = PluginRegistry()..register(NetworkAuditorPlugin());
final agent = Quickstart.createAgent(
  () => AutonomousDeviceAgent(),
  model: DeepSeekClient(apiKey: 'YOUR_KEY'),
  plugins: plugins,
);
```

#### Option B: Via `AgentBridgeDispatcher`
```dart
final dispatcher = AgentBridgeDispatcher.withDefaults();
dispatcher.pluginRegistry.register(NetworkAuditorPlugin());
```

---

## Testing Your Plugin (TDD)

Always write a unit test in `mobi_nooa_core/test/` using `MockModelClient`:

```dart
import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  test('NetworkAuditorPlugin injects pingEndpoint tool and records audit logs', () async {
    final plugin = NetworkAuditorPlugin();
    final registry = PluginRegistry()..register(plugin);

    final mockModel = MockModelClient();
    mockModel.queueToolCall(
      toolName: 'pingEndpoint',
      arguments: {'url': 'https://api.deepseek.com'},
    );
    mockModel.queueText('Endpoint is active.');

    final agent = Quickstart.createAgent(
      () => GeneralMobileAgent(),
      model: mockModel,
      plugins: registry,
    );

    final result = await agent.ellipsis<String>('Test network');
    expect(result, contains('active'));
    expect(plugin.networkAuditLogs, isNotEmpty);
  });
}
```

---

## Verification Checklist

- [ ] Subclass extends `AgentPlugin` with non-empty `name`, `version`, and `description`.
- [ ] Any injected tools use `ActionMetadata` with typed parameters.
- [ ] Exported in `mobi_nooa_core/lib/mobi_nooa_core.dart` under the `// Plugin System` header.
- [ ] Unit tests pass via `dart test`.
- [ ] Static analysis passes via `dart analyze`.
