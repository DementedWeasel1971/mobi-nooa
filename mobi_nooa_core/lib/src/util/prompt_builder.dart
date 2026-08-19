/// Dynamic prompt template builder and context block formatter.
class PromptBuilder {
  final StringBuffer _buffer = StringBuffer();

  /// Adds a header block.
  PromptBuilder header(String title, [int level = 2]) {
    final hashes = '#' * level;
    _buffer.writeln('\n$hashes $title');
    return this;
  }

  /// Adds key-value instructions or properties.
  PromptBuilder item(String label, dynamic value) {
    _buffer.writeln('- **$label**: $value');
    return this;
  }

  /// Adds a fenced code block.
  PromptBuilder codeBlock(String code, [String lang = '']) {
    _buffer.writeln('```$lang\n$code\n```');
    return this;
  }

  /// Adds raw text.
  PromptBuilder text(String content) {
    _buffer.writeln(content);
    return this;
  }

  /// Interpolates `{{variable}}` placeholders in a template string.
  static String interpolate(String template, Map<String, dynamic> variables) {
    var result = template;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value.toString());
    }
    return result;
  }

  String build() => _buffer.toString().trim();
}
