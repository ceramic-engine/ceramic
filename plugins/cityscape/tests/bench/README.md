# Cityscape bench

Benchmark scenarios of Cityscape, run headless.

- Node: `ceramic headless run node --setup --assets --allow-multiple`
- Native (macOS): `ceramic clay build mac --setup --assets --allow-multiple`, then
  `project/mac/bench.app/Contents/MacOS/bench` (hidden window, `clay_sdl_headless`)

Environment variables: `CITYSCAPE_BENCH_SCENARIOS` (comma separated names),
`CITYSCAPE_BENCH_FRAMES` (default 300), `CITYSCAPE_BENCH_WARMUP` (default 30),
`CITYSCAPE_BENCH_RESULTS` (results directory, default `results/`, not committed).

Each scenario writes `<name>-<target>.json` with the mean, median, p95, p99 and
max frame time in milliseconds.

To add a scenario: implement `Scenario` in `src/scenarios/`, then add it to
`Scenarios.all()`. `range-sort` is a placeholder until the editor scenarios
(opening, typing and scrolling 10 000 lines, tokenization, allocations per frame)
are added with the model and the view.
