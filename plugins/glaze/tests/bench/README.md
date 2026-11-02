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

On the web, the build runs under Ceramic's Electron runner with a hidden
window (the page reads the variables below from Node's `process.env`; the
project does not set `ceramic_use_electron`, so asset reads behave like in a
browser):

```sh
ceramic clay build web --setup --assets --variant perf     # perf: no allocation counters
GPUI_BENCH_SCENARIOS=cards GPUI_BENCH_RESULTS=/some/dir node web-run.js [--profile] [--alloc]
```

`web-run.js` adds what the page cannot measure: V8's collections per measured
block (`--js-flags=--trace-gc`: minor and major counts and pauses, allocation
volume per frame) in a `webGc` object of each result, a CPU profile per block
with `--profile` (`<scenario>-<mode>-rN.cpuprofile`, top self times printed)
and V8's sampling heap profile with `--alloc` (from the start of the block
with `GPUI_BENCH_SCREEN=1`). `GPUI_BENCH_WEB_DIR` runs another copy of
`project/web` (A/B on frozen builds). `--variant perf_onig` builds the perf
web bench with onig.wasm as the highlighter's regex engine (`gpui_onig_wasm`).

Environment variables: `GPUI_BENCH_SCENARIOS` (comma list, default all),
`GPUI_BENCH_FRAMES` (default 300), `GPUI_BENCH_ONLY` (`full` or `cached`),
`GPUI_BENCH_RUNS` (repeat the measured block N times in one process, one
result per run), `GPUI_BENCH_RESULTS` (results directory), `GPUI_BENCH_SCREEN`
(`1`: through the real update loop with the window on screen, adds the
Ceramic draw time per frame), `GPUI_BENCH_RT` (`1` or `0`: force the render to
texture mode of the windows), `GPUI_BENCH_PARTIAL` (`1` or `0`: force the
partial rendering of the windows' render textures, see
`SceneRenderable.partialRendering`), `GPUI_BENCH_VERIFY_PARTIAL` (`1`, on
screen: compare each partially drawn frame byte for byte with a full redraw),
`GPUI_BENCH_GPU` (`1`, on screen: wait for the GPU after each Ceramic draw,
`glFinish()` natively and a one pixel read back on the web, and report that
wait as a proxy of the frame's GPU time), `GPUI_BENCH_ATLAS` (`1`: atlas upload micro
benchmark instead of the scenarios).

For timings, measure without `gpui_count_allocations` (it is instrumentation)
in `ceramic.yml`; add `gpui_profile_frames` for the per-phase times.

## Endurance (leak check)

`GPUI_BENCH_SOAK_SECONDS=N` runs each selected scenario and mode for N seconds
instead of the measured blocks (pick one with `GPUI_BENCH_SCENARIOS` and
`GPUI_BENCH_ONLY`), through the real update loop in slices of about 100 ms.
Every `GPUI_BENCH_SOAK_SAMPLE_SECONDS` (default 5) it records the hxcpp heap
(used, reserved, current, large, minor and full collections, concurrent
cycles, allocation volume), the V8 heap on node and the web, and the frame
times of the interval; every `GPUI_BENCH_SOAK_LIVE_SECONDS` (default 60, 0 for
never) the live memory right after a full collection (`Gc.run(true)` and
hxcpp's exact live object bytes, memInfo 120; V8's `gc()` on node and the
web). The series are stored in arrays allocated up front, so the recording
does not show up as growth. The result is
`<timestamp>-<target>-<scenario>-<mode>-soak.json` with a summary: least
squares slopes (MB per minute) after `GPUI_BENCH_SOAK_WARMUP_SECONDS`
(default 180) of the live, reserved and used memory, and `leakSuspected` (a
significant live slope and a rising live floor, above 1 MB and 2 % over the
span). `node ../../scratchpad/soak-report.js <file>` prints a report.

```sh
GPUI_BENCH_SCENARIOS=cards GPUI_BENCH_ONLY=full GPUI_BENCH_SOAK_SECONDS=1800 project/mac/bench.app/Contents/MacOS/bench
GPUI_BENCH_SCENARIOS=cards GPUI_BENCH_ONLY=full GPUI_BENCH_SOAK_SECONDS=900 GPUI_BENCH_RESULTS=/some/dir node web-run.js
```

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

## Boxing report

`boxing-report.js` scans the C++ that hxcpp generated for the port, taffy and
ttf (`out/clay/mac/cpp` after a native build of this project) and counts, per
Haxe module and per function, what boxes values or allocates behind the
code's back (step 5 of `docs/perf/PLAN.md`):

- `dynLocal`: `::Dynamic` locals and parameters (`Null<Float>`, `Null<Int>`,
  `Null<Bool>`, function values, anonymous structures);
- `dynCall`: calls through a function value (Float arguments are boxed);
- `field`: field reads and writes on anonymous structures and `Dynamic`
  (`__Field` / `__SetField`, a lookup by name);
- `anon`: anonymous structures created;
- `closure`: local functions (one allocation each time the code runs);
- `member`: methods taken as values (`obj->method_dyn()`);
- `dynCtor`: other explicit `::Dynamic(...)` constructions;
- `fields`: `::Dynamic` fields of the module's classes (from the headers).

```sh
node boxing-report.js                         # hot modules (Window, Div, Interactivity, Style, taffy...)
node boxing-report.js --all --functions 0     # every module, totals only
node boxing-report.js --json before.json      # save the counts
node boxing-report.js --compare before.json   # difference with saved counts
```

It is static: it says where boxing can happen, not how often. Pair it with a
profile (`--variant prof_checked` and macOS `sample`) to find the hot ones,
and rerun it after each lot: the counts of the modules touched must go down.
