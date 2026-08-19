import 'dart:async';
import '../models/model_client.dart';

/// Client bridge for Model Context Protocol (MCP) servers on mobile or remote endpoints.
abstract class McpHarness {
  Future<List<ToolDefinition>> listTools();
  Future<dynamic> callTool(String name, Map<String, dynamic> arguments);
}

/// In-memory MCP harness allowing external tool registration.
class DefaultMcpHarness implements McpHarness {
  final Map<String, ToolDefinition> _tools = {};
  final Map<String, Future<dynamic> Function(Map<String, dynamic> args)>
      _handlers = {};

  void registerTool({
    required ToolDefinition definition,
    required Future<dynamic> Function(Map<String, dynamic> args) handler,
  }) {
    _tools[definition.name] = definition;
    _handlers[definition.name] = handler;
  }

  @override
  Future<List<ToolDefinition>> listTools() async => _tools.values.toList();

  @override
  Future<dynamic> callTool(String name, Map<String, dynamic> arguments) async {
    if (!_handlers.containsKey(name)) {
      throw ArgumentError('MCP tool "$name" not found.');
    }
    return await _handlers[name]!(arguments);
  }
}
