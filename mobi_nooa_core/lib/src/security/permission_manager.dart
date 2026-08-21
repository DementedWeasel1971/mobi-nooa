import 'dart:async';
import 'permission_policy.dart';

/// Exception thrown when an agent action is rejected by security policy or the user.
class SecurityException implements Exception {
  final String message;
  final String actionName;
  final Map<String, dynamic> arguments;

  SecurityException(
    this.message, {
    this.actionName = '',
    this.arguments = const {},
  });

  @override
  String toString() => 'SecurityException: $message ($actionName)';
}

/// Request payload delivered to an [ApprovalCallback] when an action requires confirmation.
class ApprovalRequest {
  final String actionName;
  final Map<String, dynamic> arguments;
  final String? rationale;
  final PermissionTier tier;
  final DateTime timestamp;

  ApprovalRequest({
    required this.actionName,
    required this.arguments,
    this.rationale,
    this.tier = PermissionTier.prompt,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'actionName': actionName,
        'arguments': arguments,
        if (rationale != null) 'rationale': rationale,
        'tier': tier.name,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Callback signature for requesting user or host app confirmation before executing an action.
typedef ApprovalCallback = Future<bool> Function(ApprovalRequest request);

/// Central permission enforcement manager for the agent runtime.
///
/// Decouples authorization and permission evaluation from individual tool
/// implementations (inspired by DeepSeek Harness / Cordis security design).
class PermissionManager {
  final PermissionPolicy policy;
  final ApprovalCallback? approvalHandler;

  PermissionManager({
    PermissionPolicy? policy,
    this.approvalHandler,
  }) : policy = policy ?? PermissionPolicy.defaultMobile();

  /// Evaluates an action execution request and resolves user approval if required.
  Future<PermissionDecision> checkPermission(
    String actionName,
    Map<String, dynamic> arguments, {
    String? rationale,
  }) async {
    final decision = policy.evaluate(actionName, arguments);

    if (decision.tier == PermissionTier.allow || decision.tier == PermissionTier.quarantine) {
      return decision;
    }

    if (decision.tier == PermissionTier.deny) {
      return decision;
    }

    // Tier is prompt -> invoke approvalHandler if available
    if (decision.tier == PermissionTier.prompt) {
      if (approvalHandler != null) {
        final request = ApprovalRequest(
          actionName: actionName,
          arguments: arguments,
          rationale: rationale ?? decision.reason,
          tier: decision.tier,
        );

        final approved = await approvalHandler!(request);
        if (approved) {
          return PermissionDecision.allow('Approved by user authorization callback');
        } else {
          return PermissionDecision.deny('Rejected by user authorization callback');
        }
      }

      // Without an explicit approval handler in autonomous mode, prompt-tier actions are permitted
      return PermissionDecision.allow('Auto-approved prompt action in autonomous execution');
    }

    return decision;
  }

  /// Authorizes the action or throws a [SecurityException] if forbidden or rejected.
  Future<void> authorize(
    String actionName,
    Map<String, dynamic> arguments, {
    String? rationale,
  }) async {
    final decision = await checkPermission(
      actionName,
      arguments,
      rationale: rationale,
    );

    if (!decision.isAllowed) {
      throw SecurityException(
        decision.reason,
        actionName: actionName,
        arguments: arguments,
      );
    }
  }
}
