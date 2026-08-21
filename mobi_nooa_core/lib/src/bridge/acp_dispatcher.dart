import 'dart:async';
import 'dart:convert';
import 'agent_bridge_dispatcher.dart';

/// Standard Agent Client Protocol (ACP) JSON-RPC 2.0 Response.
class AcpResponse {
  final dynamic id;
  final Map<String, dynamic>? result;
  final AcpError? error;

  AcpResponse({
    required this.id,
    this.result,
    this.error,
  });

  factory AcpResponse.success(dynamic id, Map<String, dynamic> result) =>
      AcpResponse(id: id, result: result);

  factory AcpResponse.failure(dynamic id, int code, String message, [dynamic data]) =>
      AcpResponse(
        id: id,
        error: AcpError(code: code, message: message, data: data),
      );

  Map<String, dynamic> toJson() => {
        'jsonrpc': '2.0',
        'id': id,
        if (result != null) 'result': result,
        if (error != null) 'error': error!.toJson(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// Structured ACP Error conforming to JSON-RPC 2.0 spec.
class AcpError {
  final int code;
  final String message;
  final dynamic data;

  AcpError({
    required this.code,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}

/// Agent Client Protocol (ACP) Dispatcher.
///
/// Implements xAI's open JSON-RPC 2.0 agent protocol, enabling external IDEs
/// (Zed, VS Code, Cursor), CI/CD pipelines, and local CLIs to drive mobi-nooa agents headlessly.
class AcpDispatcher {
  final AgentBridgeDispatcher bridgeDispatcher;

  AcpDispatcher({AgentBridgeDispatcher? bridgeDispatcher})
      : bridgeDispatcher = bridgeDispatcher ?? AgentBridgeDispatcher.withDefaults();

  /// Handles an incoming JSON-RPC 2.0 message string or map.
  Future<AcpResponse> handleJsonRpc(dynamic message) async {
    Map<String, dynamic> req;
    if (message is String) {
      try {
        req = Map<String, dynamic>.from(jsonDecode(message) as Map);
      } catch (e) {
        return AcpResponse.failure(null, -32700, 'Parse error: Invalid JSON');
      }
    } else if (message is Map) {
      req = Map<String, dynamic>.from(message);
    } else {
      return AcpResponse.failure(null, -32600, 'Invalid Request: Expected Object or String');
    }

    final id = req['id'];
    final method = req['method'] as String?;
    final params = Map<String, dynamic>.from((req['params'] as Map?) ?? {});

    if (method == null || method.isEmpty) {
      return AcpResponse.failure(id, -32600, 'Invalid Request: Missing "method" field');
    }

    try {
      switch (method) {
        // Protocol Handshake & Capabilities Negotiation
        case 'initialize':
          return AcpResponse.success(id, {
            'protocolVersion': '1.0.0',
            'agentInfo': {
              'name': 'mobi-nooa',
              'version': '1.0.0',
              'architecture': 'NOOA + DeepSeek + Grok Build',
            },
            'capabilities': {
              'subagents': true,
              'planMode': true,
              'sessionTimeTravel': true,
              'objectHeap': true,
              'fallbackCascade': true,
              'astSecurityGuardrails': true,
              'resourceGovernor': true,
            },
            'registeredAgents': bridgeDispatcher.registeredAgentNames,
          });

        case 'agents/list':
          final res = await bridgeDispatcher.handle({'action': 'listAgents'});
          return AcpResponse.success(id, res);

        case 'models/list':
          final res = await bridgeDispatcher.handle({'action': 'listModelProviders'});
          return AcpResponse.success(id, res);

        case 'session/create':
          final res = await bridgeDispatcher.handle({
            'action': 'createSession',
            'sessionId': params['sessionId'],
          });
          return AcpResponse.success(id, res);

        case 'session/prompt':
        case 'session/run':
          final res = await bridgeDispatcher.handle({
            'action': 'runAgentLoop',
            ...params,
          });
          if (res.containsKey('error') && res['error'] != null) {
            return AcpResponse.failure(id, -32000, res['error'].toString(), res);
          }
          return AcpResponse.success(id, res);

        case 'session/replay':
          final res = await bridgeDispatcher.handle({
            'action': 'replaySession',
            ...params,
          });
          return AcpResponse.success(id, res);

        case 'session/fork':
          final res = await bridgeDispatcher.handle({
            'action': 'forkSession',
            ...params,
          });
          return AcpResponse.success(id, res);

        case 'governor/telemetry':
          final res = await bridgeDispatcher.handle({'action': 'getDeviceTelemetry'});
          return AcpResponse.success(id, res);

        case 'governor/budget':
          final res = await bridgeDispatcher.handle({'action': 'assessBudget'});
          return AcpResponse.success(id, res);

        case 'heap/compact':
          final res = await bridgeDispatcher.handle({'action': 'compactHeap'});
          return AcpResponse.success(id, res);

        case 'plugins/list':
          final res = await bridgeDispatcher.handle({'action': 'listPlugins'});
          return AcpResponse.success(id, res);

        case 'tools/register':
          final res = await bridgeDispatcher.handle({
            'action': 'registerDynamicTool',
            ...params,
          });
          return AcpResponse.success(id, res);

        default:
          return AcpResponse.failure(id, -32601, 'Method not found: "$method"');
      }
    } catch (e, st) {
      return AcpResponse.failure(id, -32603, 'Internal server error: $e', {'stack': st.toString()});
    }
  }
}
