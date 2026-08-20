import 'nooa_agent.dart';
import '../models/model_client.dart';

/// Autonomous on-device mobile agent capable of system telemetry monitoring,
/// user alerting, and two-way procedural skill execution and synthesis.
///
/// Implements NOOA Principle 1 (Class-as-Agent), Principle 5 (Explicit State),
/// and Principle 6 (Model-Callable Harness APIs).
class AutonomousDeviceAgent extends NooaAgent {
  AutonomousDeviceAgent({
    String? name,
    String? role,
    String? description,
  }) : super(
          name: name ?? 'AutonomousDeviceAgent',
          role: role ?? 'Autonomous Mobile System & Triage Agent',
          description: description ??
              'Monitors mobile hardware telemetry, triggers alerts, and executes/synthesizes procedural skills.',
          customPromptInstructions:
              'Always check relevant procedural skills before executing multi-step triage workflows. '
              'If you discover a new reusable recovery workflow, synthesize and persist it via learnSkill.',
        );

  @override
  void initAgent() {
    setState('telemetry_history', <Map<String, dynamic>>[]);
    setState('alerts', <Map<String, dynamic>>[]);
    setState('notes', <String>[]);

    registerAction(
      name: 'getDeviceInfo',
      description: 'Captures battery level, charging state, network type, and disk storage metrics.',
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final status = await context.harness.device.getStatus();
        final json = status.toJson();
        final history = List<Map<String, dynamic>>.from(
          getState('telemetry_history') as List? ?? [],
        )..add(json);
        setState('telemetry_history', history);
        return json;
      },
    );

    registerAction(
      name: 'sendNotification',
      description: 'Emits a high-priority system notification to the mobile user.',
      parameters: const [
        ToolParameter(
          name: 'title',
          type: 'string',
          description: 'Notification title',
          required: true,
        ),
        ToolParameter(
          name: 'body',
          type: 'string',
          description: 'Notification message body',
          required: true,
        ),
      ],
      returnType: 'bool',
      invoker: (args) async {
        final title = args['title'] as String;
        final body = args['body'] as String;
        await context.harness.device.sendNotification(
          title: title,
          body: body,
        );
        final alerts = List<Map<String, dynamic>>.from(
          getState('alerts') as List? ?? [],
        )..add({'title': title, 'body': body, 'timestamp': DateTime.now().toIso8601String()});
        setState('alerts', alerts);
        return true;
      },
    );

    registerAction(
      name: 'vibrate',
      description: 'Triggers mobile device haptic vibration feedback.',
      parameters: const [
        ToolParameter(
          name: 'durationMs',
          type: 'integer',
          description: 'Vibration duration in milliseconds (default: 200)',
          required: false,
        ),
      ],
      returnType: 'bool',
      invoker: (args) async {
        final duration = (args['durationMs'] as num?)?.toInt() ?? 200;
        await context.harness.device.vibrate(durationMs: duration);
        return true;
      },
    );

    registerAction(
      name: 'searchSkills',
      description: 'Discovers procedural skills and execution recipes matching a task query.',
      parameters: const [
        ToolParameter(
          name: 'query',
          type: 'string',
          description: 'Search query or task keyword',
          required: true,
        ),
      ],
      returnType: 'List<Map<String, dynamic>>',
      invoker: (args) async {
        final query = args['query'] as String;
        return await context.harness.skill.searchSkills(query);
      },
    );

    registerAction(
      name: 'loadSkill',
      description: 'Loads the full step-by-step instructions and recipes for a specific skill.',
      parameters: const [
        ToolParameter(
          name: 'skillId',
          type: 'string',
          description: 'Unique identifier of the skill',
          required: true,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final id = args['skillId'] as String;
        final skill = await context.harness.skill.loadSkill(id);
        return skill ?? {'error': 'Skill not found: $id'};
      },
    );

    registerAction(
      name: 'learnSkill',
      description: 'Synthesizes and permanently saves a newly discovered procedural skill to the skill store.',
      parameters: const [
        ToolParameter(
          name: 'id',
          type: 'string',
          description: 'Unique slug identifier for the skill (e.g. "battery-thermal-saver")',
          required: true,
        ),
        ToolParameter(
          name: 'name',
          type: 'string',
          description: 'Human readable name of the skill',
          required: true,
        ),
        ToolParameter(
          name: 'description',
          type: 'string',
          description: 'Summary of what this skill does',
          required: true,
        ),
        ToolParameter(
          name: 'instructions',
          type: 'string',
          description: 'Step-by-step instructions and guidelines for executing the skill',
          required: true,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final id = args['id'] as String;
        final name = args['name'] as String;
        final desc = args['description'] as String;
        final instructions = args['instructions'] as String;

        return await context.harness.skill.createSkill(
          id: id,
          name: name,
          description: desc,
          instructions: instructions,
        );
      },
    );

    registerAction(
      name: 'saveNote',
      description: 'Appends a text note into explicit agent state.',
      parameters: const [
        ToolParameter(
          name: 'text',
          type: 'string',
          description: 'Note text',
          required: true,
        ),
      ],
      returnType: 'int',
      invoker: (args) async {
        final text = args['text'] as String;
        final notes = List<String>.from(getState('notes') as List? ?? [])..add(text);
        setState('notes', notes);
        return notes.length;
      },
    );

    registerAction(
      name: 'assessResourceHeadroom',
      description: 'Evaluates real-time device resource pressure (RAM, thermals, battery) and computes adaptive execution budget.',
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final budget = await context.harness.governor.evaluateBudget();
        final json = budget.toJson();
        setState('resource_budget', json);
        return json;
      },
    );

    registerAction(
      name: 'applyGovernorPolicy',
      description: 'Applies active load balancing and pacing policy to prevent device overdraw.',
      parameters: const [
        ToolParameter(
          name: 'targetModelTier',
          type: 'string',
          description: 'Target model tier (e.g. "onDeviceStandard", "cloudOffload", "onDeviceTiny")',
          required: true,
        ),
        ToolParameter(
          name: 'maxConcurrent',
          type: 'integer',
          description: 'Max parallel agent tasks allowed',
          required: true,
        ),
        ToolParameter(
          name: 'pacingDelayMs',
          type: 'integer',
          description: 'Step execution pacing delay in milliseconds',
          required: true,
        ),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final policy = {
          'targetModelTier': args['targetModelTier'],
          'maxConcurrent': args['maxConcurrent'],
          'pacingDelayMs': args['pacingDelayMs'],
          'appliedAt': DateTime.now().toIso8601String(),
        };
        setState('governor_policy', policy);
        return {'status': 'policy_applied', 'policy': policy};
      },
    );
  }
}
