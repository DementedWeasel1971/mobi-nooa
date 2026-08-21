import 'dart:async';
import 'dart:convert';
import 'loop_config.dart';
import 'step_event.dart';
import '../agent/nooa_agent.dart';
import '../agent/agent_context.dart';
import '../agent/reflector.dart';
import '../agent/operating_mode.dart';
import '../models/model_client.dart';
import '../tracing/trace_event.dart';
import '../engine/sandboxed_environment.dart';
import '../engine/code_act_engine.dart';
import '../heap/object_reference.dart';
import '../security/permission_manager.dart';
import '../plugin/plugin_context.dart';
import '../plugin/plugin_registry.dart';
import '../session/session_event.dart';
import '../session/session_event_log.dart';

/// Programmable execution loop for NOOA Agents.
///
/// Implements NOOA Principle 4: "Programmable loop engineering" alongside
/// DeepSeek Harness advancements (Everything-is-a-plugin, tiered permissions,
/// append-only session event logs, and reasoning thought extraction).
class AgentLoop {
  final NooaAgent agent;
  final AgentContext context;
  final LoopConfig config;
  final List<StepExecution> history = [];

  late final SandboxedEnvironment _sandbox;
  late final CodeActEngine _codeActEngine;
  late final PermissionManager _permissionManager;
  late final PluginRegistry _plugins;
  late final SessionEventLog? _sessionLog;
  late final AgentOperatingMode _operatingMode;

  AgentLoop({
    required this.agent,
    required this.context,
    this.config = const LoopConfig(),
  }) {
    _permissionManager = config.permissionManager ?? context.permissionManager;
    _plugins = config.plugins ?? context.plugins;
    _sessionLog = config.sessionLog ?? context.sessionLog;
    _operatingMode = config.operatingMode != AgentOperatingMode.autonomous
        ? config.operatingMode
        : context.operatingMode;

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
      data: {'goal': goal, 'inputs': inputs, 'mode': _operatingMode.name},
    );

    // Initialize all plugins in the context
    await _plugins.initializeAll(
      PluginContext(
        agent: agent,
        agentContext: context,
        permissionManager: _permissionManager,
      ),
    );

