import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 01: First Generation Method
///
/// Demonstrates NOOA Principle 1: Defining an agent as a Dart class where
/// method docstrings and type annotations serve as model prompts.
class GreeterAgent extends NooaAgent {
  GreeterAgent()
      : super(
          name: 'GreeterAgent',
          role: 'Friendly Mobile Assistant',
          description: 'Greets users and introduces on-device capabilities.',
        );

  /// Generates a personalized greeting for [userName] highlighting mobile capabilities.
  Future<String> greet(String userName) async {
    return ellipsis<String>(
      'Generate a warm, one-line greeting for $userName mentioning on-device AI.',
    );
  }
}

Future<void> main() async {
  print('=== mobi-nooa Tutorial 01: First Generation Method ===\n');

  final mockModel = MockModelClient();
  mockModel.queueText('Hello Alice! Welcome to mobi-nooa, your autonomous on-device AI harness.');

  final agent = Quickstart.createAgent(
    () => GreeterAgent(),
    model: mockModel,
  );

  final greeting = await agent.greet('Alice');
  print('Agent Result:');
  print(greeting);
}
