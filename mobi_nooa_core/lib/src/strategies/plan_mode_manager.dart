import 'dart:async';

/// Execution status of an individual step in a plan.
enum PlanStepStatus {
  pending,
  inProgress,
  completed,
  skipped,
  failed,
}

/// A structured step within an agent's execution plan.
class PlanStep {
  final String id;
  final String title;
  final String description;
  final List<String> targetFiles;
  final String? diffPreview;
  final bool requiresApproval;
  PlanStepStatus status;
  dynamic output;
  String? error;

  PlanStep({
    required this.id,
    required this.title,
    required this.description,
    this.targetFiles = const [],
    this.diffPreview,
    this.requiresApproval = false,
    this.status = PlanStepStatus.pending,
    this.output,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetFiles': targetFiles,
        if (diffPreview != null) 'diffPreview': diffPreview,
        'requiresApproval': requiresApproval,
        'status': status.name,
        if (output != null) 'output': output?.toString(),
        if (error != null) 'error': error,
      };

  @override
  String toString() => '[$id] (${status.name}) $title: $description';
}

/// A complete structured execution plan drafted by the agent.
class ExecutionPlan {
  final String planId;
  final String goal;
  final List<PlanStep> steps;
  final DateTime createdAt;
  bool isApproved;

  ExecutionPlan({
    required this.planId,
    required this.goal,
    required this.steps,
    DateTime? createdAt,
    this.isApproved = false,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalSteps => steps.length;
  int get completedSteps =>
      steps.where((s) => s.status == PlanStepStatus.completed).length;
  bool get isComplete =>
      steps.every((s) => s.status == PlanStepStatus.completed || s.status == PlanStepStatus.skipped);

  double get progressPercentage =>
      totalSteps > 0 ? (completedSteps / totalSteps) * 100.0 : 0.0;

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'goal': goal,
        'totalSteps': totalSteps,
        'completedSteps': completedSteps,
        'progressPercentage': progressPercentage,
        'isApproved': isApproved,
        'createdAt': createdAt.toIso8601String(),
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('📋 Execution Plan: $goal (Progress: ${progressPercentage.toStringAsFixed(0)}%)');
    for (final step in steps) {
      final mark = step.status == PlanStepStatus.completed
          ? '✓'
          : (step.status == PlanStepStatus.inProgress ? '▶' : '○');
      buffer.writeln('  $mark [${step.id}] ${step.title}');
    }
    return buffer.toString().trim();
  }
}

/// First-Class Plan Mode Manager.
///
/// Implements Grok Build's "Plan -> Review -> Approve -> Execute with Diffs" workflow.
/// Allows complex agent workflows to generate explicit structured plans with pre-flight
/// diff previews before any mutating actions are executed.
class PlanModeManager {
  ExecutionPlan? _currentPlan;
  final Future<bool> Function(PlanStep step)? onApprovalRequired;

  PlanModeManager({this.onApprovalRequired});

  ExecutionPlan? get currentPlan => _currentPlan;

  /// Creates a new execution plan from a list of steps.
  ExecutionPlan createPlan({
    required String goal,
    required List<PlanStep> steps,
    String? planId,
  }) {
    final plan = ExecutionPlan(
      planId: planId ?? 'plan_${DateTime.now().millisecondsSinceEpoch}',
      goal: goal,
      steps: steps,
    );
    _currentPlan = plan;
    return plan;
  }

  /// Marks the entire plan as approved.
  void approvePlan() {
    if (_currentPlan != null) {
      _currentPlan!.isApproved = true;
    }
  }

  /// Executes a plan step with pre-approval verification.
  Future<bool> verifyStepExecution(PlanStep step) async {
    if (step.requiresApproval && onApprovalRequired != null) {
      final approved = await onApprovalRequired!(step);
      if (!approved) {
        step.status = PlanStepStatus.skipped;
        return false;
      }
    }
    step.status = PlanStepStatus.inProgress;
    return true;
  }

  /// Marks a step as completed with its resulting output.
  void markStepCompleted(String stepId, [dynamic output]) {
    final step = _currentPlan?.steps.firstWhere((s) => s.id == stepId);
    if (step != null) {
      step.status = PlanStepStatus.completed;
      step.output = output;
    }
  }

  /// Marks a step as failed with an error message.
  void markStepFailed(String stepId, String error) {
    final step = _currentPlan?.steps.firstWhere((s) => s.id == stepId);
    if (step != null) {
      step.status = PlanStepStatus.failed;
      step.error = error;
    }
  }
}
