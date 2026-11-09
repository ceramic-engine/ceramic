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
`Scenarios.all()`.

Scenarios:

- `range-sort`: sorts 10 000 ranges (runner check).
- `model-open`: builds a 10 000 line model (about 300 KB of code-like text)
  and disposes it.
- `model-edit`: 1000 single character edits (`applyEdits`, insertions and
  deletions alternating) at pseudo random positions of a 10 000 line model.
- `model-type`: the same through `pushEditOperations` (undo stack, events),
  a stack element closed every 10 edits.
- `model-read-lines`: `getLineContent` on every line of a 10 000 line model
  fragmented by 2000 random edits.

- `tokenize-js-full`, `tokenize-10k-full`: TextMate tokenization of the
  whole document each frame (Glaze's JavaScript grammar and VS Code's Dark+
  theme on `data/runner-app.js`, a frozen copy of Ceramic's runner/app.js,
  541 lines, and on 10 000 lines repeating it; pure Haxe Oniguruma). The
  10 000 line one takes seconds per frame: run it with
  `CITYSCAPE_BENCH_FRAMES=5`.
- `tokenize-js-edit`, `tokenize-10k-edit`: one character typed or removed
  per frame in the longest line of the middle of the document, then
  tokenization until the last line again (only what the state store
  invalidated).

The view scenarios (scrolling, allocations per frame) come with the view.