    // Record session start / user message
    _sessionLog?.append(
      SessionEvent(
        sessionId: _sessionLog?.sessionId ?? 'session',
        stepIndex: 0,
        type: SessionEventType.userMessage,
        data: {'goal': goal, 'inputs': inputs},
        summary: 'Goal: $goal',
      ),
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

    // Aggregate actions declared on the agent + actions contributed by plugins
    final allActions = <ActionMetadata>[
      ...agent.declaredActions,
      ..._plugins.collectActions(),
    ];
    final tools = allActions.map((a) => a.toToolDefinition()).toList();

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

      // Plugin hook: beforeStep
      await _plugins.dispatchBeforeStep(stepIndex, messages);

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
            'reasoning': response.reasoningContent,
            'toolCalls': response.toolCalls.map((t) => t.toJson()).toList(),
          },
        );

        // Plugin hook: afterStep
        await _plugins.dispatchAfterStep(stepIndex, response);

        // Record reasoning/thought event if present
        if (response.hasReasoning) {
          _sessionLog?.append(
            SessionEvent(
              sessionId: _sessionLog?.sessionId ?? 'session',
              stepIndex: stepIndex,
              type: SessionEventType.assistantThought,
              data: {'thought': response.reasoningContent},
              summary: 'DeepSeek Reasoning Thought',
            ),
          );
        }

        messages.add(ModelMessage.assistant(
          response.text,
          toolCalls: response.hasToolCalls ? response.toolCalls : null,
        ));

        // Check if model emitted code actions in markdown block
        final codeSnippet = CodeActEngine.extractCodeBlock(response.text);
        final hasCodeBlock = codeSnippet != response.text.trim() && codeSnippet.isNotEmpty;

        final thoughtText = response.hasReasoning
            ? '${response.reasoningContent}\n\n${response.text}'.trim()
            : response.text;

        if (response.hasToolCalls) {
          consecutiveErrors = 0;
          final toolOutputs = <String>[];

          for (final call in response.toolCalls) {
            _sessionLog?.append(
              SessionEvent(
                sessionId: _sessionLog?.sessionId ?? 'session',
                stepIndex: stepIndex,
                type: SessionEventType.toolCall,
                data: {'tool': call.name, 'arguments': call.arguments},
                summary: 'Invoking ${call.name}',
              ),
            );

            final output = await _executeToolCall(call, allActions, stepIndex);
            toolOutputs.add(output);

            _sessionLog?.append(
              SessionEvent(
                sessionId: _sessionLog?.sessionId ?? 'session',
                stepIndex: stepIndex,
                type: SessionEventType.toolResult,
                data: {'tool': call.name, 'result': output},
                summary: 'Result from ${call.name}',
              ),
            );

            messages.add(ModelMessage.tool(
              content: output,
              toolCallId: call.id,
              name: call.name,
            ));
          }

          history.add(StepExecution(
            stepIndex: stepIndex,
            thought: thoughtText,
            toolCalls: response.toolCalls,
            toolOutputs: toolOutputs,
            tokenUsage: response.usage,
            duration: stepStopwatch.elapsed,
          ));
        } else if (hasCodeBlock && config.executionMode != ExecutionMode.toolCalling) {
          consecutiveErrors = 0;

          // Permission check for CodeAct execution
          await _permissionManager.authorize(
            'codeActSnippet',
            {'code': codeSnippet},
            rationale: 'Executing sandboxed CodeAct snippet',
          );

          _sessionLog?.append(
            SessionEvent(
              sessionId: _sessionLog?.sessionId ?? 'session',
              stepIndex: stepIndex,
              type: SessionEventType.codeActSnippet,
              data: {'code': codeSnippet},
              summary: 'Executing CodeAct snippet',
            ),
          );

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

          _sessionLog?.append(
            SessionEvent(
              sessionId: _sessionLog?.sessionId ?? 'session',
              stepIndex: stepIndex,
              type: SessionEventType.codeActResult,
              data: {'stdout': codeResult.stdout, 'success': codeResult.success},
              summary: 'CodeAct output',
            ),
          );

          messages.add(ModelMessage.user(
            'Code Execution Output:\n$outputStr',
          ));

          history.add(StepExecution(
            stepIndex: stepIndex,
            thought: thoughtText,
            codeSnippet: codeSnippet,
            codeOutput: outputStr,
            tokenUsage: response.usage,
            duration: stepStopwatch.elapsed,
          ));
        } else {
          // Terminal response
          history.add(StepExecution(
            stepIndex: stepIndex,
            thought: thoughtText,
            tokenUsage: response.usage,
            duration: stepStopwatch.elapsed,
            isTerminal: true,
          ));

          _sessionLog?.append(
            SessionEvent(
              sessionId: _sessionLog?.sessionId ?? 'session',
              stepIndex: stepIndex,
              type: SessionEventType.assistantResponse,
              data: {'result': response.text},
              summary: 'Final Agent Response',
            ),
          );

          context.tracer.record(
            type: TraceEventType.agentFinish,
            stepIndex: stepIndex,
            description: 'Agent finished successfully',
            data: {'result': response.text},
            duration: DateTime.now().difference(startTime),
          );

          await _plugins.dispatchAgentFinished(response.text);
          return response.text;
        }
      } catch (e, stack) {
        stepStopwatch.stop();
        consecutiveErrors++;

        _sessionLog?.append(
          SessionEvent(
            sessionId: _sessionLog?.sessionId ?? 'session',
            stepIndex: stepIndex,
            type: SessionEventType.error,
            data: {'error': e.toString(), 'stack': stack.toString()},
            summary: 'Error in step $stepIndex',
          ),
        );

        context.tracer.record(
          type: TraceEventType.error,
          stepIndex: stepIndex,
          description: 'Error during step $stepIndex: $e',
          data: {'error': e.toString(), 'stack': stack.toString()},
        );

        await _plugins.dispatchError(e, stack);

        if (consecutiveErrors >= config.maxConsecutiveErrors) {
          throw StateError('Agent failed after $consecutiveErrors consecutive errors: $e');
        }

        messages.add(ModelMessage.user('Execution Error encountered: $e. Please correct and retry.'));
      }
    }

    throw StateError('Agent reached maximum step limit (${config.maxSteps}) without completing.');
  }

  Future<String> _executeToolCall(
    ToolCall call,
    List<ActionMetadata> availableActions,
    int stepIndex,
  ) async {
    final matching = availableActions.where((a) => a.name == call.name).toList();
    if (matching.isEmpty) {
      return 'Error: Action "${call.name}" is not registered on agent ${agent.name}.';
    }

    final action = matching.first;
    final callWatch = Stopwatch()..start();

    try {
      // 1. Permission check via PermissionManager
      await _permissionManager.authorize(
        action.name,
        call.arguments,
        rationale: action.description,
      );

      // 2. Plugin hook: beforeToolExecution
      await _plugins.dispatchBeforeToolExecution(action.name, call.arguments);

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

      // 3. Plugin hook: afterToolExecution
      await _plugins.dispatchAfterToolExecution(
        action.name,
        call.arguments,
        wrappedResult,
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
