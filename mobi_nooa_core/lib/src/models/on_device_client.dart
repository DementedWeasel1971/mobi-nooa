import 'dart:async';
import 'model_client.dart';

/// Prompt template formats commonly used by local mobile LLM backends (GGUF, LiteRT).
enum PromptTemplate {
  /// ChatML format used by Qwen, SmolLM, and many finetunes (<|im_start|>role\ncontent<|im_end|>).
  chatMl,

  /// Llama 3 / 3.2 format (<|start_header_id|>role<|end_header_id|>\n\ncontent<|eot_id|>).
  llama3,

  /// Gemma 2 format (<start_of_turn>role\ncontent<end_of_turn>).
  gemma,

  /// Raw / generic delimiter format (<|role|>\ncontent\n<|end|>).
  raw,
}

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
  final PromptTemplate template;

  OnDeviceModelClient({
    this.modelName = 'on-device-mobile-llm',
    this.template = PromptTemplate.llama3,
    NativeInferenceBridge? bridge,
  }) : _bridge = bridge ?? _defaultBridge;

  static Future<String> _defaultBridge(
    String prompt, {
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    return 'On-device local completion (template: prompt len ${prompt.length})';
  }

  /// Formats a list of [ModelMessage] into a single prompt string according to [template].
  String formatPrompt(List<ModelMessage> messages) {
    final buffer = StringBuffer();

    switch (template) {
      case PromptTemplate.chatMl:
        for (final msg in messages) {
          final role = _roleString(msg.role);
          buffer.writeln('<|im_start|>$role\n${msg.content}<|im_end|>');
        }
        buffer.write('<|im_start|>assistant\n');
        break;

      case PromptTemplate.llama3:
        buffer.write('<|begin_of_text|>');
        for (final msg in messages) {
          final role = _roleString(msg.role);
          buffer.write(
            '<|start_header_id|>$role<|end_header_id|>\n\n${msg.content}<|eot_id|>',
          );
        }
        buffer.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
        break;

      case PromptTemplate.gemma:
        for (final msg in messages) {
          final role = msg.role == MessageRole.assistant ? 'model' : 'user';
          buffer.writeln('<start_of_turn>$role\n${msg.content}<end_of_turn>');
        }
        buffer.write('<start_of_turn>model\n');
        break;

      case PromptTemplate.raw:
        for (final msg in messages) {
          final role = _roleString(msg.role);
          buffer.writeln('<|$role|>\n${msg.content}\n<|end|>');
        }
        buffer.write('<|assistant|>\n');
        break;
    }

    return buffer.toString();
  }

  static String _roleString(MessageRole role) {
    switch (role) {
      case MessageRole.system:
        return 'system';
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.tool:
        return 'tool';
    }
  }

  /// Returns recommended stop sequences for the current [template].
  List<String> get defaultStopSequences {
    switch (template) {
      case PromptTemplate.chatMl:
        return const ['<|im_end|>', '<|im_start|>'];
      case PromptTemplate.llama3:
        return const ['<|eot_id|>', '<|end_of_text|>'];
      case PromptTemplate.gemma:
        return const ['<end_of_turn>', '<start_of_turn>'];
      case PromptTemplate.raw:
        return const ['<|end|>', '<|user|>', '<|system|>'];
    }
  }

  @override
  Future<ModelResponse> generate({
    required List<ModelMessage> messages,
    List<ToolDefinition>? tools,
    double temperature = 0.2,
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    final formattedPrompt = formatPrompt(messages);
    final stops = stopSequences ?? defaultStopSequences;

    final rawOutput = await _bridge(
      formattedPrompt,
      temperature: temperature,
      maxTokens: maxTokens ?? 1024,
      stopSequences: stops,
    );

    return ModelResponse(
      text: rawOutput.trim(),
      finishReason: 'stop',
      usage: TokenUsage(
        promptTokens: formattedPrompt.length ~/ 4,
        completionTokens: rawOutput.length ~/ 4,
        totalTokens: (formattedPrompt.length + rawOutput.length) ~/ 4,
      ),
    );
  }
}

