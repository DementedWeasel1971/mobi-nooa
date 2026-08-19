import 'dart:async';
import 'model_client.dart';

/// Predictable mock model client for unit tests and local simulations.
class MockModelClient implements ModelClient {
  @override
  final String modelName;

  final List<ModelResponse Function(List<ModelMessage> messages, List<ToolDefinition>? tools)> _handlers = [];
  int _callIndex = 0;

  MockModelClient({this.modelName = 'mock-model'});

  void queueResponse(ModelResponse response) {
    _handlers.add((messages, tools) => response);
  }

  void queueText(String text) {
    _handlers.add((messages, tools) => ModelResponse(text: text));
  }

  void queueToolCall({
    required String toolName,
    required Map<String, dynamic> arguments,
    String? thought,
    String? callId,
  }) {
    _handlers.add((messages, tools) => ModelResponse(
          text: thought ?? '',
          toolCalls: [
            ToolCall(
              id: callId ?? 'call_${_callIndex + 1}',
              name: toolName,
              arguments: arguments,
            ),
          ],
        ));
  }

  void queueHandler(
      ModelResponse Function(List<ModelMessage> messages, List<ToolDefinition>? tools) handler) {
    _handlers.add(handler);
  }

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    if (_callIndex < _handlers.length) {
      final handler = _handlers[_callIndex++];
      return handler(messages, tools);
    }
    return ModelResponse(
      text: 'Mock response ${_callIndex++}',
      finishReason: 'stop',
    );
  }

  void reset() {
    _handlers.clear();
    _callIndex = 0;
  }
}
