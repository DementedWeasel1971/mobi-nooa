import 'package:mobi_nooa_core/mobi_nooa_core.dart';
import 'package:test/test.dart';

/// Agent C: Specialist Worker (Database / Storage Repair)
class StorageRepairAgent extends NooaAgent {
  StorageRepairAgent()
      : super(
          name: 'StorageRepairAgent',
          role: 'Database & Storage Repair Specialist',
          description: 'Specializes in low-level SQLite repair and cache compaction.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'compactDatabase',
      description: 'Performs low-level database compaction.',
      parameters: const [
        ToolParameter(name: 'targetDb', type: 'string', description: 'Target database file', required: true),
      ],
      returnType: 'Map<String, dynamic>',
      invoker: (args) async {
        final targetDb = args['targetDb'] as String;
        setState('repairedDb', targetDb);
        return {'status': 'success', 'freedBytes': 1048576, 'targetDb': targetDb};
      },
    );
  }
}

/// Agent B: System Triage Coordinator (Middle-Tier Agent)
class TriageCoordinatorAgent extends NooaAgent {
  final ModelClient? specialistModel;

  TriageCoordinatorAgent({this.specialistModel})
      : super(
          name: 'TriageCoordinatorAgent',
          role: 'Mobile System Triage Lead',
          description: 'Diagnoses mobile issues and refers storage corruption to StorageRepairAgent.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'referToStorageSpecialist',
      description: 'Delegates storage recovery to the dedicated StorageRepairAgent.',
      parameters: const [
        ToolParameter(name: 'databasePath', type: 'string', description: 'Path to corrupted DB', required: true),
      ],
      returnType: 'String',
      invoker: (args) async {
        final dbPath = args['databasePath'] as String;
        final specialist = StorageRepairAgent();

        // Agent B refers subtask to Agent C
        final result = await spawnSubagent(
          subagent: specialist,
          task: 'Compact and repair database at $dbPath',
          modelOverride: specialistModel,
        );

        setState('specialistResolution', result);
        return 'Specialist completed repair: $result';
      },
    );
  }
}

/// Agent A: User Assistant / Front-Facing Orchestrator
class FrontDeskAgent extends NooaAgent {
  final ModelClient? triageModel;
  final ModelClient? specialistModel;

  FrontDeskAgent({this.triageModel, this.specialistModel})
      : super(
          name: 'FrontDeskAgent',
          role: 'Customer-Facing AI Assistant',
          description: 'Receives user requests and refers hardware/system issues to TriageCoordinatorAgent.',
        );

  @override
  void initAgent() {
    registerAction(
      name: 'escalateToTriage',
      description: 'Escalates technical issues to TriageCoordinatorAgent.',
      parameters: const [
        ToolParameter(name: 'issueSummary', type: 'string', description: 'Summary of the user issue', required: true),
      ],
      returnType: 'String',
      invoker: (args) async {
        final issue = args['issueSummary'] as String;
        final triageLead = TriageCoordinatorAgent(specialistModel: specialistModel);

        // Agent A refers subtask to Agent B
        final result = await spawnSubagent(
          subagent: triageLead,
          task: 'Diagnose and resolve issue: $issue',
          modelOverride: triageModel,
        );

        setState('triageResolution', result);
        return 'Triage lead reported: $result';
      },
    );
  }
}

void main() {
  group('Hierarchical Multi-Agent Delegation Chain (Agent A -> Agent B -> Agent C)', () {
    test('Agent A delegates to Agent B, who refers to Agent C, returning full chain resolution', () async {
      // Model for Agent A (FrontDesk)
      final modelA = MockModelClient();
      modelA.queueToolCall(
        toolName: 'escalateToTriage',
        arguments: {'issueSummary': 'SQLite database corrupted at /data/app.db'},
        thought: 'This is a technical system issue. Escalating to TriageCoordinatorAgent.',
      );
      modelA.queueText('User issue resolved: The system triage and storage specialist repaired the database.');

      // Model for Agent B (TriageCoordinator)
      final modelB = MockModelClient();
      modelB.queueToolCall(
        toolName: 'referToStorageSpecialist',
        arguments: {'databasePath': '/data/app.db'},
        thought: 'Database compaction required. Referring to StorageRepairAgent.',
      );
      modelB.queueText('Triage complete: Database was compacted and verified.');

      // Model for Agent C (StorageRepair Specialist)
      final modelC = MockModelClient();
      modelC.queueToolCall(
        toolName: 'compactDatabase',
        arguments: {'targetDb': '/data/app.db'},
        thought: 'Compacting database and freeing storage.',
      );
      modelC.queueText('Successfully repaired and compacted /data/app.db (1MB freed).');

      // Shared infrastructure
      final heap = ObjectHeap();
      final harness = HarnessApi();
      final tracer = Tracer('MultiAgentChainTest');

      final contextA = AgentContext(
        heap: heap,
        model: modelA,
        harness: harness,
        tracer: tracer,
      );

      final frontDesk = FrontDeskAgent(
        triageModel: modelB,
        specialistModel: modelC,
      )..attachContext(contextA);

      // Execute top-level goal on Agent A
      final finalResult = await frontDesk.ellipsis<String>(
        'My app crashed with a database corruption error at /data/app.db. Please fix it.',
        maxSteps: 5,
      );

      // Verify the full chain executed
      expect(finalResult, contains('User issue resolved'));
      expect(frontDesk.getState('triageResolution'), contains('Triage complete'));

      // Verify telemetry traces captured all subagent spawns
      final events = tracer.events;
      final spawnEvents = events.where((e) => e.type == TraceEventType.subagentSpawn).toList();
      expect(spawnEvents.length, equals(2));
      expect(spawnEvents[0].description, contains('TriageCoordinatorAgent'));
      expect(spawnEvents[1].description, contains('StorageRepairAgent'));
    });
  });
}
