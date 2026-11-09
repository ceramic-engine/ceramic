# Cityscape bench

Benchmark scenarios of Cityscape, run headless.

- Node: `ceramic headless run node --setup --assets --allow-multiple`
- Native (macOS): `ceramic clay build mac --setup --assets --allow-multiple`, then
  `project/mac/bench.app/Contents/MacOS/bench` (hidden window, `clay_sdl_headless`)

Environment variables: `CITYSCAPE_BENCH_SCENARIOS` (comma separated names),
`CITYSCAPE_BENCH_FRAMES` (default 300), `CITYSCAPE_BENCH_WARMUP` (default 30),
`CITYSCAPE_BENCH_RESULTS` (results directory, default `results/`, not committed).

Each scenario writes `<name>-<target>.json` with the mean, median, p95, p99 and
max frame time in milliseconds, and natively the bytes allocated per frame
(hxcpp's allocation volume) and the minor collections of the measured frames.

Variants (native): the default build is the one whose numbers count;
`--variant perf` (no hxcpp checks), `--variant prof` and `--variant prof_checked`
(symbols kept, for `sample` or Instruments) are diagnostics.
`--variant allocprof` records every allocation (hxcpp's telemetry, see
`src/AllocProfile.hx`, a copy of Glaze's) and writes
`<scenario>-cpp-allocs.txt` next to the results: objects and bytes per frame by
type, by allocating function and by call site (`CITYSCAPE_BENCH_ALLOC_TOP` lines
per table, `CITYSCAPE_BENCH_ALLOC_DEPTH` callers per site, default 2).

Checks of the view scenarios: `CITYSCAPE_BENCH_VERIFY=1` draws every frame
again in full after the cached draw and counts the frames whose primitive
count differs (a view not painted again), and turns on
`CityscapeView.checkRenderCache` (every kept rendered line checked against its
rendering input); `CITYSCAPE_BENCH_DIGEST=1` (with it) prints an MD5 of each
fully drawn frame (Glaze's scene dump), to compare two builds frame by frame
(`diff <(grep DIGEST a.log) <(grep DIGEST b.log)`). `CITYSCAPE_BENCH_DEBUG=1`
prints the scroll position, views rendered and primitives every 10 frames.

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

View scenarios (`src/scenarios/ViewBench.hx`, `ViewScenarios.hx`): real
`CityscapeEditor`s in a headless Glaze window (1280x1024 at scale 2, view
caching on, the kit's dark theme), 10 000 lines of JavaScript (the lines of
`data/runner-app.js` repeated) with Glaze's grammar and VS Code's Dark+, the
document tokenized and the background work done before measuring. Each frame
is the input (a wheel event or a keystroke through the window), the context's
background scheduler for one frame budget, and the draw of the window.

- `view-open`: a new 10 000 line model set on the editor and drawn (20 frames).
- `view-scroll-line`, `view-scroll-page`: steady scrolling, one line or one
  page per frame; `view-scroll-wrap` with word wrap on; `view-scroll-cjk` in a
  file heavy in CJK and emoji (ZWJ sequences, flags, keycaps, skin tones).
- `view-decorated`: one line per frame through 2000 inline decorations (a
  registered class style, typed pills, typed italic colors), 500 hidden
  ranges revealed on the cursor line and 200 whole line styles.
- `view-type`: one keystroke per frame at the end of the longest code line of
  the middle of the file (a word typed, then erased with Backspace), the
  pending quick suggestion run after each key (its 10 ms delay is over before
  the next frame of an app): the suggest widget opens on the words typed
  (word based completions over the 10 000 lines).
- `view-type-suggest`: the suggest widget open while typing (`const` typed and
  erased after its first letter, the widget refilters).
- `view-type-nosuggest`: quick suggestions and suggestions on trigger
  characters off.
- `view-type-multi`: 10 cursors; `view-type-two`: two editors on the model;
  `view-type-wrap`: word wrap on.
- `view-type-long`, `view-type-long-wrap`: typing in a line of 5000
  characters (wrap off, then on).
