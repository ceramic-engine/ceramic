# Benchmark suite

Scenarios of the GPUI port, each a window built once per mode (full render:
no view cache; cached: the default view caching) and one mutation or input
per frame. The runner (`src/BenchRunner.hx`) draws after every step and
measures the frame time (mean, median, p50, p95, p99, max), the views
rendered and reused, the objects created (`gpui.util.AllocationCounters`,
with the `gpui_count_allocations` define), the bytes per frame on native
(GC disabled), the per-phase times (`gpui.util.FrameProfiler`, with the
`gpui_profile_frames` define, otherwise 0) and the minor GC pauses on native.
The `idle` scenario checks that 120 frames of the real update loop draw and
allocate nothing; the process exits with 1 when they do.

Scenarios are registered in `src/Scenarios.hx` (`cards`, `idle`, and the
classes under `src/scenarios/`). A scenario implements `Scenario` or extends
`BaseScenario` (`src/Scenario.hx`, `src/BaseScenario.hx`).

## Running

```sh
cd test/bench
ceramic headless run node --setup --assets            # Node
ceramic clay build mac --setup --assets && project/mac/bench.app/Contents/MacOS/bench   # native
```

Environment variables: `GPUI_BENCH_SCENARIOS` (comma list, default all),
`GPUI_BENCH_FRAMES` (default 300), `GPUI_BENCH_ONLY` (`full` or `cached`),
`GPUI_BENCH_RUNS` (repeat the measured block N times in one process, one
result per run), `GPUI_BENCH_RESULTS` (results directory).

For timings, measure without `gpui_count_allocations` (it is instrumentation)
in `ceramic.yml`; add `gpui_profile_frames` for the per-phase times.

## Results

Each run writes `results/<yyyymmdd-HHMMSS>-<target>-<scenario>-<mode>.json`
(target `native`, `node` or `web`; `-rN` suffix when `GPUI_BENCH_RUNS` is
above 1) with the metrics, the build defines, the GC configuration and the
system. The same JSON is printed on one line prefixed with `BENCH_JSON ` on
every target; on the web only the line is printed. The results folder is
versioned.

## Comparing

```sh
node compare.js <baseline-dir-or-glob> <candidate-dir-or-glob> [--median-threshold 3] [--p99-threshold 5]
node compare.js 'results/20261101-02*' 'results/20261101-03*'
```

Files are grouped by (target, scenario, mode) and the median over the runs of
each group is used. The script prints a table per group (metric, baseline,
candidate, delta in percent) and exits with 1 when the median frame time
regresses by more than the median threshold, the p99 by more than the p99
threshold, or the bytes per frame or the total minor GC pause by more than
the median threshold.
