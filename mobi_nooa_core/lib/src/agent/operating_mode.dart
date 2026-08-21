/// Operating modes for mobi-nooa agents (inspired by DeepSeek Harness modes).
enum AgentOperatingMode {
  /// Full autonomous execution where non-denied actions run directly.
  autonomous,

  /// Supervised execution where mutating actions require approval callback.
  supervised,

  /// Read-only observation & telemetry mode (all mutations blocked).
  audit,

  /// Creator mode tailored for skill discovery, code synthesis, and reflection.
  creator,
}
