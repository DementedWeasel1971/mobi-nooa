import 'nooa_agent.dart';
import '../models/model_client.dart';
import '../tools/file_editor_tool.dart';
import '../tools/shell_tool.dart';
import '../tools/code_search_tool.dart';

/// The official BenchAgent architecture from NVIDIA Object-Oriented Agents (arXiv:2607.20709).
///
/// Designed for benchmark-agnostic evaluation across SWE-bench, Terminal-Bench, and CyberGym.
/// Combines shell execution, file editing, and repository navigation with explicit state
/// and pass-by-reference object heap management.
class BenchAgent extends NooaAgent {
  final ShellHarness shellHarness;
  FileEditorTool? _fileEditor;
  CodeSearchTool? _codeSearch;

  FileEditorTool get fileEditor => _fileEditor ??= FileEditorTool(fs: context.harness.fs);
  CodeSearchTool get codeSearch => _codeSearch ??= CodeSearchTool(fs: context.harness.fs);

  BenchAgent({
    ShellHarness? shellHarness,
  })  : shellHarness = shellHarness ?? LocalShellHarness(),
        super(
          name: 'BenchAgent',
          role: 'Autonomous Software Engineering & Benchmark Agent',
          description:
              'Solves software engineering tasks by inspecting codebases, editing files, and running shell commands.',
          customPromptInstructions:
              'You are an expert autonomous software engineer. '
              'Explore the repository, locate the relevant code symbols and files, '
              'reproduce issues using shell commands, apply precise edits using strReplace, '
              'and verify your solution before finishing.',
        );

  @override
  void initAgent() {
    setState('editedFiles', <String>[]);
    setState('commandHistory', <String>[]);
    setState('workingDirectory', shellHarness.workingDirectory);

    // 1. Shell Command Execution
    registerAction(
      name: 'runShell',
      description: 'Executes a command in the shell environment and returns stdout/stderr.',
      parameters: const [
        ToolParameter(
          name: 'command',
          type: 'string',
          description: 'The exact command line string to run',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final cmd = args['command'] as String;
        final history = List<String>.from(getState('commandHistory') as List? ?? [])..add(cmd);
        setState('commandHistory', history);

        final result = await shellHarness.execute(cmd);
        setState('workingDirectory', shellHarness.workingDirectory);

        return result.toString();
      },
    );

    // 2. View File
    registerAction(
      name: 'viewFile',
      description: 'Reads contents of a file with line numbers and optional slicing.',
      parameters: const [
        ToolParameter(
          name: 'path',
          type: 'string',
          description: 'Path of the file to view',
          required: true,
        ),
        ToolParameter(
          name: 'startLine',
          type: 'integer',
          description: 'Start line number (1-indexed)',
          required: false,
        ),
        ToolParameter(
          name: 'endLine',
          type: 'integer',
          description: 'End line number (inclusive)',
          required: false,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final path = args['path'] as String;
        final startLine = (args['startLine'] as num?)?.toInt() ?? 1;
        final endLine = (args['endLine'] as num?)?.toInt();
        final result = await fileEditor.viewFile(path, startLine: startLine, endLine: endLine);
        return result.toString();
      },
    );

    // 3. String Replace Editor
    registerAction(
      name: 'strReplace',
      description: 'Replaces unique substring target with new text in specified file.',
      parameters: const [
        ToolParameter(
          name: 'path',
          type: 'string',
          description: 'Path of the file to edit',
          required: true,
        ),
        ToolParameter(
          name: 'oldStr',
          type: 'string',
          description: 'Exact unique substring to replace',
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

        final result = await fileEditor.strReplace(path, oldStr: oldStr, newStr: newStr);

        if (result.success) {
          final edited = List<String>.from(getState('editedFiles') as List? ?? []);
          if (!edited.contains(path)) {
            edited.add(path);
            setState('editedFiles', edited);
          }
        }

        return result.toString();
      },
    );

    // 4. Create File
    registerAction(
      name: 'createFile',
      description: 'Creates a new file or overwrites an existing file with content.',
      parameters: const [
        ToolParameter(
          name: 'path',
          type: 'string',
          description: 'Path to create',
          required: true,
        ),
        ToolParameter(
          name: 'content',
          type: 'string',
          description: 'File content',
          required: true,
        ),
      ],
      returnType: 'String',
      invoker: (args) async {
        final path = args['path'] as String;
        final content = args['content'] as String;
        final result = await fileEditor.createFile(path, content: content);

        if (result.success) {
          final edited = List<String>.from(getState('editedFiles') as List? ?? []);
          if (!edited.contains(path)) {
            edited.add(path);
            setState('editedFiles', edited);
          }
        }

        return result.toString();
      },
    );

    // 5. Code Search & Grep
    registerAction(
      name: 'grepCode',
      description: 'Searches codebase for pattern matches across files.',
      parameters: const [
        ToolParameter(
          name: 'query',
          type: 'string',
          description: 'Regex or literal string to search for',
          required: true,
        ),
        ToolParameter(
          name: 'extension',
          type: 'string',
          description: 'Optional file extension filter (e.g. dart, py, kt)',
          required: false,
        ),
      ],
      returnType: 'List<String>',
      invoker: (args) async {
        final query = args['query'] as String;
        final ext = args['extension'] as String?;
        final matches = await codeSearch.grep(query: query, extension: ext);
        return matches.map((m) => m.toString()).toList();
      },
    );

    // 6. List Code Symbols
    registerAction(
      name: 'listSymbols',
      description: 'Extracts classes, functions, and symbols from files.',
      parameters: const [
        ToolParameter(
          name: 'extension',
          type: 'string',
          description: 'File extension filter (e.g. dart, kt, py)',
          required: false,
        ),
      ],
      returnType: 'List<String>',
      invoker: (args) async {
        final ext = args['extension'] as String?;
        final symbols = await codeSearch.extractSymbols(extension: ext);
        return symbols.map((s) => s.toString()).toList();
      },
    );
  }
}
