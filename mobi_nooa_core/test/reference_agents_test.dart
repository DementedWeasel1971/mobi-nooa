import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('mobi-nooa Reference Agents & Harness Architecture Suite', () {
    test('AutonomousDeviceAgent registers actions, mutates state, and interacts with skills', () async {
      final agent = AutonomousDeviceAgent();
      final heap = ObjectHeap();
      final tracer = Tracer('AutonomousDeviceAgent');
      final harness = HarnessApi();
      final context = AgentContext(heap: heap, model: MockModelClient(), tracer: tracer, harness: harness);
      agent.attachContext(context);

      expect(agent.name, 'AutonomousDeviceAgent');
      expect(agent.role, 'Autonomous Mobile System & Triage Agent');

      // 1. Test getDeviceInfo
      final devAction = agent.findAction('getDeviceInfo');
      expect(devAction, isNotNull);
      final devResult = await devAction!.invoker({}) as Map<String, dynamic>;
      expect(devResult['batteryLevel'], isNotNull);
      expect((agent.getState('telemetry_history') as List).length, 1);

      // 2. Test sendNotification & vibrate
      final notifAction = agent.findAction('sendNotification');
      expect(notifAction, isNotNull);
      await notifAction!.invoker({'title': 'Thermal Alert', 'body': 'Battery temp high'});
      expect((agent.getState('alerts') as List).length, 1);

      final vibAction = agent.findAction('vibrate');
      expect(vibAction, isNotNull);
      final vibResult = await vibAction!.invoker({'durationMs': 150});
      expect(vibResult, isTrue);

      // 3. Test skill search & synthesis
      final searchSkillAction = agent.findAction('searchSkills');
      expect(searchSkillAction, isNotNull);
      final searchRes = await searchSkillAction!.invoker({'query': 'battery'}) as List;
      expect(searchRes, isNotEmpty);

      final learnAction = agent.findAction('learnSkill');
      expect(learnAction, isNotNull);
      final learnRes = await learnAction!.invoker({
        'id': 'custom-thermal-throttle',
        'name': 'Thermal Throttling Recovery',
        'description': 'Procedure for reducing screen brightness when hot',
        'instructions': '1. Check temp\n2. Lower brightness',
      }) as Map<String, dynamic>;
      expect(learnRes['status'], 'created');
      expect(learnRes['skillId'], 'custom-thermal-throttle');

      // Verify skill is now discoverable
      final newlyFound = await searchSkillAction.invoker({'query': 'thermal'}) as List;
      expect(newlyFound.any((s) => (s as Map)['id'] == 'custom-thermal-throttle'), isTrue);
    });

    test('DataAnalystAgent allocates #ref handles into ObjectHeap and computes stats', () async {
      final agent = DataAnalystAgent();
      final heap = ObjectHeap();
      final tracer = Tracer('DataAnalystAgent');
      final harness = HarnessApi();
      final context = AgentContext(heap: heap, model: MockModelClient(), tracer: tracer, harness: harness);
      agent.attachContext(context);

      // 1. Generate dataset into heap
      final loadAction = agent.findAction('loadSampleDataset');
      expect(loadAction, isNotNull);
      final handle = await loadAction!.invoker({'rowCount': 50}) as String;
      expect(handle, startsWith('#ref_'));

      // 2. Compute summary over pass-by-reference handle
      final summaryAction = agent.findAction('computeSummary');
      expect(summaryAction, isNotNull);
      final summary = await summaryAction!.invoker({'handle': handle}) as Map<String, dynamic>;
      expect(summary['rowCount'], 50);
      expect(summary['avgCpu'], isNotNull);
      expect(summary['avgRamMb'], isNotNull);

      // 3. Filter dataset into a new handle
      final filterAction = agent.findAction('filterDataset');
      expect(filterAction, isNotNull);
      final filteredHandle = await filterAction!.invoker({
        'handle': handle,
        'column': 'network',
        'value': 'wifi',
      }) as String;
      expect(filteredHandle, startsWith('#ref_'));
      expect(filteredHandle, isNot(equals(handle)));

      final filteredData = heap.resolveHandleOrValue(filteredHandle) as List;
      expect(filteredData, isNotEmpty);
      expect(filteredData.every((r) => (r as Map)['network'] == 'wifi'), isTrue);
    });

    test('AutonomousCodingAgent inspects files, replaces substrings, and executes shell', () async {
      final agent = AutonomousCodingAgent();
      final fs = MemoryFileSystemHarness({'/workspace/main.dart': 'void main() {\n  print("hello");\n}\n'});
      final harness = HarnessApi(fs: fs);
      final heap = ObjectHeap();
      final tracer = Tracer('AutonomousCodingAgent');
      final context = AgentContext(heap: heap, model: MockModelClient(), tracer: tracer, harness: harness);
      agent.attachContext(context);

      // 1. View file
      final viewAction = agent.findAction('viewFile');
      expect(viewAction, isNotNull);
      final viewOut = await viewAction!.invoker({'path': '/workspace/main.dart'}) as String;
      expect(viewOut, contains('print("hello")'));

      // 2. Exact string replace
      final replaceAction = agent.findAction('strReplace');
      expect(replaceAction, isNotNull);
      await replaceAction!.invoker({
        'path': '/workspace/main.dart',
        'oldStr': 'print("hello");',
        'newStr': 'print("mobi-nooa");',
      });
      final updated = await fs.readFile('/workspace/main.dart');
      expect(updated, contains('print("mobi-nooa");'));

      // 3. Search skills for coding workflows
      final skillAction = agent.findAction('searchSkills');
      expect(skillAction, isNotNull);
      final matched = await skillAction!.invoker({'query': 'strReplace'}) as List;
      expect(matched, isNotEmpty);
    });

    test('AgentBridgeDispatcher.withDefaults includes all 5 reference agents and runs loops', () async {
      final dispatcher = AgentBridgeDispatcher.withDefaults();
      final names = dispatcher.registeredAgentNames;

      expect(names, containsAll([
        'GeneralMobileAgent',
        'BenchAgent',
        'AutonomousDeviceAgent',
        'DataAnalystAgent',
        'AutonomousCodingAgent',
      ]));

      // Run an agent loop with AutonomousDeviceAgent
      final response = await dispatcher.handle({
        'action': 'runAgentLoop',
        'agentName': 'AutonomousDeviceAgent',
        'goal': 'Check battery level and status',
        'model': {'provider': 'mock'},
        'maxSteps': 3,
      });

      expect(response['result'], isNotNull);
      expect(response['agentName'], 'AutonomousDeviceAgent');
      expect((response['trace'] as List).length, greaterThanOrEqualTo(1));
    });
  });
}
