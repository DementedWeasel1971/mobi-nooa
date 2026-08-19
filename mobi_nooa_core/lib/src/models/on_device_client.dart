import 'dart:async';
import 'model_client.dart';

/// Function signature for the native Android bridge on-device LLM runner.
typedef NativeInferenceBridge = Future<String> Function(
  String prompt, {
  double temperature,
  int? maxTokens,
  List<String>? stopSequences,
});

/// On-Device Model Client running locally on Android mobile hardware
/// (e.g. MediaPipe LLM Inference, LiteRT, or llama.cpp GGUF engine).
class OnDeviceModelClient implements ModelClient {
  @override
  final String modelName;
  final NativeInferenceBridge _bridge;

  OnDeviceModelClient({
    this.modelName = 'on-device-mobile-llm',
    required NativeInferenceBridge bridge,
  }) : _bridge = bridge;

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    final promptBuffer = StringBuffer();

    // Format prompt suitable for compact mobile models (like Gemma-2B, Llama-3.2-1B/3B, Phi-3.5)
    for (final msg in messages) {
      if (msg.role == MessageRole.system) {
        promptBuffer.writeln('<|system|>\n${msg.content}\n<|end|>');
      } else if (msg.role == MessageRole.user) {
        promptBuffer.writeln('<|user|>\n${msg.content}\n<|end|>');
      } else if (msg.role == MessageRole.assistant) {
        promptBuffer.writeln('<|assistant|>\n${msg.content}\n<|end|>');
      } else if (msg.role == MessageRole.tool) {
        promptBuffer.writeln('<|tool_result|>\n${msg.content}\n<|end|>');
      }
    }
    promptBuffer.write('<|assistant|>\n');

    final rawOutput = await _bridge(
      promptBuffer.toString(),
      temperature: temperature,
      maxTokens: maxTokens ?? 1024,
      stopSequences: stopSequences ?? ['<|end|>', '<|user|>', '<|system|>'],
    );

    return ModelResponse(
      text: rawOutput.trim(),
      finishReason: 'stop',
      usage: TokenUsage(
        promptTokens: promptBuffer.length ~/ 4,
        completionTokens: rawOutput.length ~/ 4,
        totalTokens: (promptBuffer.length + rawOutput.length) ~/ 4,
      ),
    );
  }
}
