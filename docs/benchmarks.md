# Benchmarking & Evaluation Suite (`nooa.bench`)

**`mobi-nooa`** includes an evaluation suite for benchmarking mobile agents on standard SWE-bench software engineering tasks and mobile-specific autonomous device tasks.

---

## 🏆 1. Benchmark Suites

### SWE-bench Verified (Mobile Edition)
Evaluates `BenchAgent` on realistic GitHub bug resolution:
- **`swe_task_001`**: Off-by-one boundary fix in array chunker.
- **`swe_task_002`**: Missing JSON configuration loader implementation.

### Mobile-Bench Autonomous
Evaluates mobile-specific capabilities:
- **`mob_task_001`**: Device battery health audit and eco-mode trigger.
- **`mob_task_002`**: In-memory pass-by-reference dataset aggregation using `ObjectHeap`.

---

## 🚀 2. Running Benchmarks

Execute the runner script:

```bash
cd mobi_nooa_core
dart run example/run_benchmarks.dart
```

### Sample Output:
```
=== Benchmark Report: SWE-bench-Verified-Mobile ===
Pass Rate: 100.0% (2 / 2)
Avg Steps per Task: 1.00
Total Tokens: 0

Exported JSONL Report:
{"taskId":"swe_task_001","isResolved":true,"stepsUsed":1,"durationMs":7,"agentOutput":"Fixed remainder slicing."}
{"taskId":"swe_task_002","isResolved":true,"stepsUsed":1,"durationMs":0,"agentOutput":"Loaded app_name."}
```

---

## 📊 3. Metric Calculations

`BenchmarkReport` tracks:
- **Pass Rate**: Percentage of resolved benchmark tasks ($\frac{\text{Resolved}}{\text{Total}}$).
- **Average Steps**: Number of reasoning loop steps per task.
- **Token Efficiency**: Prompt tokens, completion tokens, and total tokens consumed.
- **Execution Duration**: Milliseconds per task.
- **JSONL Export**: Structured line-delimited records for automated analysis in CI/CD pipelines.
