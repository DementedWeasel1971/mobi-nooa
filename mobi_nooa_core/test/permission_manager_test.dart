import 'package:test/test.dart';
import 'package:mobi_nooa_core/src/security/permission_policy.dart';
import 'package:mobi_nooa_core/src/security/permission_manager.dart';

void main() {
  group('PermissionPolicy & PermissionManager (TDD)', () {
    test('defaultMobile policy auto-allows read tools and prompts on write tools', () {
      final policy = PermissionPolicy.defaultMobile();

      final readDecision = policy.evaluate('getDeviceInfo', {});
      expect(readDecision.tier, equals(PermissionTier.allow));
      expect(readDecision.isAllowed, isTrue);
      expect(readDecision.requiresApproval, isFalse);

      final searchDecision = policy.evaluate('searchSkills', {'query': 'battery'});
      expect(searchDecision.tier, equals(PermissionTier.allow));

      final writeDecision = policy.evaluate('createFile', {'path': '/data/test.txt'});
      expect(writeDecision.tier, equals(PermissionTier.prompt));
      expect(writeDecision.requiresApproval, isTrue);

      final shellDecision = policy.evaluate('execShell', {'command': 'ls -la'});
      expect(shellDecision.tier, equals(PermissionTier.prompt));
    });

    test('strictAudit policy denies all mutating actions', () {
      final policy = PermissionPolicy.strictAudit();

      final readDecision = policy.evaluate('viewFile', {'path': 'main.dart'});
      expect(readDecision.tier, equals(PermissionTier.allow));

      final writeDecision = policy.evaluate('strReplace', {'path': 'main.dart'});
      expect(writeDecision.tier, equals(PermissionTier.deny));
      expect(writeDecision.isAllowed, isFalse);

      final shellDecision = policy.evaluate('execShell', {'command': 'rm -rf /'});
      expect(shellDecision.tier, equals(PermissionTier.deny));
      expect(shellDecision.isAllowed, isFalse);
    });

    test('PermissionManager approves prompt actions when ApprovalCallback returns true', () async {
      var approvalPrompted = false;
      final manager = PermissionManager(
        policy: PermissionPolicy.defaultMobile(),
        approvalHandler: (request) async {
          approvalPrompted = true;
          expect(request.actionName, equals('createFile'));
          expect(request.arguments['path'], equals('output.json'));
          return true;
        },
      );

      final decision = await manager.checkPermission('createFile', {'path': 'output.json'});
      expect(decision.isAllowed, isTrue);
      expect(approvalPrompted, isTrue);
    });

    test('PermissionManager throws SecurityException when action is denied or rejected', () async {
      final manager = PermissionManager(
        policy: PermissionPolicy.defaultMobile(),
        approvalHandler: (request) async => false, // User denies in UI
      );

      expect(
        () async => await manager.authorize('createFile', {'path': 'malicious.apk'}),
        throwsA(isA<SecurityException>()),
      );
    });

    test('custom rule matches pattern and argument condition', () {
      final policy = PermissionPolicy(
        name: 'custom_policy',
        rules: [
          PermissionRule(
            actionPattern: 'execShell',
            tier: PermissionTier.deny,
            condition: (action, args) {
              final cmd = args['command']?.toString() ?? '';
              return cmd.contains('rm -rf') || cmd.contains(':(){ :|:& };:');
            },
            reason: 'Dangerous destructive command pattern blocked',
          ),
          PermissionRule(
            actionPattern: 'execShell',
            tier: PermissionTier.prompt,
            reason: 'Regular shell execution requires approval',
          ),
        ],
      );

      final dangerous = policy.evaluate('execShell', {'command': 'rm -rf /data'});
      expect(dangerous.tier, equals(PermissionTier.deny));
      expect(dangerous.reason, contains('Dangerous destructive command'));

      final benign = policy.evaluate('execShell', {'command': 'ls'});
      expect(benign.tier, equals(PermissionTier.prompt));
    });
  });
}
