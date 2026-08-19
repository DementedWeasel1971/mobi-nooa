import 'dart:convert';
import 'sandboxed_environment.dart';
import '../heap/object_reference.dart';
import '../heap/object_heap.dart';

/// Lightweight, safe interpreter for evaluating CodeAct script statements on mobile.
class AstEvaluator {
  final SandboxedEnvironment env;

  AstEvaluator(this.env);

  /// Executes a multi-line script and returns the result of the last expression or return statement.
  dynamic executeScript(String script) {
    final lines = script
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('//') && !l.startsWith('#'))
        .toList();

    dynamic lastResult;
    for (final line in lines) {
      if (line.startsWith('return ')) {
        final expr = line.substring('return '.length).trim();
        return evaluateExpression(expr);
      }
      lastResult = executeStatement(line);
    }
    return lastResult;
  }

  /// Executes a single statement (e.g. assignment `a = b` or function call).
  dynamic executeStatement(String statement) {
    var stmt = statement;
    if (stmt.endsWith(';')) {
      stmt = stmt.substring(0, stmt.length - 1).trim();
    }

    // Assignment: varName = expression
    final assignMatch = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$').firstMatch(stmt);
    if (assignMatch != null) {
      final varName = assignMatch.group(1)!;
      final expr = assignMatch.group(2)!;
      final val = evaluateExpression(expr);
      env.setVar(varName, val);
      return val;
    }

    return evaluateExpression(stmt);
  }

  /// Evaluates an expression.
  dynamic evaluateExpression(String expression) {
    var expr = expression.trim();
    if (expr.isEmpty) return null;

    // Literals
    if (expr == 'null') return null;
    if (expr == 'true') return true;
    if (expr == 'false') return false;

    // String literals
    if ((expr.startsWith('"') && expr.endsWith('"')) ||
        (expr.startsWith("'") && expr.endsWith("'"))) {
      return expr.substring(1, expr.length - 1);
    }

    // Number literals
    final numVal = num.tryParse(expr);
    if (numVal != null) return numVal;

    // Direct Heap Handle (e.g. #ref_1)
    if (expr.startsWith('#ref_') && env.heap.contains(expr)) {
      return env.heap.get(expr);
    }

    // List literals: [a, b, c]
    if (expr.startsWith('[') && expr.endsWith(']')) {
      final inner = expr.substring(1, expr.length - 1).trim();
      if (inner.isEmpty) return [];
      final items = _splitArguments(inner);
      return items.map((i) => evaluateExpression(i)).toList();
    }

    // Map literals: { "k": v }
    if (expr.startsWith('{') && expr.endsWith('}')) {
      try {
        return jsonDecode(expr);
      } catch (_) {}
    }

    // Binary expressions: e.g. a + b, a > b
    for (final op in ['==', '!=', '<=', '>=', '<', '>', '+', '-', '*', '/']) {
      final idx = _findTopLevelOperator(expr, op);
      if (idx != -1) {
        final leftExpr = expr.substring(0, idx).trim();
        final rightExpr = expr.substring(idx + op.length).trim();
        final left = evaluateExpression(leftExpr);
        final right = evaluateExpression(rightExpr);
        return _applyOperator(op, left, right);
      }
    }

    // Method / function invocation: target.method(arg1, arg2) or func(arg1)
    final callMatch = RegExp(r'^(.+)\((.*)\)$').firstMatch(expr);
    if (callMatch != null) {
      final targetExpr = callMatch.group(1)!.trim();
      final argsStr = callMatch.group(2)!.trim();
      final evaluatedArgs = _splitArguments(argsStr)
          .where((a) => a.isNotEmpty)
          .map((a) => evaluateExpression(a))
          .toList();

      if (targetExpr.contains('.')) {
        final dotIdx = targetExpr.lastIndexOf('.');
        final receiverExpr = targetExpr.substring(0, dotIdx).trim();
        final methodName = targetExpr.substring(dotIdx + 1).trim();
        final receiver = evaluateExpression(receiverExpr);
        return _invokeMethod(receiver, methodName, evaluatedArgs);
      } else {
        final fn = env.getVar(targetExpr);
        if (fn is Function) {
          return Function.apply(fn, evaluatedArgs);
        }
        throw ArgumentError('Identifier "$targetExpr" is not a callable function.');
      }
    }

    // Property / Map / List access: obj.field or list[index]
    if (expr.contains('.')) {
      final parts = expr.split('.');
      dynamic current = evaluateExpression(parts[0]);
      for (int i = 1; i < parts.length; i++) {
        final key = parts[i];
        if (current is Map) {
          current = current[key];
        } else {
          current = _getProperty(current, key);
        }
      }
      return current;
    }

    // Simple variable lookup
    if (env.hasVar(expr)) {
      return env.getVar(expr);
    }

    return expr;
  }

  int _findTopLevelOperator(String expr, String op) {
    int parenCount = 0;
    int bracketCount = 0;
    bool inQuote = false;
    String quoteChar = '';

    for (int i = 0; i <= expr.length - op.length; i++) {
      final char = expr[i];

      if ((char == '"' || char == "'") && (i == 0 || expr[i - 1] != '\\')) {
        if (!inQuote) {
          inQuote = true;
          quoteChar = char;
        } else if (char == quoteChar) {
          inQuote = false;
        }
      }

      if (inQuote) continue;

      if (char == '(') parenCount++;
      if (char == ')') parenCount--;
      if (char == '[') bracketCount++;
      if (char == ']') bracketCount--;

      if (parenCount == 0 && bracketCount == 0) {
        if (expr.substring(i, i + op.length) == op) {
          return i;
        }
      }
    }
    return -1;
  }

  List<String> _splitArguments(String argsStr) {
    if (argsStr.trim().isEmpty) return [];
    final args = <String>[];
    int parenCount = 0;
    int bracketCount = 0;
    bool inQuote = false;
    String quoteChar = '';
    int start = 0;

    for (int i = 0; i < argsStr.length; i++) {
      final char = argsStr[i];

      if ((char == '"' || char == "'") && (i == 0 || argsStr[i - 1] != '\\')) {
        if (!inQuote) {
          inQuote = true;
          quoteChar = char;
        } else if (char == quoteChar) {
          inQuote = false;
        }
      }

      if (inQuote) continue;

      if (char == '(') parenCount++;
      if (char == ')') parenCount--;
      if (char == '[') bracketCount++;
      if (char == ']') bracketCount--;

      if (char == ',' && parenCount == 0 && bracketCount == 0) {
        args.add(argsStr.substring(start, i).trim());
        start = i + 1;
      }
    }

    if (start < argsStr.length) {
      args.add(argsStr.substring(start).trim());
    }

    return args;
  }

  dynamic _applyOperator(String op, dynamic left, dynamic right) {
    switch (op) {
      case '+':
        if (left is String || right is String) return '$left$right';
        return (left as num) + (right as num);
      case '-':
        return (left as num) - (right as num);
      case '*':
        return (left as num) * (right as num);
      case '/':
        return (left as num) / (right as num);
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        return (left as num) > (right as num);
      case '<':
        return (left as num) < (right as num);
      case '>=':
        return (left as num) >= (right as num);
      case '<=':
        return (left as num) <= (right as num);
      default:
        throw UnsupportedError('Unsupported operator: $op');
    }
  }

  dynamic _invokeMethod(dynamic receiver, String methodName, List<dynamic> args) {
    if (receiver == null) {
      throw ArgumentError('Cannot invoke "$methodName" on null receiver.');
    }

    // Common list methods
    if (receiver is List) {
      if (methodName == 'take' && args.isNotEmpty) {
        return receiver.take((args[0] as num).toInt()).toList();
      }
      if (methodName == 'skip' && args.isNotEmpty) {
        return receiver.skip((args[0] as num).toInt()).toList();
      }
      if (methodName == 'contains' && args.isNotEmpty) {
        return receiver.contains(args[0]);
      }
      if (methodName == 'length') return receiver.length;
    }

    // ObjectHeap methods
    if (receiver is ObjectHeap) {
      if (methodName == 'get' && args.isNotEmpty) {
        return receiver.get(args[0].toString());
      }
      if (methodName == 'put' && args.isNotEmpty) {
        return receiver.put(args[0], label: args.length > 1 ? args[1].toString() : null);
      }
    }

    // Common reflection fallback
    try {
      final invoker = (receiver as dynamic);
      return Function.apply(invoker[methodName], args);
    } catch (_) {
      throw UnsupportedError('Method "$methodName" is not supported on $receiver');
    }
  }

  dynamic _getProperty(dynamic receiver, String prop) {
    if (receiver is ObjectReference) {
      if (prop == 'handle') return receiver.handle;
      if (prop == 'typeName') return receiver.typeName;
      if (prop == 'preview') return receiver.preview;
      if (prop == 'label') return receiver.label;
    }
    return (receiver as dynamic)[prop];
  }
}
