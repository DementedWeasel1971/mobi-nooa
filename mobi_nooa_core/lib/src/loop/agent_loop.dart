import 'dart:async';
import 'dart:convert';
import 'loop_config.dart';
import 'step_event.dart';
import '../agent/nooa_agent.dart';
import '../agent/agent_context.dart';
import '../agent/reflector.dart';
import '../models/model_client.dart';
import '../tracing/trace_event.dart';
import '../engine/sandboxed_environment.dart';
import '../engine/code_act_engine.dart';
import '../heap/object_reference.dart';

/// Programmable execution loop for NOOA Agents.
///
/// Implements NOOA Principle 4: "Programmable loop engineering".
class AgentLoop {
  final NooaAgent agent;
  final AgentContext context;
  final LoopConfig config;
  final List<StepExecution> history = [];

  late final SandboxedEnvironment _sandbox;
  late final CodeActEngine _codeActEngine;

  AgentLoop({
    required this.agent,
    required this.context,
    this.config = const LoopConfig(),
  }) {
    _sandbox = SandboxedEnvironment(
      heap: context.heap,
      harness: context.harness,
      initialVariables: {
        'agent': agent,
      },
    );
    _codeActEngine = CodeActEngine(_sandbox);
  }

  /// Runs the agentic loop to satisfy the given task/goal.
  Future<dynamic> run(
    String goal, {
    Map<String, dynamic> inputs = const {},
  }) async {
    final startTime = DateTime.now();
    context.tracer.record(
      type: TraceEventType.agentStart,
      description: 'Starting agent ${agent.name} with goal: $goal',
      data: {'goal': goal, 'inputs': inputs},
    );

    final messages = <ModelMessage>[];

    // 1. Initial Prompt Construction
    final heapSummary = context.heap.toPromptSummary();
    final systemPrompt = AgentReflector.buildSystemPrompt(
      agent: agent,
      heapSummary: heapSummary,
    );
    messages.add(ModelMessage.system(systemPrompt));

    final userTask = StringBuffer('Task: $goal');
    if (inputs.isNotEmpty) {
      userTask.writeln('\nInputs:\n```json\n${jsonEncode(inputs)}\n```');
    }
    messages.add(ModelMessage.user(userTask.toString()));

    // Available tools derived from agent actions
    final tools = agent.declaredActions.map((a) => a.toToolDefinition()).toList();

    int stepIndex = 0;
    int consecutiveErrors = 0;

    while (stepIndex < config.maxSteps) {
      if (context.isCancelled) {
        throw StateError('Agent execution was cancelled.');
      }

      stepIndex++;
      final stepStopwatch = Stopwatch()..start();

      context.tracer.record(
        type: TraceEventType.stepStart,
        stepIndex: stepIndex,
        description: 'Executing step $stepIndex/${config.maxSteps}',
      );

      // Re-synchronize heap summary before calling LLM
      if (config.autoSummarizeHeap && stepIndex > 1) {
        final updatedHeap = context.heap.toPromptSummary();
        messages.first = ModelMessage.system(
          AgentReflector.buildSystemPrompt(
            agent: agent,
            heapSummary: updatedHeap,
          ),
        );
      }

      try {
        final response = await context.model.generate(
          messages: messages,
          tools: tools.isNotEmpty ? tools : null,
          temperature: config.temperature,
        ).timeout(config.stepTimeout);

        stepStopwatch.stop();

        context.tracer.record(
          type: TraceEventType.llmResponse,
          stepIndex: stepIndex,
          description: 'Received LLM response',
          tokenUsage: response.usage,
          data: {
            'text': response.text,
            'toolCalls': response.toolCalls.map((t) => t.toJson()).toList(),
          },
        );

        messages.add(ModelMessage.assistant(
          response.text,
          toolCalls: response.hasToolCalls ? response.toolCalls : null,
        ));

        // Check if model emitted code actions in markdown block
        final codeSnippet = CodeActEngine.extractCodeBlock(response.text);
        final hasCodeBlock = codeSnippet != response.text.trim() && codeSnippet.isNotEmpty;

        if (response.hasToolCalls) {
          consecutiveErrors = 0;
          final toolOutputs = <String>[];

          for (final call in response.toolCalls) {
            final output = await _executeToolCall(call, stepIndex);
            toolOutputs.add(output);

            messages.add(ModelMessage.tool(
              content: output,
              toolCallId: call.id,
              name: call.name,
            ));
          }

          history.add(StepExecution(
            stepIndex: stepIndex,
            thought: response.text,
            toolCalls: response.toolCalls,
            toolOutputs: toolOutputs,
            tokenUsage: response.usage,
            duration: stepStopwatch.elapsed,
          ));
        } else if (hasCodeBlock && config.executionMode != ExecutionMode.toolCalling) {
          consecutiveErrors = 0;
          final codeResult = await _codeActEngine.execute(codeSnippet);

          context.tracer.record(
            type: TraceEventType.codeActExecution,
            stepIndex: stepIndex,
            description: 'Executed CodeAct snippet',
            duration: codeResult.executionDuration,
            data: {
              'code': codeSnippet,
              'success': codeResult.success,
              'stdout': codeResult.stdout,
              'returnedRef': codeResult.returnedObjectRef?.handle,
            },
          );

          final outputStr = codeResult.toPromptOutput();
          messages.add(ModelMessage.user(
            'Code Execution Output:\n$outputStr',
          ));

          history.add(StepExecution(
            stepIndex: stepIndex,
            thought: response.text,
            codeSnippet: codeSnippet,
            codeOutput: outputStr,
            tokenUsage: response.usage,
            duration: stepStopwatch.elapsed,
          ));
        } else {
          // Terminal response
          history.add(StepExecution(
            stepIndex: stepIndex,
            thought: response.text,
            tokenUsage: response.usage,
            duration: stepStopwatch.elapsed,
            isTerminal: true,
          ));

          context.tracer.record(
            type: TraceEventType.agentFinish,
            stepIndex: stepIndex,
            description: 'Agent finished successfully',
            data: {'result': response.text},
            duration: DateTime.now().difference(startTime),
          );

          return response.text;
        }
      } catch (e, stack) {
        stepStopwatch.stop();
        consecutiveErrors++;

        context.tracer.record(
          type: TraceEventType.error,
          stepIndex: stepIndex,
          description: 'Error during step $stepIndex: $e',
          data: {'error': e.toString(), 'stack': stack.toString()},
        );

        if (consecutiveErrors >= config.maxConsecutiveErrors) {
          throw StateError('Agent failed after $consecutiveErrors consecutive errors: $e');
        }

        messages.add(ModelMessage.user('Execution Error encountered: $e. Please correct and retry.'));
      }
    }

    throw StateError('Agent reached maximum step limit (${config.maxSteps}) without completing.');
  }

