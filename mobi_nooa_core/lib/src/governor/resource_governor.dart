import '../harness/device_harness.dart';

/// Aggregated system resource pressure level.
enum ResourcePressureLevel {
  nominal,
  moderate,
  high,
  critical,
}

/// Recommended LLM model execution tier based on device headroom.
enum ModelTier {
  onDeviceLarge,
  onDeviceStandard,
  onDeviceTiny,
  cloudOffload,
  paused,
}

/// Priority tier of an executing or queued agent task.
enum AgentPriority {
  critical,
  high,
  normal,
  low,
  background,
}

/// Computed adaptive execution budget for agent loops and models.
class ExecutionBudget {
  final ResourcePressureLevel pressureLevel;
  final ModelTier recommendedModelTier;
  final int maxConcurrentAgents;
  final int stepPacingDelayMs;
  final bool isEcoPowerRequired;
  final bool shouldTriggerHeapCompaction;
  final bool shouldPauseBackgroundAgents;
  final int availableRamMb;
  final ThermalState thermalState;
  final double batteryLevel;
  final bool isCharging;

  const ExecutionBudget({
    required this.pressureLevel,
    required this.recommendedModelTier,
    required this.maxConcurrentAgents,
    required this.stepPacingDelayMs,
    required this.isEcoPowerRequired,
    required this.shouldTriggerHeapCompaction,
    required this.shouldPauseBackgroundAgents,
    required this.availableRamMb,
    required this.thermalState,
    required this.batteryLevel,
    required this.isCharging,
  });

  /// Evaluates whether an agent with [priority] is authorized to run.
  bool canExecute(AgentPriority priority) {
    if (recommendedModelTier == ModelTier.paused) {
      return priority == AgentPriority.critical;
    }

    switch (pressureLevel) {
      case ResourcePressureLevel.nominal:
        return !shouldPauseBackgroundAgents || priority != AgentPriority.background;
      case ResourcePressureLevel.moderate:
        return priority != AgentPriority.background;
      case ResourcePressureLevel.high:
        return priority == AgentPriority.critical || priority == AgentPriority.high;
      case ResourcePressureLevel.critical:
        return priority == AgentPriority.critical;
    }
  }

  Map<String, dynamic> toJson() => {
        'pressureLevel': pressureLevel.name,
        'recommendedModelTier': recommendedModelTier.name,
        'maxConcurrentAgents': maxConcurrentAgents,
        'stepPacingDelayMs': stepPacingDelayMs,
        'isEcoPowerRequired': isEcoPowerRequired,
        'shouldTriggerHeapCompaction': shouldTriggerHeapCompaction,
        'shouldPauseBackgroundAgents': shouldPauseBackgroundAgents,
        'availableRamMb': availableRamMb,
        'thermalState': thermalState.name,
        'batteryLevel': batteryLevel,
        'isCharging': isCharging,
      };

  @override
  String toString() =>
      'ExecutionBudget(pressure: ${pressureLevel.name}, modelTier: ${recommendedModelTier.name}, '
      'concurrency: $maxConcurrentAgents, pacingMs: $stepPacingDelayMs, eco: $isEcoPowerRequired)';
}

/// Adaptive on-device resource governor that prevents device overdraw (battery, RAM, thermals)
/// and load-balances agentic AI execution in real time.
class DeviceResourceGovernor {
  final DeviceHarness harness;
  ExecutionBudget? _cachedBudget;

  DeviceResourceGovernor({required this.harness});

  /// Evaluates current device telemetry and computes an optimal [ExecutionBudget].
  Future<ExecutionBudget> evaluateBudget() async {
    final status = await harness.getStatus();

    final isSevereThermal = status.thermalState == ThermalState.severe ||
        status.thermalState == ThermalState.critical ||
        status.thermalState == ThermalState.emergency ||
        status.thermalState == ThermalState.shutdown;

    final isModerateThermal = status.thermalState == ThermalState.serious;

    final isLowRam = status.availableRamMb < 512 || status.isLowRamDevice;
    final isModerateRam = status.availableRamMb < 1500;

    final isLowBattery = status.batteryLevel < 0.15 && !status.isCharging;
    final isModerateBattery = status.batteryLevel < 0.25 && !status.isCharging;

    // Calculate aggregated pressure
    ResourcePressureLevel pressure;
    if (isSevereThermal || isLowRam || status.thermalState == ThermalState.shutdown) {
      pressure = isLowRam ? ResourcePressureLevel.critical : ResourcePressureLevel.high;
    } else if (isModerateThermal || isModerateRam || isLowBattery) {
      pressure = ResourcePressureLevel.moderate;
    } else {
      pressure = ResourcePressureLevel.nominal;
    }

    // Determine model tier & concurrency
    ModelTier tier;
    int maxConcurrent;
    int pacingDelayMs = 0;

    if (status.thermalState == ThermalState.shutdown) {
      tier = ModelTier.paused;
      maxConcurrent = 0;
      pacingDelayMs = 1000;
    } else if (isSevereThermal) {
      tier = ModelTier.cloudOffload; // Offload computation to cool device
      maxConcurrent = 1;
      pacingDelayMs = 300;
    } else if (isLowRam) {
      tier = ModelTier.onDeviceTiny;
      maxConcurrent = 1;
      pacingDelayMs = 150;
    } else if (isModerateThermal || isModerateBattery) {
      tier = ModelTier.onDeviceStandard;
      maxConcurrent = 2;
      pacingDelayMs = 50;
    } else {
      tier = ModelTier.onDeviceStandard;
      maxConcurrent = 4;
      pacingDelayMs = 0;
    }

    final budget = ExecutionBudget(
      pressureLevel: pressure,
      recommendedModelTier: tier,
      maxConcurrentAgents: maxConcurrent,
      stepPacingDelayMs: pacingDelayMs,
      isEcoPowerRequired: isLowBattery || status.isLowPowerMode,
      shouldTriggerHeapCompaction: isLowRam,
      shouldPauseBackgroundAgents: isLowBattery || isLowRam || isSevereThermal,
      availableRamMb: status.availableRamMb,
      thermalState: status.thermalState,
      batteryLevel: status.batteryLevel,
      isCharging: status.isCharging,
    );

    _cachedBudget = budget;
    return budget;
  }

  /// Returns the most recently computed budget, or evaluates immediately if absent.
  Future<ExecutionBudget> getCurrentBudget() async {
    return _cachedBudget ?? await evaluateBudget();
  }
}
