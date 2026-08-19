import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 05: Pluggable Execution Strategies (ReAct, PlanAndSolve, CodeAct)
///
/// Demonstrates NOOA Principle 4: Reasoning strategies can be swapped without
/// altering the agent class implementation or the harness interfaces.
Future<void> main() async {
  print('=== mobi-nooa Tutorial 05: Execution Strategies ===\n');

  final agent = Quickstart.createAgent(() => GeneralMobileAgent());

  // 1. ReAct Strategy (Thought -> Action -> Observation)
  print('1. Testing ReAct Strategy Prompt Formatter:');
  final reactStrategy = ReActStrategy();
  print(reactStrategy.buildStrategyPrompt(agent));

  // 2. PlanAndSolve Strategy (Two-Stage Planning + Execution)
  print('\n2. Testing PlanAndSolve Strategy Prompt Formatter:');
  final planStrategy = PlanAndSolveStrategy();
  print(planStrategy.buildStrategyPrompt(agent));

  // 3. CodeAct Strategy (Direct Code Execution)
  print('\n3. Testing CodeAct Strategy Prompt Formatter:');
  final codeActStrategy = CodeActStrategy();
  print(codeActStrategy.buildStrategyPrompt(agent));

  // 4. Run ReAct with simulated thoughts
  final mockResponse = ModelResponse(
    text: 'Thought: I should check battery level.\nFinal Answer: Device is at 95% battery.',
  );
  final reactResult = await reactStrategy.processResponse(
    agent: agent,
    modelResponse: mockResponse,
    history: [],
  );

  print('\nReAct Strategy Result Output: ${reactResult.finalOutput}');
  print('ReAct Should Continue Loop? ${reactResult.shouldContinue}');
}