  Future<String> _executeToolCall(ToolCall call, int stepIndex) async {
    final matching = agent.declaredActions.where((a) => a.name == call.name).toList();
    if (matching.isEmpty) {
      return 'Error: Action "${call.name}" is not registered on agent ${agent.name}.';
    }

    final action = matching.first;
    final callWatch = Stopwatch()..start();

    try {
      // Resolve any #ref_ handles passed inside arguments
      final resolvedArgs = <String, dynamic>{};
      for (final entry in call.arguments.entries) {
        resolvedArgs[entry.key] = context.heap.resolveHandleOrValue(entry.value);
      }

      final rawResult = await action.invoker(resolvedArgs);
      callWatch.stop();

      // Wrap complex/large return objects into ObjectHeap (Pass-by-reference)
      final wrappedResult = context.heap.maybeWrap(
        rawResult,
        label: '${agent.name}.${action.name}',
      );

      context.tracer.record(
        type: TraceEventType.toolExecution,
        stepIndex: stepIndex,
        description: 'Executed tool ${action.name}',
        duration: callWatch.elapsed,
        data: {
          'tool': action.name,
          'arguments': call.arguments,
          'result': wrappedResult is ObjectReference
              ? wrappedResult.toPromptString()
              : wrappedResult.toString(),
        },
      );

      if (wrappedResult is ObjectReference) {
        return wrappedResult.toPromptString();
      }
      return wrappedResult.toString();
    } catch (e, stack) {
      callWatch.stop();
      return 'Error invoking ${action.name}: $e\n$stack';
    }
  }
}
