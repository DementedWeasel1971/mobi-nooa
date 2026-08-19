import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 08: Model Context Protocol (MCP) Integration
///
/// Demonstrates NOOA Principle 6: Invoking external tools via the standard MCP harness.
Future<void> main() async {
  print('=== mobi-nooa Tutorial 08: Model Context Protocol (MCP) ===\n');

  final mcpHarness = DefaultMcpHarness();

  // 1. Register a tool on the MCP harness
  mcpHarness.registerTool(
    definition: const ToolDefinition(
      name: 'getWeatherForecast',
      description: 'Fetches real-time weather conditions for a given city.',
      parameters: [
        ToolParameter(
          name: 'city',
          type: 'string',
          description: 'Target city name',
          required: true,
        ),
      ],
    ),
    handler: (args) async => {
      'city': args['city'],
      'temperature': '21°C',
      'condition': 'Sunny',
      'humidity': '45%',
    },
  );

  // 2. Discover available tools on the MCP harness
  final tools = await mcpHarness.listTools();
  print('Discovered MCP Tools:');
  for (final tool in tools) {
    print('- ${tool.name}: ${tool.description}');
  }

  // 3. Call tool via MCP harness
  final weatherResult = await mcpHarness.callTool(
    'getWeatherForecast',
    {'city': 'San Francisco'},
  );

  print('\nMCP Tool Execution Result:');
  print(weatherResult);
}
