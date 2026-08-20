import 'package:mobi_nooa_core/mobi_nooa_core.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceResourceGovernor & AgentLoadBalancer Suite (TDD)', () {
    late DefaultDeviceHarness harness;
    late DeviceResourceGovernor governor;

    setUp(() {
      harness = DefaultDeviceHarness(
        initialStatus: const DeviceStatus(
          batteryLevel: 0.85,
          isCharging: false,
          availableRamMb: 4096,
          totalRamMb: 8192,
          thermalState: ThermalState.nominal,
          cpuLoadFraction: 0.15,
          networkType: 'wifi',
        ),
      );
      governor = DeviceResourceGovernor(harness: harness);
    });

    test('Assesses nominal device state and allows full on-device concurrency',
        () async {
      final budget = await governor.evaluateBudget();

      expect(budget.pressureLevel, equals(ResourcePressureLevel.nominal));
      expect(budget.recommendedModelTier, equals(ModelTier.onDeviceStandard));
      expect(budget.maxConcurrentAgents, greaterThanOrEqualTo(3));
      expect(budget.stepPacingDelayMs, equals(0));
      expect(budget.canExecute(AgentPriority.background), isTrue);
    });

    test('Detects severe thermal pressure and applies throttling and cloud offload',
        () async {
      harness.updateStatus(const DeviceStatus(
        batteryLevel: 0.60,
        isCharging: false,
        availableRamMb: 3500,
        totalRamMb: 8192,
        thermalState: ThermalState.severe,
        cpuLoadFraction: 0.88,
        networkType: 'wifi',
      ));

      final budget = await governor.evaluateBudget();

      expect(budget.pressureLevel, equals(ResourcePressureLevel.high));
      // Under high thermal stress, recommends cloud offload or quantized tiny model to cool CPU/NPU
      expect(budget.recommendedModelTier, equals(ModelTier.cloudOffload));
      expect(budget.maxConcurrentAgents, equals(1));
      expect(budget.stepPacingDelayMs, greaterThanOrEqualTo(250));
      expect(budget.canExecute(AgentPriority.low), isFalse);
      expect(budget.canExecute(AgentPriority.high), isTrue);
    });

    test('Detects critical low RAM and halts low-priority tasks with heap compaction trigger',
        () async {
      harness.updateStatus(const DeviceStatus(
        batteryLevel: 0.50,
        isCharging: false,
        availableRamMb: 450, // Less than 512MB free
        totalRamMb: 4096,
        isLowRamDevice: true,
        thermalState: ThermalState.fair,
      ));

      final budget = await governor.evaluateBudget();

      expect(budget.pressureLevel, equals(ResourcePressureLevel.critical));
      expect(budget.shouldTriggerHeapCompaction, isTrue);
      expect(budget.canExecute(AgentPriority.background), isFalse);
      expect(budget.shouldPauseBackgroundAgents, isTrue);
    });

    test('Detects low battery on unmetered/metered network and recommends eco mode',
        () async {
      harness.updateStatus(const DeviceStatus(
        batteryLevel: 0.12, // 12% battery
        isCharging: false,
        isLowPowerMode: true,
        networkType: 'cellular',
      ));

      final budget = await governor.evaluateBudget();

      expect(budget.isEcoPowerRequired, isTrue);
      expect(budget.shouldPauseBackgroundAgents, isTrue);
      expect(budget.canExecute(AgentPriority.high), isTrue);
    });

    test('AutonomousDeviceAgent evaluates resource budget and manages load balancing',
        () async {
      final mockModel = MockModelClient();

      // Step 1: Model inspects device resource headroom
      mockModel.queueToolCall(
        toolName: 'assessResourceHeadroom',
        arguments: const {},
        thought: 'Assessing RAM, thermal status, and battery budget.',
      );

      // Step 2: Model balances workload by applying pacing policy
      mockModel.queueToolCall(
        toolName: 'applyGovernorPolicy',
        arguments: const {
          'targetModelTier': 'onDeviceStandard',
          'maxConcurrent': 2,
          'pacingDelayMs': 100
        },
        thought: 'Configuring active execution governor.',
      );

      mockModel.queueText(
          'Load balancer configured: System nominal with 4GB free RAM. Max concurrency set to 2.');

      final agent = Quickstart.createAgent(
        () => AutonomousDeviceAgent(),
        model: mockModel,
      );

      final result = await agent.ellipsis<String>(
        'Optimize agent resource allocation based on device health',
        maxSteps: 4,
      );

      expect(result, contains('Load balancer configured'));
      expect(agent.getState('governor_policy'), isNotNull);
    });
  });
}
