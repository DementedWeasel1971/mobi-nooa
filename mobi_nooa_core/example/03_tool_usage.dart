import 'package:mobi_nooa_core/mobi_nooa_core.dart';

/// 03: Tool Usage and State Mutation
///
/// Demonstrates NOOA Principle 5 & 6: Methods registered as tools that mutate
/// explicit agent state (`setState`/`getState`) and interact with harnesses.
class ExpenseAgent extends NooaAgent {
  ExpenseAgent()
      : super(
          name: 'ExpenseAgent',
          role: 'Personal Expense Tracker',
          description: 'Tracks on-device expenses and manages ledger state.',
        );

  @override
  void initAgent() {
    setState('expenses', <Map<String, dynamic>>[]);
    setState('totalBudget', 500.0);

    registerAction(
      name: 'addExpense',
      description: 'Records a new expense item into the agent ledger.',
      parameters: const [
        ToolParameter(
          name: 'title',
          type: 'string',
          description: 'Expense item name',
          required: true,
        ),
        ToolParameter(
          name: 'amount',
          type: 'number',
          description: 'Cost in USD',
          required: true,
        ),
      ],
      returnType: 'double',
      invoker: (args) async {
        final title = args['title'] as String;
        final amount = (args['amount'] as num).toDouble();

        final list = List<Map<String, dynamic>>.from(
          (getState('expenses') as List?) ?? [],
        )..add({'title': title, 'amount': amount});

        setState('expenses', list);
        final total = list.fold<double>(0.0, (sum, e) => sum + (e['amount'] as double));
        return total;
      },
    );
  }
}

Future<void> main() async {
  print('=== mobi-nooa Tutorial 03: Tool Usage & State Mutation ===\n');

  final mockModel = MockModelClient();
  mockModel.queueToolCall(
    toolName: 'addExpense',
    arguments: {'title': 'Coffee', 'amount': 4.50},
    thought: 'Adding coffee expense to ledger.',
  );
  mockModel.queueToolCall(
    toolName: 'addExpense',
    arguments: {'title': 'Mobile Data Plan', 'amount': 25.00},
    thought: 'Adding data plan expense to ledger.',
  );
  mockModel.queueText('Successfully recorded 2 expenses. Total spent: \$29.50');

  final agent = Quickstart.createAgent(
    () => ExpenseAgent(),
    model: mockModel,
  );

  final summary = await agent.ellipsis<String>('Record \$4.50 for coffee and \$25 for data plan.');
  print('Agent Summary:\n$summary\n');

  print('Final Agent Explicit State:');
  print(agent.getStateSnapshot());
}
