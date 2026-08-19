import 'nooa_agent.dart';
import '../models/model_client.dart';

/// General-purpose mobile OO-Agent equipped with device status and note management.
class GeneralMobileAgent extends NooaAgent {
  GeneralMobileAgent({
    String? name,
    String? role,
    String? description,
  }) : super(
          name: name ?? 'GeneralMobileAgent',
          role: role ?? 'On-Device Mobile Agent',
          description: description ??
              'Executes device tools, CodeAct scripts, and manages local mobile state.',
        );

  @override
  void initAgent() {
    setState('notes', <String>[]);

    registerAction(
      name: 'getDeviceInfo',
      description: 'Retrieves device telemetry (battery, network, storage).',
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final status = await context.harness.device.getStatus();
        return status.toJson();
      },
    );

    registerAction(
      name: 'saveNote',
      description: 'Saves a note to explicit agent state.',
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
  }
}
