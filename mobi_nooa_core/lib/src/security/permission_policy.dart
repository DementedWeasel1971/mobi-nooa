/// Tiers of authorization permissions in the agent runtime.
enum PermissionTier {
  /// Allowed unconditionally without interrupting the agent loop.
  allow,

  /// Requires explicit user/app approval callback before proceeding.
  prompt,

  /// Denied unconditionally; action invocation will fail immediately.
  deny,

  /// Quarantined/sandboxed simulation mode.
  quarantine,
}

/// The evaluated decision for an action execution request.
class PermissionDecision {
  final PermissionTier tier;
  final bool isAllowed;
  final String reason;
  final bool requiresApproval;

  const PermissionDecision({
    required this.tier,
    required this.isAllowed,
    required this.reason,
    required this.requiresApproval,
  });

  factory PermissionDecision.allow([String reason = 'Allowed by policy']) =>
      PermissionDecision(
        tier: PermissionTier.allow,
        isAllowed: true,
        reason: reason,
        requiresApproval: false,
      );

  factory PermissionDecision.prompt([String reason = 'Action requires user authorization']) =>
      PermissionDecision(
        tier: PermissionTier.prompt,
        isAllowed: false,
        reason: reason,
        requiresApproval: true,
      );

  factory PermissionDecision.deny([String reason = 'Action is forbidden by policy']) =>
      PermissionDecision(
        tier: PermissionTier.deny,
        isAllowed: false,
        reason: reason,
        requiresApproval: false,
      );

  factory PermissionDecision.quarantine([String reason = 'Action diverted to quarantine sandbox']) =>
      PermissionDecision(
        tier: PermissionTier.quarantine,
        isAllowed: true,
        reason: reason,
        requiresApproval: false,
      );
}

/// A rule governing permission evaluation for specific actions or arguments.
class PermissionRule {
  final String actionPattern;
  final PermissionTier tier;
  final String reason;
  final bool Function(String action, Map<String, dynamic> arguments)? condition;

  const PermissionRule({
    required this.actionPattern,
    required this.tier,
    this.reason = '',
    this.condition,
  });

  bool matches(String action, Map<String, dynamic> arguments) {
    bool nameMatches;
    if (actionPattern == '*' || actionPattern == action) {
      nameMatches = true;
    } else if (actionPattern.endsWith('*')) {
      final prefix = actionPattern.substring(0, actionPattern.length - 1);
      nameMatches = action.startsWith(prefix);
    } else {
      nameMatches = RegExp('^$actionPattern\$').hasMatch(action);
    }

    if (!nameMatches) return false;
    if (condition != null) {
      return condition!(action, arguments);
    }
    return true;
  }
}

/// Comprehensive permission policy defining agent authorization constraints.
class PermissionPolicy {
  final String name;
  final PermissionTier defaultTier;
  final List<PermissionRule> rules;

  const PermissionPolicy({
    this.name = 'default',
    this.defaultTier = PermissionTier.prompt,
    this.rules = const [],
  });

  /// Evaluates an action execution request against policy rules in order.
  PermissionDecision evaluate(String action, Map<String, dynamic> arguments) {
    for (final rule in rules) {
      if (rule.matches(action, arguments)) {
        final reason = rule.reason.isNotEmpty ? rule.reason : 'Matched rule for ${rule.actionPattern}';
        switch (rule.tier) {
          case PermissionTier.allow:
            return PermissionDecision.allow(reason);
          case PermissionTier.prompt:
            return PermissionDecision.prompt(reason);
          case PermissionTier.deny:
            return PermissionDecision.deny(reason);
          case PermissionTier.quarantine:
            return PermissionDecision.quarantine(reason);
        }
      }
    }

    // Default fallback
    switch (defaultTier) {
      case PermissionTier.allow:
        return PermissionDecision.allow('Default fallback allow');
      case PermissionTier.prompt:
        return PermissionDecision.prompt('Default fallback requires approval');
      case PermissionTier.deny:
        return PermissionDecision.deny('Default fallback deny');
      case PermissionTier.quarantine:
        return PermissionDecision.quarantine('Default fallback quarantine');
    }
  }

  /// Default mobile profile: safe read tools are auto-allowed, mutating tools require prompt.
  factory PermissionPolicy.defaultMobile() {
    return const PermissionPolicy(
      name: 'defaultMobile',
      defaultTier: PermissionTier.prompt,
      rules: [
        // Read-only tools & telemetry
        PermissionRule(
          actionPattern: 'get*',
          tier: PermissionTier.allow,
          reason: 'Read-only telemetry and device info',
        ),
        PermissionRule(
          actionPattern: 'viewFile',
          tier: PermissionTier.allow,
          reason: 'Safe file reading',
        ),
        PermissionRule(
          actionPattern: 'findFiles',
          tier: PermissionTier.allow,
          reason: 'Safe directory search',
        ),
        PermissionRule(
          actionPattern: 'grep',
          tier: PermissionTier.allow,
          reason: 'Safe regex text search',
        ),
        PermissionRule(
          actionPattern: 'extractSymbols',
          tier: PermissionTier.allow,
          reason: 'Safe symbol extraction',
        ),
        PermissionRule(
          actionPattern: 'searchSkills',
          tier: PermissionTier.allow,
          reason: 'Safe skill library query',
        ),
        PermissionRule(
          actionPattern: 'loadSkill',
          tier: PermissionTier.allow,
          reason: 'Safe skill inspection',
        ),
        PermissionRule(
          actionPattern: 'querySql',
          tier: PermissionTier.allow,
          reason: 'Read-only database query',
        ),

        // Mutating actions require explicit confirmation on mobile
        PermissionRule(
          actionPattern: 'createFile',
          tier: PermissionTier.prompt,
          reason: 'Filesystem mutation requires user authorization',
        ),
        PermissionRule(
          actionPattern: 'writeFile',
          tier: PermissionTier.prompt,
          reason: 'Filesystem mutation requires user authorization',
        ),
        PermissionRule(
          actionPattern: 'strReplace',
          tier: PermissionTier.prompt,
          reason: 'Source code modification requires user authorization',
        ),
        PermissionRule(
          actionPattern: 'execShell',
          tier: PermissionTier.prompt,
          reason: 'Shell command execution requires user authorization',
        ),
        PermissionRule(
          actionPattern: 'sendNotification',
          tier: PermissionTier.prompt,
          reason: 'Sending system notification requires user authorization',
        ),
        PermissionRule(
          actionPattern: 'vibrate',
          tier: PermissionTier.allow,
          reason: 'Haptic feedback is non-destructive',
        ),
        PermissionRule(
          actionPattern: 'learnSkill',
          tier: PermissionTier.prompt,
          reason: 'Saving new skill recipe requires confirmation',
        ),
      ],
    );
  }

  /// Strict audit mode: all write/mutating actions are forbidden.
  factory PermissionPolicy.strictAudit() {
    return const PermissionPolicy(
      name: 'strictAudit',
      defaultTier: PermissionTier.deny,
      rules: [
        PermissionRule(actionPattern: 'get*', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'viewFile', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'findFiles', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'grep', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'extractSymbols', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'searchSkills', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'loadSkill', tier: PermissionTier.allow),
        PermissionRule(actionPattern: 'querySql', tier: PermissionTier.allow),
      ],
    );
  }

  /// Permissive policy: all actions allowed unconditionally (e.g. for sandboxed test runners).
  factory PermissionPolicy.permissive() {
    return const PermissionPolicy(
      name: 'permissive',
      defaultTier: PermissionTier.allow,
      rules: [],
    );
  }
}
