# CLAUDE.md — mobi-nooa Instructions

This repository fuses **NVIDIA's Object-Oriented Agents (NOOA)**, **DeepSeek Harness**, and **xAI Grok Build** for mobile autonomous agent engines.

## 🛠️ Build & Test Commands

```powershell
# Dart Core: Unit tests & analysis
cd mobi_nooa_core
dart analyze
dart test --exclude-tags live

# Flutter Bridge Shim: MethodChannel tests
cd ../mobi_nooa_bridge
flutter analyze
flutter test

# Android Native Kotlin: JVM Unit tests
cd ..
.\gradlew.bat :android_mobi_nooa:testDebugUnitTest

# Full Android APK assembly
.\gradlew.bat :app:assembleDebug

# Live On-Device Integration Runner (connected emulator or physical device)
.\gradlew.bat :android_mobi_nooa:connectedDebugAndroidTest
```

## 📖 Key Rules & Guidelines

- **Primary Repository Reference**: Read [`AGENTS.md`](./AGENTS.md) and [`DESIGN.md`](./DESIGN.md) before making architectural changes.
- **Rules Directory**: See [`.agents/rules/flutter_rules.md`](./.agents/rules/flutter_rules.md) and [`.agents/rules/nooa_dart_rules.md`](./.agents/rules/nooa_dart_rules.md).
- **Dart 3.x Idioms**: Use switch expressions, pattern matching, sealed class hierarchies, and `const` constructors.
- **Zero Flutter in Core**: `mobi_nooa_core` must never import Flutter/`dart:ui`.
- **Pass-by-Reference**: Wrap large data with `ObjectHeap.maybeWrap` (`#ref_xxx`).
- **AST Guardrails**: Validate all CodeAct snippets through `AstGuardrails.validate`.
- **4-Tier Testing**: Follow strict TDD (Red -> Green -> Refactor & Secure).
