import 'nooa_agent.dart';
import '../models/model_client.dart';
import '../tools/file_editor_tool.dart';
import '../tools/shell_tool.dart';
import '../tools/code_search_tool.dart';

/// Autonomous software engineering and code repair agent combining full terminal
/// shell execution, AST/regex code searching, exact file editing, and procedural skills.
class AutonomousCodingAgent extends NooaAgent {
  final ShellHarness shellHarness;
  FileEditorTool? _fileEditor;
  CodeSearchTool? _codeSearch;

  FileEditorTool get fileEditor => _fileEditor ??= FileEditorTool(fs: context.harness.fs);
  CodeSearchTool get codeSearch => _codeSearch ??= CodeSearchTool(fs: context.harness.fs);

  AutonomousCodingAgent({
    ShellHarness? shellHarness,
    String? name,
    String? role,
    String? description,
  })  : shellHarness = shellHarness ?? LocalShellHarness(),
        super(
          name: name ?? 'AutonomousCodingAgent',
          role: role ?? 'Autonomous Software Engineer',
          description: description ??
              'Autonomous coding agent equipped with shell execution, file editing, code search, and procedural skill lookup.',
          customPromptInstructions:
              'Always view files before editing. Use unique substrings for strReplace. '
              'Search procedural skills when encountering complex build or repair tasks.',
        );

  @override
  void initAgent() {
    setState('files_modified', <String>[]);
    setState('commands_executed', <String>[]);

    registerAction(
      name: 'viewFile',
      description: 'Views a file with line numbers. Use startLine and endLine to paginate large files.',
      parameters: const [
        ToolParameter(
          name: 'path',
          type: 'string',
          description: 'Path to the file to inspect',
          required: true,
        ),
        ToolParameter(
          name: 'startLine',
          type: 'integer',
          description: '1-indexed starting line number (default: 1)',
          required: false,
        ),
        ToolParameter(
          name: 'endLine',
          type: 'integer',
          description: '1-indexed ending line number (inclusive)',
          required: false,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final path = args['path'] as String;
        final start = (args['startLine'] as num?)?.toInt() ?? 1;
        final end = (args['endLine'] as num?)?.toInt();
        final res = await fileEditor.viewFile(path, startLine: start, endLine: end);
        return res.toString();
      },
    );

    registerAction(
      name: 'strReplace',
      description: 'Replaces an exact, unique substring in a file with new content.',
      parameters: const [
        ToolParameter(
          name: 'path',
          type: 'string',
          description: 'Path to target file',
          required: true,
        ),
        ToolParameter(
          name: 'oldStr',
          type: 'string',
          description: 'Exact text to replace (must match exactly once in file)',
          required: true,
        ),
        ToolParameter(
          name: 'newStr',
          type: 'string',
          description: 'Replacement text',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final path = args['path'] as String;
        final oldStr = args['oldStr'] as String;
        final newStr = args['newStr'] as String;
        final res = await fileEditor.strReplace(path, oldStr: oldStr, newStr: newStr);

        if (res.success) {
          final modified = List<String>.from(getState('files_modified') as List? ?? [])..add(path);
          setState('files_modified', modified);
        }
        return res.toString();
      },
    );

    registerAction(
      name: 'createFile',
      description: 'Creates or completely overwrites a file at path with content.',
      parameters: const [
        ToolParameter(
          name: 'path',
          type: 'string',
          description: 'Target file path',
          required: true,
        ),
        ToolParameter(
          name: 'content',
          type: 'string',
          description: 'Full file content',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final path = args['path'] as String;
        final content = args['content'] as String;
        final res = await fileEditor.createFile(path, content: content);

        if (res.success) {
          final modified = List<String>.from(getState('files_modified') as List? ?? [])..add(path);
          setState('files_modified', modified);
        }
        return res.toString();
      },
    );

    registerAction(
      name: 'runShell',
      description: 'Executes a command in the local shell environment with working directory tracking.',
      parameters: const [
        ToolParameter(
          name: 'command',
          type: 'string',
          description: 'Command line string to execute',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final cmd = args['command'] as String;
        final history = List<String>.from(getState('commands_executed') as List? ?? [])..add(cmd);
        setState('commands_executed', history);

        final res = await shellHarness.execute(cmd);
        return res.toString();
      },
    );

    registerAction(
      name: 'grepCode',
      description: 'Searches for a regex pattern across sandboxed files.',
      parameters: const [
        ToolParameter(
          name: 'pattern',
          type: 'string',
          description: 'Regex pattern to search for',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final pattern = args['pattern'] as String;
        final matches = await codeSearch.grep(query: pattern);
        if (matches.isEmpty) return 'No matching lines found.';
        return matches.map((m) => '${m.path}:${m.lineNumber}: ${m.lineContent}').join('\n');
      },
    );

    registerAction(
      name: 'searchSkills',
      description: 'Finds procedural engineering and repair skills matching a query.',
      parameters: const [
        ToolParameter(
          name: 'query',
          type: 'string',
          description: 'Search terms',
          required: true,
        ),
      ],
      returnType: 'List<Map<String, dynamic>>',
      invoker: (args) async {
        final query = args['query'] as String;
        return await context.harness.skill.searchSkills(query);
      },
    );
  }
}
