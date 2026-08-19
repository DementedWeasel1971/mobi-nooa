import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// Reference Mobile Assistant Agent demonstrating Principle 5 (Explicit Object State),
/// Principle 6 (Model-Callable Harness APIs), and Subagent Orchestration.
class MobileAssistantAgent extends NooaAgent {
  MobileAssistantAgent()
      : super(
          name: 'MobileAssistantAgent',
          role: 'On-Device Mobile Executive Assistant',
          description:
              'Manages device tasks, battery health alerts, local notes, and subagents.',
        );

  @override
  void initAgent() {
    setState('notes', <String>[]);
    setState('alerts', <String>[]);

    registerAction(
      name: 'checkBatteryAndOptimize',
      description: 'Checks device battery level and triggers power optimization if below threshold.',
      parameters: const [
        ToolParameter(
          name: 'threshold',
          type: 'number',
          description: 'Threshold below which to notify (0.0 to 1.0)',
          required: false,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final threshold = (args['threshold'] as num?)?.toDouble() ?? 0.20;
        final status = await context.harness.device.getStatus();

        if (status.batteryLevel < threshold && !status.isCharging) {
          final alert = 'Low battery alert: ${(status.batteryLevel * 100).toInt()}%';
          final alerts = List<String>.from(getState('alerts') as List? ?? [])..add(alert);
          setState('alerts', alerts);

          await context.harness.device.sendNotification(
            title: 'mobi-nooa Battery Alert',
            body: 'Battery is at ${(status.batteryLevel * 100).toInt()}%. Enabling eco-mode.',
          );
          return alert;
        }

        return 'Battery healthy at ${(status.batteryLevel * 100).toInt()}% (Charging: ${status.isCharging}).';
      },
    );

    registerAction(
      name: 'addNote',
      description: 'Saves a text note into on-device agent state.',
      parameters: const [
        ToolParameter(
          name: 'text',
          type: 'string',
          description: 'The note text to store',
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
  }
}

Future<void> main() async {
  print('=== mobi-nooa: MobileAssistantAgent Demo ===');

  final heap = ObjectHeap();
  final harness = HarnessApi(
    device: DefaultDeviceHarness(
      initialStatus: const DeviceStatus(
        batteryLevel: 0.15,
        isCharging: false,
      ),
    ),
  );
  final tracer = Tracer('MobileAssistantDemo');
  final model = MockModelClient();

  final agent = MobileAssistantAgent();
  final context = AgentContext(
    heap: heap,
    model: model,
    harness: harness,
    tracer: tracer,
  );
  agent.attachContext(context);

  model.queueToolCall(
    toolName: 'checkBatteryAndOptimize',
    arguments: {'threshold': 0.20},
    thought: 'Checking battery level to assess device health.',
  );
  model.queueToolCall(
    toolName: 'addNote',
    arguments: {'text': 'Remember to plug in phone tonight!'},
    thought: 'Saving reminder note.',
  );
  model.queueText('Device checked. Battery was 15%, notification dispatched and reminder saved.');

  final result = await agent.ellipsis<String>('Audit phone battery and save reminder note.');

  print('\nResult:\n$result');
  print('\nUpdated Agent State:\n${agent.getStateSnapshot()}');
  print('\nNotifications sent:\n${(harness.device as DefaultDeviceHarness).sentNotifications}');
}
