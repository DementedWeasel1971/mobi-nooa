import 'package:meta/meta_meta.dart';

/// Annotation for documenting a [NooaAgent] class.
@Target({TargetKind.classType})
class NooaAgentDoc {
  final String description;
  final String? role;
  final List<String> tags;

  const NooaAgentDoc(
    this.description, {
    this.role,
    this.tags = const [],
  });
}

/// Annotation providing prompt instructions for the agent or a specific dynamic method.
@Target({TargetKind.classType, TargetKind.method})
class Prompt {
  final String text;
  const Prompt(this.text);
}

/// Annotation providing documentation for tools, actions, or properties.
@Target({TargetKind.method, TargetKind.getter, TargetKind.field})
class Doc {
  final String description;
  const Doc(this.description);
}

/// Annotation specifying details for method parameters.
@Target({TargetKind.parameter, TargetKind.method})
class ParamDoc {
  final String name;
  final String description;
  final bool required;
  final dynamic defaultValue;

  const ParamDoc(
    this.name,
    this.description, {
    this.required = true,
    this.defaultValue,
  });
}

/// Annotation specifying the return value description of an action.
@Target({TargetKind.method})
class ReturnsDoc {
  final String description;
  const ReturnsDoc(this.description);
}

/// Marks a method as an executable Agent Action / Tool.
@Target({TargetKind.method})
class Action {
  final String? name;
  final String? description;
  final bool isDeterministic;

  const Action({
    this.name,
    this.description,
    this.isDeterministic = true,
  });
}

/// Marks a method as a Dynamic Action (the NOOA `...` ellipsis equivalent).
/// When called or invoked by the agent, execution is driven dynamically by the LLM.
@Target({TargetKind.method})
class DynamicAction {
  final String? promptTemplate;
  final int maxSteps;
  final double temperature;

  const DynamicAction({
    this.promptTemplate,
    this.maxSteps = 10,
    this.temperature = 0.2,
  });
}

/// Marks an agent field as explicit managed state.
@Target({TargetKind.field, TargetKind.getter, TargetKind.setter})
class StateVar {
  final String? description;
  final bool persistent;
  final bool reactive;

  const StateVar({
    this.description,
    this.persistent = true,
    this.reactive = true,
  });
}
