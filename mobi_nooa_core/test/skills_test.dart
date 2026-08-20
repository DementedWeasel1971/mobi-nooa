import 'package:test/test.dart';
import 'package:mobi_nooa_core/mobi_nooa_core.dart';

void main() {
  group('nooa-skills: Two-Way Procedural Skills Subsystem (ADR 0009)', () {
    test('Skill matches query and formats Markdown prompt block', () {
      final skill = const Skill(
        id: 'test-battery-skill',
        name: 'Battery Diagnostics',
        description: 'Triage mobile battery drain.',
        tags: ['battery', 'mobile', 'power'],
        requiredTools: ['getDeviceInfo'],
        instructions: '1. Call getDeviceInfo()\n2. Check batteryLevel',
        examples: [
          {'goal': 'triage battery', 'result': 'alert sent'}
        ],
      );

      expect(skill.matchesQuery('battery drain on phone'), isTrue);
      expect(skill.matchesQuery('irrelevant query'), isFalse);
      expect(skill.matchScore('battery drain power'), greaterThan(0.5));

      final md = skill.toPromptMarkdown();
      expect(md, contains('### Skill: Battery Diagnostics (`test-battery-skill`)'));
      expect(md, contains('**Required Tools**: `getDeviceInfo`'));
      expect(md, contains('1. Call getDeviceInfo()'));

      final json = skill.toJson();
      final revived = Skill.fromJson(json);
      expect(revived.id, skill.id);
      expect(revived.name, skill.name);
      expect(revived.tags, skill.tags);
    });

    test('InMemorySkillStore finds relevant seed skills and supports persistence', () async {
      final store = InMemorySkillStore();
      final all = await store.listSkills();
      expect(all.length, greaterThanOrEqualTo(3));

      final matched = await store.findSkills('battery status warning', limit: 2);
      expect(matched, isNotEmpty);
      expect(matched.first.id, 'mobile-battery-diagnostics');

      // Save a new skill
      const newSkill = Skill(
        id: 'log-compression-skill',
        name: 'Log Compression',
        description: 'Compresses log files.',
        tags: ['logs', 'zip', 'storage'],
        instructions: '1. Find logs\n2. Compress',
      );
      await store.saveSkill(newSkill);

      final retrieved = await store.getSkill('log-compression-skill');
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Log Compression');

      final deleted = await store.deleteSkill('log-compression-skill');
      expect(deleted, isTrue);
      expect(await store.getSkill('log-compression-skill'), isNull);
    });

    test('FileSystemSkillStore saves and loads skills as JSON files', () async {
      final fs = MemoryFileSystemHarness();
      final fsStore = FileSystemSkillStore(fs, skillsDirectory: '/skills');

      final initialSkills = await fsStore.listSkills();
      expect(initialSkills, isNotEmpty);

      const customSkill = Skill(
        id: 'network-switch-skill',
        name: 'Network Fallback Switch',
        description: 'Switches from WiFi to Cellular.',
        tags: ['network', 'wifi', 'cellular'],
        instructions: '1. Check network\n2. Reconnect',
      );

      await fsStore.saveSkill(customSkill);
      expect(await fs.exists('/skills/network-switch-skill.json'), isTrue);

      final loaded = await fsStore.getSkill('network-switch-skill');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Network Fallback Switch');

      final searchResults = await fsStore.findSkills('switch wifi network');
      expect(searchResults.any((s) => s.id == 'network-switch-skill'), isTrue);

      await fsStore.deleteSkill('network-switch-skill');
      expect(await fs.exists('/skills/network-switch-skill.json'), isFalse);
    });

    test('SkillPromptEnhancer injects matched procedural recipes into prompts', () async {
      final store = InMemorySkillStore();
      final enhancer = SkillPromptEnhancer(store);

      final section = await enhancer.buildSkillsPromptSection('Inspect battery level and send alert');
      expect(section, isNotNull);
      expect(section!, contains('## Relevant Skills & Procedural Recipes'));
      expect(section, contains('Mobile Battery & Telemetry Diagnostics'));

      final enhanced = await enhancer.enhancePrompt('Base system prompt.', 'battery check');
      expect(enhanced, startsWith('Base system prompt.'));
      expect(enhanced, contains('Mobile Battery & Telemetry Diagnostics'));
    });

    test('SkillHarness enables two-way skill search, loading, and synthesis', () async {
      final harness = SkillHarness();

      final search = await harness.searchSkills('battery');
      expect(search, isNotEmpty);
      expect(search.first['id'], 'mobile-battery-diagnostics');

      final loaded = await harness.loadSkill('mobile-battery-diagnostics');
      expect(loaded, isNotNull);
      expect(loaded!['name'], 'Mobile Battery & Telemetry Diagnostics');

      // Synthesize a new skill from the agent
      final created = await harness.createSkill(
        id: 'cache-cleanup-skill',
        name: 'Cache Cleanup Procedure',
        description: 'Safely removes old cache files.',
        instructions: '1. List cache files\n2. Delete older than 7 days',
        tags: ['cache', 'cleanup', 'storage'],
        requiredTools: ['findFiles', 'deleteFile'],
      );

      expect(created['status'], 'created');
      expect(created['skillId'], 'cache-cleanup-skill');

      final all = await harness.listSkills();
      expect(all.any((s) => s['id'] == 'cache-cleanup-skill'), isTrue);
    });

    test('HarnessApi exposes SkillHarness by default', () async {
      final harnessApi = HarnessApi();
      expect(harnessApi.skill, isNotNull);

      final list = await harnessApi.skill.listSkills();
      expect(list, isNotEmpty);
    });
  });
}
