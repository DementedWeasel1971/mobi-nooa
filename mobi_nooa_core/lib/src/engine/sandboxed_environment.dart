import 'dart:convert';
import '../heap/object_heap.dart';
import '../harness/harness_api.dart';

/// Sandboxed execution environment for CodeAct scripts on mobile.
class SandboxedEnvironment {
  final ObjectHeap heap;
  final HarnessApi harness;
  final Map<String, dynamic> _variables = {};
  final List<String> stdout = [];

  SandboxedEnvironment({
    required this.heap,
    required this.harness,
    Map<String, dynamic>? initialVariables,
  }) {
    if (initialVariables != null) {
      _variables.addAll(initialVariables);
    }
    _registerBuiltins();
  }

  void setVar(String name, dynamic value) {
    _variables[name] = value;
  }

  dynamic getVar(String name) {
    if (name.startsWith('#ref_')) {
      return heap.get(name);
    }
    if (_variables.containsKey(name)) {
      return _variables[name];
    }
    throw ArgumentError('Variable or identifier "$name" is not defined.');
  }

  bool hasVar(String name) =>
      _variables.containsKey(name) || (name.startsWith('#ref_') && heap.contains(name));

  Map<String, dynamic> get variables => Map.unmodifiable(_variables);

  void printLog(dynamic message) {
    final str = message.toString();
    stdout.add(str);
  }

  void _registerBuiltins() {
    _variables['print'] = (dynamic msg) => printLog(msg);
    _variables['len'] = (dynamic obj) {
      if (obj == null) return 0;
      if (obj is List) return obj.length;
      if (obj is Map) return obj.length;
      if (obj is String) return obj.length;
      if (obj is Set) return obj.length;
      return 1;
    };
    _variables['range'] = (int start, [int? end, int step = 1]) {
      if (end == null) {
        return List.generate(start, (i) => i);
      }
      final list = <int>[];
      for (int i = start; i < end; i += step) {
        list.add(i);
      }
      return list;
    };
    _variables['sum'] = (List list) =>
        list.fold<num>(0, (prev, elem) => prev + (elem is num ? elem : 0));
    _variables['max'] = (List list) =>
        list.reduce((a, b) => (a as num) > (b as num) ? a : b);
    _variables['min'] = (List list) =>
        list.reduce((a, b) => (a as num) < (b as num) ? a : b);
    _variables['avg'] = (List list) {
      if (list.isEmpty) return 0;
      final total =
          list.fold<num>(0, (prev, elem) => prev + (elem is num ? elem : 0));
      return total / list.length;
    };
    _variables['jsonEncode'] = (dynamic obj) => jsonEncode(obj);
    _variables['jsonDecode'] = (String str) => jsonDecode(str);

    // Expose heap and harness APIs to code
    _variables['heap'] = heap;
    _variables['device'] = harness.device;
    _variables['fs'] = harness.fs;
    _variables['network'] = harness.network;
    _variables['memory'] = harness.memory;
  }
}
