---
name: add-nooa-harness
description: 'Add a new model-callable harness capability to mobi_nooa_core (NOOA Principle 6), following this repo''s HarnessApi/*_harness.dart conventions.'
---

# Add a NOOA Harness

Use this skill when asked to add a new device/system capability that agents
should be able to call as a tool (e.g. camera, sensors, clipboard, contacts,
bluetooth, notifications, a new storage backend).

Harnesses implement **NOOA Principle 6: model-callable harness APIs** — they
expose typed, sandboxed Dart interfaces that agent actions invoke, and every
call should be observable via the `Tracer`. See `DESIGN.md` for the full
principle list and `AGENTS.md` for repo-wide conventions.

## Reference implementations (read before writing new code)

- `mobi_nooa_core/lib/src/harness/harness_api.dart` — the aggregator class
- `mobi_nooa_core/lib/src/harness/filesystem_harness.dart` — simple
  interface + default in-memory implementation pattern
- `mobi_nooa_core/lib/src/harness/memory_harness.dart` — interface with
  richer behavior (KV store + vector search) and its default implementation
- `mobi_nooa_core/lib/src/harness/device_harness.dart`,
  `network_harness.dart`, `mcp_harness.dart`, `sqlite_harness.dart` — other
  existing harnesses

## Pattern to follow

1. **File**: create `mobi_nooa_core/lib/src/harness/<name>_harness.dart`.
2. **Abstract interface**: define `abstract class <Name>Harness` with
   `Future<...>`-returning methods only (async, no sync I/O). Keep methods
   narrow and single-purpose — mirror how `FileSystemHarness` exposes
   `readFile`/`writeFile`/`exists`/`listFiles`/`deleteFile` rather than one
   catch-all method.
3. **Default implementation**: provide a concrete class named
   `Default<Name>Harness` (or a descriptive variant like
   `MemoryFileSystemHarness`) that implements the interface with an
   in-memory or safe sandboxed stand-in — this keeps `mobi_nooa_core`
   platform-agnostic. Do NOT call `dart:io`/platform APIs directly for
   device-specific behavior; that belongs in `android_mobi_nooa` bridging
   code, injected at runtime via constructor parameters.
4. **Wire into `HarnessApi`**:
   - add an import in `harness_api.dart`
   - add a `final <Name>Harness <fieldName>;` field
   - add an optional constructor parameter defaulting to
     `Default<Name>Harness()`
5. **Expose to agents**: harnesses are invoked from within agent actions
   registered via `NooaAgent.registerAction(...)` — a harness method itself
   is not automatically a callable tool. Add or update an action in the
   relevant agent (see `nooa_agent.dart` / examples under
   `mobi_nooa_core/example/`) that calls `context.harness.<fieldName>.<method>()`.
6. **Wrap large results**: if a harness method can return a large or complex
   object, wrap it with `context.heap.maybeWrap(...)` at the call site
   instead of returning it inline (NOOA Principle 2 — pass-by-reference).
7. **Tests**: add/extend a test in `mobi_nooa_core/test/` exercising the new
   harness directly (construct it, call its methods, assert behavior) —
   follow the style of `nooa_principles_test.dart`.
8. **Docs**: if this harness represents a new category of capability (not
   just a method on an existing one), add a row/mention in `DESIGN.md`'s
   harness section, and add an ADR under `docs/decisions/` if it introduces
   a new architectural pattern (e.g. a new native bridge mechanism).

## Validation

```powershell
cd mobi_nooa_core
dart analyze
dart test
```

Both must pass cleanly before considering the harness complete.

## Checklist

- [ ] `<name>_harness.dart` created with abstract interface + default impl
- [ ] Wired into `HarnessApi` (import, field, constructor param)
- [ ] No `flutter`/`dart:ui`/direct native platform calls inside `mobi_nooa_core`
- [ ] Agent action added/updated to actually invoke the harness as a tool
- [ ] Large/complex return values wrapped via `ObjectHeap.maybeWrap`
- [ ] Unit test added under `mobi_nooa_core/test/`
- [ ] `dart analyze` and `dart test` pass
- [ ] `DESIGN.md` / ADR updated if this is architecturally new
