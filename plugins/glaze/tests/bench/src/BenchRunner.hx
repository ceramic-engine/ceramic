package;

import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Window;
import gpui.util.AllocationCounters;
import gpui.util.FrameProfiler;

/**
 * Runs the registered scenarios (`Scenarios.all()`) and writes one JSON
 * result per (scenario, mode, run) in `test/bench/results/`.
 *
 * For a regular scenario and each of its modes (full render: no view cache,
 * like GPUI's uncached views; cached: the default view caching), the measured
 * block is: 30 warmup frames, then `frames` frames of `scenario.step(frame)`
 * followed by `flushImmediate()` and `window.drawIfDirty()`. It reports the
 * mean, median, p50, p95, p99 and max frame time, the views rendered and
 * reused per frame, the objects created per frame (`AllocationCounters`,
 * with `gpui_count_allocations`), the new `AnyElement`s per frame, on native
 * the bytes allocated per frame (20 more frames with the GC disabled), the
 * per-phase times per frame (`FrameProfiler`, with `gpui_profile_frames`,
 * otherwise 0) and on native the minor GC pauses (`cpp.vm.Gc.memInfo64`
 * 107 to 110, 0 until hxcpp exposes them), the concurrent cycles per second,
 * the reserved heap and the process RSS at the end of the block, and the CPU
 * time: the main thread's per frame (`CLOCK_THREAD_CPUTIME_ID`: median, p99,
 * mean, and the median of the frames without any collection work and of the
 * frames run during a concurrent cycle), and the whole process's per frame.
 * The thread CPU time is not inflated by other processes like the wall time,
 * which helps comparing runs taken on a busy machine.
 *
 * An `IdleScenario` is drawn once, put on the screen, and `idleFrames` ticks
 * of the real update loop must draw nothing and allocate nothing; the process
 * exits with 1 when they do.
 *
 * Environment:
 * - `GPUI_BENCH_SCENARIOS`: comma separated names (default: all registered);
 * - `GPUI_BENCH_FRAMES`: measured frames per run (default 300);
 * - `GPUI_BENCH_ONLY`: `full` or `cached` to measure one mode only;
 * - `GPUI_BENCH_RUNS`: repeats of the measured block in the same process (default 1);
 * - `GPUI_BENCH_RESULTS`: results directory (default `test/bench/results`);
 * - `GPUI_BENCH_SCREEN`: `1` runs the measured block through the real update
 *   loop with the renderable on the screen (one step per tick), so the
 *   `render` phase (SceneRenderable, with `gpui_profile_frames`), the time
 *   Ceramic spends drawing (from its begin draw to its finish draw event) and
 *   the wall time between two ticks (GL flush and swap included) are
 *   measured too;
 * - `GPUI_BENCH_ATLAS`: `1` runs the atlas upload micro benchmark instead;
 * - `GPUI_BENCH_RT`: `1` or `0` forces the `renderToTexture` mode of the
 *   windows' renderables (`SceneRenderable.renderToTexture`), otherwise the
 *   default (`SceneRenderable.defaultRenderToTexture`);
 * - `GPUI_BENCH_GPU`: `1` (on screen, clay) calls `glFinish()` (on the web:
 *   reads one pixel back, `finish()` does not wait there) after each
 *   Ceramic draw and measures how long it waits: the GPU work left for the
 *   frame, a proxy of its GPU time (it serializes CPU and GPU, so compare
 *   runs that both use it);
 * - `GPUI_BENCH_VERIFY_PARTIAL`: `1` (on screen, clay) also draws every frame
 *   entirely into a second texture and compares it byte for byte with the
 *   partially drawn one (`SceneRenderable.verifyPartialRendering`), printing
 *   the counts after each block (a check, not a measure);
 * - `GPUI_BENCH_PARTIAL`: `1` or `0` forces the `partialRendering` mode of
 *   the windows' renderables (`SceneRenderable.partialRendering`), otherwise
 *   the default (`SceneRenderable.defaultPartialRendering`);
 * - `GPUI_BENCH_SOAK_SECONDS`: endurance (leak check) run instead of the
 *   measured blocks: each selected scenario and mode runs that many seconds
 *   and its memory is sampled (see `soak`), with
 *   `GPUI_BENCH_SOAK_SAMPLE_SECONDS` (default 5), `GPUI_BENCH_SOAK_LIVE_SECONDS`
 *   (live memory after a full collection, default 60, 0 for never) and
 *   `GPUI_BENCH_SOAK_WARMUP_SECONDS` (left out of the slopes, default 180).
 */
#if cpp
@:cppFileCode('
#include <time.h>
#ifdef __APPLE__
#include <mach/mach.h>
#endif
static double bench_thread_cpu_ms() {
#ifdef _WIN32
   return 0;
#else
   struct timespec ts;
   if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts) != 0) return 0;
   return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
#endif
}
static double bench_rss_bytes() {
#ifdef __APPLE__
   mach_task_basic_info_data_t info;
   mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
   if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return 0;
   return (double)info.resident_size;
#else
   return 0;
#endif
}
')
#end
class BenchRunner {

    public static inline final WARMUP_FRAMES = 30;

    public static inline final BYTES_FRAMES = 20;

    /**
     * Minor GC counters of hxcpp (`cpp.vm.Gc.memInfo64`), 0 when missing.
     */
    static inline final MEM_INFO_MINOR_PAUSE_COUNT = 107;
    static inline final MEM_INFO_LAST_MINOR_PAUSE_MS = 108;
    static inline final MEM_INFO_MAX_MINOR_PAUSE_MS = 109;
    static inline final MEM_INFO_TOTAL_MINOR_PAUSE_MS = 110;
    static inline final MEM_INFO_ALLOCATION_VOLUME = 117;
    static inline final MEM_INFO_FULL_COUNT = 115;
    static inline final MEM_INFO_CYCLE_COUNT = 100;
    static inline final MEM_INFO_CYCLE_ACTIVE = 104;
    /** Object bytes in blocks found live by the last full collection (exact, without line fragmentation) */
    static inline final MEM_INFO_FULL_LIVE_BYTES = 120;
    /** Heap bound of the concurrent collector: goal, allocations that waited at the cap, bytes released */
    static inline final MEM_INFO_HEAP_GOAL = 121;
    static inline final MEM_INFO_HEAP_WAITS = 122;
    static inline final MEM_INFO_HEAP_RELEASED = 123;

    /** `cpp.vm.Gc.MEM_INFO_*` (usage, reserved, current, large) */
    static inline final cpp_MEM_INFO_USAGE = 0;
    static inline final cpp_MEM_INFO_RESERVED = 1;
    static inline final cpp_MEM_INFO_CURRENT = 2;
    static inline final cpp_MEM_INFO_LARGE = 3;

    /** Frames of a soak run go by slices of about this long per update tick (ms) */
    public static inline final SOAK_SLICE_MS = 100.0;

    final owner:ceramic.Entity;

    final app:App;

    final frames:Int;

    final runs:Int;

    final only:Null<String>;

    final screen:Bool;

    final renderToTexture:Null<Bool>;

    final partialRendering:Null<Bool>;

    final scenarios:Array<Scenario>;

    final timestamp:String;

    /** `GPUI_BENCH_SOAK_SECONDS`: endurance run length per mode (0: regular bench) */
    final soakSeconds:Int;

    /** `GPUI_BENCH_SOAK_SAMPLE_SECONDS`: memory sample period of a soak run */
    final soakSampleSeconds:Float;

    /** `GPUI_BENCH_SOAK_LIVE_SECONDS`: live memory (after a full collection) period, 0 for never */
    final soakLiveSeconds:Float;

    /** `GPUI_BENCH_SOAK_WARMUP_SECONDS`: samples left out of the slopes */
    final soakWarmupSeconds:Float;

    var resultsDir:Null<String> = null;

    var failed:Bool = false;

    var written:Array<String> = [];

    /** Main thread CPU time of each measured frame of the current block (ms) */
    final blockThreadCpu:Array<Float> = [];
    /** The same, for frames without collection work, and for frames during a concurrent cycle (no minor) */
    final blockQuietCpu:Array<Float> = [];
    final blockCycleCpu:Array<Float> = [];
    var blockCyclesBefore = 0.0;
    var blockProcessCpuBefore = 0.0;
    var blockWallBefore = 0.0;

    /** Ceramic draw time of the last on screen measure (median and p99, ms) */
    var lastDrawMedian:Float = 0.0;

    /** Path tiles rasterized during the last measure */
    var lastPathRasterizations:Int = 0;
    var lastDrawP99:Float = 0.0;
    var lastDrawMax:Float = 0.0;

    /** Process CPU time per frame of the last on screen measure (native, ms) */
    var lastCpuPerFrame:Float = 0.0;

    /** `GPUI_BENCH_GPU`: glFinish wait of the last on screen measure (median and p99, ms) */
    var lastGpuFinishMedian:Float = 0.0;
    var lastGpuFinishP99:Float = 0.0;

    #if (clay && web)
    final gpuProbe = new js.lib.Uint8Array(4);
    #end

    public function new(owner:ceramic.Entity, app:App) {
        this.owner = owner;
        this.app = app;
        frames = envInt('GPUI_BENCH_FRAMES', 300);
        runs = envInt('GPUI_BENCH_RUNS', 1);
        final onlyEnv = env('GPUI_BENCH_ONLY');
        only = onlyEnv == 'full' || onlyEnv == 'cached' ? onlyEnv : null;
        screen = env('GPUI_BENCH_SCREEN') == '1';
        final rtEnv = env('GPUI_BENCH_RT');
        renderToTexture = rtEnv == '1' ? true : rtEnv == '0' ? false : null;
        final partialEnv = env('GPUI_BENCH_PARTIAL');
        partialRendering = partialEnv == '1' ? true : partialEnv == '0' ? false : null;
        if (env('GPUI_BENCH_VERIFY_PARTIAL') == '1') {
            gpui.platform.SceneRenderable.verifyPartialRendering = true;
        }
        soakSeconds = envInt('GPUI_BENCH_SOAK_SECONDS', 0);
        soakSampleSeconds = envFloat('GPUI_BENCH_SOAK_SAMPLE_SECONDS', 5);
        soakLiveSeconds = envFloat('GPUI_BENCH_SOAK_LIVE_SECONDS', 60);
        soakWarmupSeconds = envFloat('GPUI_BENCH_SOAK_WARMUP_SECONDS', 180);
        timestamp = DateTools.format(Date.now(), '%Y%m%d-%H%M%S');
        scenarios = select(Scenarios.all());
    }

    /**
     * The standard benchmark window: 1280x1024 at scale 2, no auto draw, no
     * input binding, the view caching of the mode.
     */
    public static function openWindow(app:App, caching:Bool, buildRoot:Void->AnyView, width:Int = 1280, height:Int = 1024, scaleFactor:Float = 2.0):Window {
        final window = Window.open(app, {width: width, height: height, scaleFactor: scaleFactor, autoDraw: false, bindInput: false, viewCaching: caching}, (_, _) -> buildRoot());
        window.viewCachingDisabled = !caching;
        return window;
    }

    /**
     * Runs every selected scenario, then exits the process (1 when an idle
     * check failed).
     */
    /**
     * Atlas upload micro benchmark (`GPUI_BENCH_ATLAS=1`): 60 bursts of 300
     * new glyph-like monochrome tiles and 4 polychrome tiles, each followed
     * by `CeramicAtlas.upload()`, timed.
     */
    static function atlasBench():Void {
        final atlas = new gpui.platform.CeramicAtlas(1024, true, false);
        var seed = 1;
        function rnd(n:Int):Int {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            return seed % n;
        }
        final times:Array<Float> = [];
        var key = 0;
        for (round in 0...60) {
            // A burst of new glyphs (a new page of text), and a few images
            for (_ in 0...300) {
                final w = 6 + rnd(14);
                final h = 10 + rnd(14);
                final bytes = haxe.io.Bytes.alloc(w * h);
                for (i in 0...bytes.length) bytes.set(i, rnd(256));
                atlas.getOrInsertWith(gpui.AtlasKey.Svg('g${key++}', w, h), () -> new gpui.AtlasTile.AtlasTileSource(w, h, bytes));
            }
            for (_ in 0...4) {
                final w = 24 + rnd(40);
                final h = 24 + rnd(40);
                final bytes = haxe.io.Bytes.alloc(w * h * 4);
                for (i in 0...bytes.length) bytes.set(i, rnd(256));
                final source = new gpui.AtlasTile.AtlasTileSource(w, h, bytes);
                source.straightAlpha = true;
                atlas.getOrInsertWith(gpui.AtlasKey.Image(key++, 0), () -> source);
            }
            final start = now();
            atlas.upload();
            times.push(now() - start);
        }
        times.sort(Reflect.compare);
        var sum = 0.0;
        for (t in times) sum += t;
        print('atlas upload: ${fmt(times[times.length >> 1])} ms median, total ${fmt(sum)} ms over ${times.length} uploads, ${atlas.textures.length} pages');
        atlas.destroy();
    }

    public function run():Void {
        #if js
        // `web-run.js --profile`: wait until it has enabled the DevTools
        // profiler, which records the `console.profile` blocks
        if (env('GPUI_BENCH_PROFILE') == '1' && isElectron() && !isNode() && js.Syntax.code("window.gpuiBenchProfilerReady") != true) {
            haxe.Timer.delay(run, 100);
            return;
        }
        #end
        if (env('GPUI_BENCH_ATLAS') == '1') {
            atlasBench();
            exit(0);
            return;
        }
        print('gpui benchmark ($target), ${scenarios.length} scenario(s): ' + [for (s in scenarios) s.name].join(', ') + ', $frames measured frames, $runs run(s)' + (screen ? ', on screen' : '')
            + (renderToTexture != null ? ', renderToTexture $renderToTexture' : '')
            + (partialRendering != null ? ', partialRendering $partialRendering' : ''));
        final tasks:Array<(Void->Void)->Void> = [];
        for (scenario in scenarios) {
            for (caching in scenario.cachedModes) {
                if (only != null && (only == 'cached') != caching) {
                    continue;
                }
                tasks.push(done -> runMode(scenario, caching, done));
            }
        }
        var index = 0;
        function next() {
            if (index >= tasks.length) {
                finish();
                return;
            }
            final task = tasks[index++];
            task(next);
        }
        next();
    }

    function finish():Void {
        if (written.length > 0) {
            print('results: ' + written.join(', '));
        }
        exit(failed ? 1 : 0);
    }

    function runMode(scenario:Scenario, caching:Bool, done:Void->Void):Void {
        final window = scenario.setup(app, caching);
        if (renderToTexture != null) {
            window.renderable.renderToTexture = renderToTexture;
        }
        if (partialRendering != null) {
            window.renderable.partialRendering = partialRendering;
        }
        AllocationCounters.reset();
        window.draw();
        final elementCount = AllocationCounters.divs + AllocationCounters.texts + AllocationCounters.svgs + AllocationCounters.viewElements;
        if (Std.isOfType(scenario, IdleScenario)) {
            idle(cast scenario, window, caching, elementCount, () -> {
                scenario.teardown();
                window.destroy();
                done();
            });
            return;
        }
        if (soakSeconds > 0) {
            soak(scenario, window, caching, () -> {
                scenario.teardown();
                window.destroy();
                done();
            });
            return;
        }
        if (screen) {
            ceramic.App.app.screen.add(window.renderable);
        }
        var run = 0;
        function nextRun() {
            if (run >= runs) {
                if (screen) {
                    ceramic.App.app.screen.remove(window.renderable);
                }
                scenario.teardown();
                window.destroy();
                done();
                return;
            }
            measure(scenario, window, caching, elementCount, run++, nextRun);
        }
        nextRun();
    }

    function measure(scenario:Scenario, window:Window, caching:Bool, elementCount:Int, run:Int, done:Void->Void):Void {
        final times:Array<Float> = [];
        final wallTimes:Array<Float> = [];
        var renderedViews = 0;
        var reusedViews = 0;
        var counters = 0;
        var anyElements = 0;
        var pathRasterizations = 0;
        var minorPausesBefore = 0.0;
        var minorPauseTotalBefore = 0.0;
        var volumeBefore = 0.0;
        var lastTick = 0.0;
        final drawTimes:Array<Float> = [];
        var drawStart = 0.0;
        var measuringDraws = false;
        var cpuBefore = 0.0;
        final onBeginDraw = () -> drawStart = now();
        final gpuTimes:Array<Float> = [];
        final measureGpu = env('GPUI_BENCH_GPU') == '1';
        final onFinishDraw = () -> {
            if (measuringDraws) drawTimes.push(now() - drawStart);
            #if clay
            if (measureGpu) {
                final start = now();
                #if web
                // `finish()` does not wait in browsers: reading a pixel back does
                clay.opengl.GL.readPixels(0, 0, 1, 1, clay.opengl.GL.RGBA, clay.opengl.GL.UNSIGNED_BYTE, gpuProbe);
                #else
                clay.opengl.GL.finish();
                #end
                if (measuringDraws) gpuTimes.push(now() - start);
            }
            #end
        };
        function frameBody(frame:Int):Void {
            measuringDraws = frame > WARMUP_FRAMES;
            if (frame == WARMUP_FRAMES + 1) {
                cpuBefore = cpuTime();
                gpui.platform.SceneRenderable.partialStatsDraws = 0;
                gpui.platform.SceneRenderable.partialStatsPartialDraws = 0;
                gpui.platform.SceneRenderable.partialStatsFullDraws = 0;
                gpui.platform.SceneRenderable.partialStatsArea = 0;
                gpui.platform.SceneRenderable.partialStatsTotalArea = 0;
            }
            final measured = frame >= WARMUP_FRAMES;
            if (frame == WARMUP_FRAMES) {
                FrameProfiler.reset();
                minorPausesBefore = gcInfo(MEM_INFO_MINOR_PAUSE_COUNT);
                minorPauseTotalBefore = gcInfo(MEM_INFO_TOTAL_MINOR_PAUSE_MS);
                volumeBefore = gcInfo(MEM_INFO_ALLOCATION_VOLUME);
                blockCyclesBefore = gcInfo(MEM_INFO_CYCLE_COUNT);
                blockProcessCpuBefore = cpuTime();
                blockWallBefore = now();
                blockThreadCpu.resize(0);
                blockQuietCpu.resize(0);
                blockCycleCpu.resize(0);
                AllocProfile.start();
            }
            final countersBefore = AllocationCounters.total();
            final elementsBefore = AnyElement.allocatedCount;
            final rasterizedBefore = gpui.PathRasterizer.rasterizedCount;
            final start = now();
            final threadStart = threadCpuTime();
            final cycleAtStart = gcInfo(MEM_INFO_CYCLE_ACTIVE);
            final minorsAtStart = gcInfo(MEM_INFO_MINOR_PAUSE_COUNT);
            final cyclesAtStart = gcInfo(MEM_INFO_CYCLE_COUNT);
            if (measured && lastTick > 0) {
                wallTimes.push(start - lastTick);
            }
            lastTick = start;
            FrameProfiler.begin(FrameProfiler.UPDATE);
            scenario.step(frame);
            ceramic.App.app.flushImmediate();
            FrameProfiler.end(FrameProfiler.UPDATE);
            window.drawIfDirty();
            final time = now() - start;
            if (measured) {
                times.push(time);
                final cpu = threadCpuTime() - threadStart;
                blockThreadCpu.push(cpu);
                // Frames without any collection work against frames run
                // while a concurrent cycle is active (no minor in either)
                if (gcInfo(MEM_INFO_MINOR_PAUSE_COUNT) == minorsAtStart) {
                    if (cycleAtStart == 0 && gcInfo(MEM_INFO_CYCLE_ACTIVE) == 0 && gcInfo(MEM_INFO_CYCLE_COUNT) == cyclesAtStart)
                        blockQuietCpu.push(cpu);
                    else
                        blockCycleCpu.push(cpu);
                }
                renderedViews += window.renderedViewCount;
                reusedViews += window.reusedViewCount;
                counters += AllocationCounters.total() - countersBefore;
                anyElements += AnyElement.allocatedCount - elementsBefore;
                pathRasterizations += gpui.PathRasterizer.rasterizedCount - rasterizedBefore;
            }
        }
        final total = WARMUP_FRAMES + frames;
        final label = '${scenario.name}-${caching ? 'cached' : 'full'}-r${run + 1}';
        if (!screen) {
            for (frame in 0...total) {
                if (frame == WARMUP_FRAMES) webMark('begin', label);
                frameBody(frame);
            }
            webMark('end', label);
            writeAllocProfile(label);
            lastPathRasterizations = pathRasterizations;
            finishMeasure(scenario, window, caching, elementCount, run, times, wallTimes, renderedViews, reusedViews, counters, anyElements, minorPausesBefore, minorPauseTotalBefore, gcInfo(MEM_INFO_ALLOCATION_VOLUME) - volumeBefore);
            done();
            return;
        }
        // On screen: one step per tick of the real update loop, Ceramic
        // renders the window after each update
        var frame = 0;
        var handler:Null<Float->Void> = null;
        ceramic.App.app.onBeginDraw(owner, onBeginDraw);
        ceramic.App.app.onFinishDraw(owner, onFinishDraw);
        handler = _ -> {
            if (frame < total) {
                if (frame == WARMUP_FRAMES) webMark('begin', label);
                frameBody(frame++);
                return;
            }
            webMark('end', label);
            ceramic.App.app.offUpdate(handler);
            ceramic.App.app.offBeginDraw(onBeginDraw);
            ceramic.App.app.offFinishDraw(onFinishDraw);
            drawTimes.sort(Reflect.compare);
            if (drawTimes.length > 0) {
                print('  ceramic draw per frame: ${fmt(drawTimes[drawTimes.length >> 1])} ms median, p99 ${fmt(percentile(drawTimes, 0.99))} ms, max ${fmt(drawTimes[drawTimes.length - 1])} ms');
                if (gpui.platform.SceneRenderable.verifyPartialRendering) {
                    print('  partial rendering check: ${gpui.platform.SceneRenderable.partialVerifiedFrames} frames compared, '
                        + '${gpui.platform.SceneRenderable.partialMismatchedFrames} differ'
                        + (gpui.platform.SceneRenderable.partialFirstMismatch != null ? ' (${gpui.platform.SceneRenderable.partialFirstMismatch})' : ''));
                }
                if (window.renderable.partialRendering) {
                    print('  partial rendering: ${gpui.platform.SceneRenderable.partialStatsDraws} texture draws, ${gpui.platform.SceneRenderable.partialStatsPartialDraws} partial, ${gpui.platform.SceneRenderable.partialStatsFullDraws} full, redrawn area '
                        + fmt(gpui.platform.SceneRenderable.partialStatsTotalArea > 0 ? 100 * gpui.platform.SceneRenderable.partialStatsArea / gpui.platform.SceneRenderable.partialStatsTotalArea : 0) + ' %');
                }
            }
            lastPathRasterizations = pathRasterizations;
            lastDrawMedian = drawTimes.length > 0 ? drawTimes[drawTimes.length >> 1] : 0.0;
            lastDrawP99 = drawTimes.length > 0 ? percentile(drawTimes, 0.99) : 0.0;
            lastDrawMax = drawTimes.length > 0 ? drawTimes[drawTimes.length - 1] : 0.0;
            lastCpuPerFrame = (cpuTime() - cpuBefore) / (frames - 1);
            gpuTimes.sort(Reflect.compare);
            lastGpuFinishMedian = gpuTimes.length > 0 ? gpuTimes[gpuTimes.length >> 1] : 0.0;
            lastGpuFinishP99 = gpuTimes.length > 0 ? percentile(gpuTimes, 0.99) : 0.0;
            if (gpuTimes.length > 0) {
                print('  glFinish wait per frame: ${fmt(lastGpuFinishMedian)} ms median, p99 ${fmt(lastGpuFinishP99)} ms');
            }
            #if cpp
            print('  process CPU per frame: ${fmt(lastCpuPerFrame)} ms');
            #end
            finishMeasure(scenario, window, caching, elementCount, run, times, wallTimes, renderedViews, reusedViews, counters, anyElements, minorPausesBefore, minorPauseTotalBefore, gcInfo(MEM_INFO_ALLOCATION_VOLUME) - volumeBefore);
            done();
        };
        ceramic.App.app.onUpdate(owner, handler);
    }

    /**
     * Endurance run (`GPUI_BENCH_SOAK_SECONDS`): the scenario's frames for
     * that long, through the real update loop in slices of about
     * `SOAK_SLICE_MS` (so timers and other deferred work run between them
     * like in an app). Every `soakSampleSeconds` it records the GC state
     * (hxcpp usage, reserved, current and large memory, minor and full
     * collection counts, concurrent cycles, allocation volume; on node and
     * the web the V8 heap) and the frame times of the interval; every
     * `soakLiveSeconds` the live memory right after a full collection. The
     * series and a summary (least squares slopes after `soakWarmupSeconds`)
     * go to `<timestamp>-<target>-<scenario>-<mode>-soak.json`.
     */
    /** Fields of a soak sample, in `soak.samples` of the result */
    static final SOAK_SAMPLE_FIELDS = ['t', 'frames', 'usage', 'reserved', 'current', 'large', 'minorCount', 'minorMaxMs', 'minorTotalMs', 'fullCount',
        'cycles', 'cycleActive', 'volume', 'jsUsed', 'jsTotal', 'intervalFrames', 'frameMedianMs', 'frameP99Ms', 'frameMaxMs', 'rss',
        'threadCpuMedianMs', 'threadCpuP99Ms', 'processCpu', 'heapGoal', 'heapWaits', 'heapReleased'];

    /** Fields of a live memory sample, in `soak.lives` of the result */
    static final SOAK_LIVE_FIELDS = ['t', 'frames', 'live', 'liveBytes', 'large', 'usageBefore', 'reservedBefore', 'reservedAfter', 'jsLive', 'jsTotal', 'collectMs'];

    function soak(scenario:Scenario, window:Window, caching:Bool, done:Void->Void):Void {
        final label = '${scenario.name}-${caching ? 'cached' : 'full'}';
        print('soak $label: ${soakSeconds} s, samples every ${soakSampleSeconds} s, live memory every ${soakLiveSeconds} s, warmup ${soakWarmupSeconds} s');
        // The series are stored in flat arrays allocated up front: records
        // added during the run would themselves show up as a slow growth of
        // the live memory
        final sampleCapacity = Std.int(soakSeconds / Math.max(soakSampleSeconds, 0.1)) + 4;
        final liveCapacity = soakLiveSeconds > 0 ? Std.int(soakSeconds / soakLiveSeconds) + 4 : 0;
        final sampleData:Array<Float> = [for (_ in 0...sampleCapacity * SOAK_SAMPLE_FIELDS.length) 0.0];
        final liveData:Array<Float> = [for (_ in 0...liveCapacity * SOAK_LIVE_FIELDS.length) 0.0];
        var sampleCount = 0;
        var liveCount = 0;
        final intervalTimes:Array<Float> = [for (_ in 0...200000) 0.0];
        final intervalCpu:Array<Float> = [for (_ in 0...200000) 0.0];
        var intervalCount = 0;
        final start = now();
        var frame = 0;
        var nextSample = start + soakSampleSeconds * 1000;
        var nextLive = soakLiveSeconds > 0 ? start + soakLiveSeconds * 1000 : Math.POSITIVE_INFINITY;
        var maxReserved = 0.0;
        var lastLiveAt = -1.0;
        var handler:Null<Float->Void> = null;
        function seconds(at:Float):Float return (at - start) / 1000;
        function sample(at:Float):Void {
            if (sampleCount >= sampleCapacity) return;
            final reserved = gcInfo(cpp_MEM_INFO_RESERVED);
            if (reserved > maxReserved) maxReserved = reserved;
            final heap = jsHeap();
            // Frame times of the interval: partial sort of the used range
            final n = intervalCount;
            final times = intervalTimes.slice(0, n);
            times.sort(Reflect.compare);
            final cpus = intervalCpu.slice(0, n);
            cpus.sort(Reflect.compare);
            final values = [seconds(at), frame, gcInfo(cpp_MEM_INFO_USAGE), reserved, gcInfo(cpp_MEM_INFO_CURRENT), gcInfo(cpp_MEM_INFO_LARGE),
                gcInfo(MEM_INFO_MINOR_PAUSE_COUNT), gcInfo(MEM_INFO_MAX_MINOR_PAUSE_MS), gcInfo(MEM_INFO_TOTAL_MINOR_PAUSE_MS), gcInfo(MEM_INFO_FULL_COUNT),
                gcInfo(MEM_INFO_CYCLE_COUNT), gcInfo(MEM_INFO_CYCLE_ACTIVE), gcInfo(MEM_INFO_ALLOCATION_VOLUME), heap[0], heap[1], n,
                n > 0 ? times[n >> 1] : 0.0, percentile(times, 0.99), n > 0 ? times[n - 1] : 0.0, rssBytes(),
                n > 0 ? cpus[n >> 1] : 0.0, percentile(cpus, 0.99), cpuTime(), gcInfo(MEM_INFO_HEAP_GOAL), gcInfo(MEM_INFO_HEAP_WAITS),
                gcInfo(MEM_INFO_HEAP_RELEASED)];
            final base = sampleCount * SOAK_SAMPLE_FIELDS.length;
            for (i in 0...values.length) sampleData[base + i] = values[i];
            sampleCount++;
            intervalCount = 0;
        }
        function live(at:Float):Void {
            if (liveCount >= liveCapacity) return;
            final reservedBefore = gcInfo(cpp_MEM_INFO_RESERVED);
            final usageBefore = gcInfo(cpp_MEM_INFO_USAGE);
            final collectStart = now();
            final heap = fullCollect();
            final collectMs = now() - collectStart;
            final liveBytes = gcInfo(MEM_INFO_FULL_LIVE_BYTES) + gcInfo(cpp_MEM_INFO_LARGE);
            final values = [seconds(at), frame, gcInfo(cpp_MEM_INFO_USAGE), liveBytes, gcInfo(cpp_MEM_INFO_LARGE), usageBefore, reservedBefore,
                gcInfo(cpp_MEM_INFO_RESERVED), heap[0], heap[1], collectMs];
            final base = liveCount * SOAK_LIVE_FIELDS.length;
            for (i in 0...values.length) liveData[base + i] = values[i];
            liveCount++;
            lastLiveAt = seconds(at);
            print('  soak $label t=${Math.round(seconds(at))} s frames=$frame live ${mb(gcInfo(cpp_MEM_INFO_USAGE))} MB, objects ${mb(liveBytes)} MB (reserved before ${mb(reservedBefore)} MB)'
                + #if js ' js live ${mb(heap[0])} MB' + #end '');
        }
        function records(data:Array<Float>, count:Int, fields:Array<String>):Array<Dynamic> {
            return [for (r in 0...count) {
                final record:haxe.DynamicAccess<Float> = {};
                for (i in 0...fields.length) record.set(fields[i], data[r * fields.length + i]);
                (record : Dynamic);
            }];
        }
        function finishSoak():Void {
            ceramic.App.app.offUpdate(handler);
            final end = now();
            final samples = records(sampleData, sampleCount, SOAK_SAMPLE_FIELDS);
            final lives = records(liveData, liveCount, SOAK_LIVE_FIELDS);
            final result = baseResult(scenario, caching, 0, frame, 0);
            final summary = soakSummary(samples, lives, maxReserved);
            result.set('soak', {
                seconds: seconds(end),
                sampleSeconds: soakSampleSeconds,
                liveSeconds: soakLiveSeconds,
                warmupSeconds: soakWarmupSeconds,
                summary: summary,
                samples: samples,
                lives: lives
            });
            print('soak $label summary: ' + haxe.Json.stringify(summary));
            writeResult(result, scenario.name, caching, 0, '-soak');
            done();
        }
        handler = _ -> {
            final sliceEnd = now() + SOAK_SLICE_MS;
            while (true) {
                final frameStart = now();
                final cpuStart = threadCpuTime();
                scenario.step(WARMUP_FRAMES + frame);
                ceramic.App.app.flushImmediate();
                window.drawIfDirty();
                final t = now();
                if (intervalCount < intervalTimes.length) {
                    intervalCpu[intervalCount] = threadCpuTime() - cpuStart;
                    intervalTimes[intervalCount++] = t - frameStart;
                }
                frame++;
                if (t >= nextSample) {
                    sample(t);
                    nextSample += soakSampleSeconds * 1000;
                    if (nextSample < t) nextSample = t + soakSampleSeconds * 1000;
                }
                if (t >= nextLive) {
                    live(t);
                    nextLive += soakLiveSeconds * 1000;
                    if (nextLive < now()) nextLive = now() + soakLiveSeconds * 1000;
                }
                if (seconds(now()) >= soakSeconds) {
                    if (soakLiveSeconds > 0 && (lastLiveAt < 0 || seconds(now()) - lastLiveAt > 1)) {
                        live(now());
                    }
                    finishSoak();
                    return;
                }
                if (now() >= sliceEnd) break;
            }
        };
        ceramic.App.app.onUpdate(owner, handler);
    }

    /**
     * Least squares slopes (MB per minute) of the soak series after the
     * warmup: live memory (after a full collection), reserved and used
     * memory, and the V8 heap on node and the web. A leak is suspected when
     * the live memory slope is significant (above twice its standard error)
     * and both it and the floor of the live memory (minimum of the second
     * half against the first half) grow by more than 1 MB and 2 % over the
     * measured span: the live samples are noisy (what the conservative stack
     * scan keeps, line fragmentation without memInfo 120).
     */
    function soakSummary(samples:Array<Dynamic>, lives:Array<Dynamic>, maxReserved:Float):Dynamic {
        function slope(series:Array<Dynamic>, field:String):Dynamic {
            final xs:Array<Float> = [];
            final ys:Array<Float> = [];
            for (s in series) {
                final t:Float = s.t;
                if (t < soakWarmupSeconds) continue;
                xs.push(t / 60);
                ys.push((Reflect.field(s, field) : Float) / (1024 * 1024));
            }
            final n = xs.length;
            if (n < 2) return {points: n, mbPerMinute: 0.0, stderr: 0.0, meanMb: n == 1 ? ys[0] : 0.0, firstMb: n == 1 ? ys[0] : 0.0, lastMb: n == 1 ? ys[0] : 0.0,
                spanMinutes: 0.0, floorFirstHalfMb: n == 1 ? ys[0] : 0.0, floorSecondHalfMb: n == 1 ? ys[0] : 0.0};
            var mx = 0.0, my = 0.0;
            for (i in 0...n) { mx += xs[i]; my += ys[i]; }
            mx /= n;
            my /= n;
            var sxy = 0.0, sxx = 0.0;
            for (i in 0...n) { sxy += (xs[i] - mx) * (ys[i] - my); sxx += (xs[i] - mx) * (xs[i] - mx); }
            final k = sxx > 0 ? sxy / sxx : 0.0;
            var residuals = 0.0;
            for (i in 0...n) {
                final r = ys[i] - (my + k * (xs[i] - mx));
                residuals += r * r;
            }
            final stderr = n > 2 && sxx > 0 ? Math.sqrt(residuals / (n - 2) / sxx) : 0.0;
            var floor1 = Math.POSITIVE_INFINITY, floor2 = Math.POSITIVE_INFINITY;
            for (i in 0...n) {
                if (i < n >> 1) floor1 = Math.min(floor1, ys[i]) else floor2 = Math.min(floor2, ys[i]);
            }
            return {points: n, mbPerMinute: k, stderr: stderr, meanMb: my, firstMb: ys[0], lastMb: ys[n - 1], spanMinutes: xs[n - 1] - xs[0],
                floorFirstHalfMb: floor1, floorSecondHalfMb: floor2};
        }
        // hxcpp: the exact object bytes when this hxcpp counts them (memInfo
        // 120), otherwise the used lines (fragmentation included)
        final exact = lives.length > 0 && (lives[lives.length - 1].liveBytes : Float) > (lives[lives.length - 1].large : Float);
        final live:Dynamic = slope(lives, #if js 'jsLive' #else exact ? 'liveBytes' : 'live' #end);
        final growth:Float = live.mbPerMinute * live.spanMinutes;
        final floorGrowth:Float = live.floorSecondHalfMb - live.floorFirstHalfMb;
        final threshold = Math.max(1.0, 0.02 * (live.meanMb : Float));
        final leak = live.points >= 4 && live.mbPerMinute > 2 * live.stderr && growth > threshold && floorGrowth > threshold;
        final last:Dynamic = samples.length > 0 ? samples[samples.length - 1] : null;
        final first:Dynamic = samples.length > 0 ? samples[0] : null;
        return {
            live: live,
            liveLines: slope(lives, 'live'),
            liveBytes: slope(lives, 'liveBytes'),
            jsLive: slope(lives, 'jsLive'),
            reserved: slope(samples, 'reserved'),
            usage: slope(samples, 'usage'),
            jsUsed: slope(samples, 'jsUsed'),
            maxReservedMb: maxReserved / (1024 * 1024),
            frames: last != null ? last.frames : 0,
            minorCollections: last != null ? (last.minorCount : Float) - (first.minorCount : Float) : 0,
            fullCollections: last != null ? (last.fullCount : Float) : 0,
            concurrentCycles: last != null ? (last.cycles : Float) - (first.cycles : Float) : 0,
            leakSuspected: leak
        };
    }

    static function mb(bytes:Float):String {
        return fmt(bytes / (1024 * 1024));
    }

    /** V8 heap used and total (node and web), zeros elsewhere */
    static function jsHeap():Array<Float> {
        #if js
        if (isNode()) {
            final usage:Dynamic = js.Syntax.code("process.memoryUsage()");
            return [usage.heapUsed, usage.heapTotal];
        }
        final used:Float = js.Syntax.code("(performance.memory != null ? performance.memory.usedJSHeapSize : 0)");
        final total:Float = js.Syntax.code("(performance.memory != null ? performance.memory.totalJSHeapSize : 0)");
        return [used, total];
        #else
        return [0.0, 0.0];
        #end
    }

    /**
     * A full collection: `Gc.run(true)` on hxcpp (a classic, compacting
     * collection), V8's `gc()` on node and the web (exposed at run time
     * through `v8.setFlagsFromString` when the engine was not started with
     * `--expose-gc`). Returns the V8 heap afterwards.
     */
    static function fullCollect():Array<Float> {
        #if cpp
        cpp.vm.Gc.run(true);
        #elseif js
        js.Syntax.code("(function() {
            var g = typeof gc === 'function' ? gc : null;
            if (g == null && typeof require === 'function') {
                try {
                    require('v8').setFlagsFromString('--expose-gc');
                    g = require('vm').runInNewContext('gc');
                } catch (e) {}
            }
            if (g != null) { g(); g(); }
        })()");
        #end
        return jsHeap();
    }

    static function envFloat(name:String, defaultValue:Float):Float {
        final value = env(name);
        if (value == null || value == '') {
            return defaultValue;
        }
        final parsed = Std.parseFloat(value);
        return Math.isNaN(parsed) || parsed < 0 ? defaultValue : parsed;
    }

    function finishMeasure(scenario:Scenario, window:Window, caching:Bool, elementCount:Int, run:Int, times:Array<Float>, wallTimes:Array<Float>,
        renderedViews:Int, reusedViews:Int, counters:Int, anyElements:Int, minorPausesBefore:Float, minorPauseTotalBefore:Float, allocatedVolume:Float):Void {
        var bytes = 0.0;
        final blockSeconds = (now() - blockWallBefore) / 1000;
        final processCpuPerFrame = (cpuTime() - blockProcessCpuBefore) / frames;
        final cyclesPerSecond = blockSeconds > 0 ? (gcInfo(MEM_INFO_CYCLE_COUNT) - blockCyclesBefore) / blockSeconds : 0.0;
        final threadCpu = blockThreadCpu.copy();
        threadCpu.sort(Reflect.compare);
        final minorPauses = gcInfo(MEM_INFO_MINOR_PAUSE_COUNT) - minorPausesBefore;
        final minorPauseTotal = gcInfo(MEM_INFO_TOTAL_MINOR_PAUSE_MS) - minorPauseTotalBefore;
        final minorPauseLast = gcInfo(MEM_INFO_LAST_MINOR_PAUSE_MS);
        final minorPauseMax = gcInfo(MEM_INFO_MAX_MINOR_PAUSE_MS);
        final phases:haxe.DynamicAccess<Float> = {};
        final phaseCounts:haxe.DynamicAccess<Int> = {};
        for (phase in 0...FrameProfiler.PHASE_COUNT) {
            phases.set(FrameProfiler.NAMES[phase], FrameProfiler.ms(phase) / frames);
            phaseCounts.set(FrameProfiler.NAMES[phase], FrameProfiler.count(phase));
        }
        // Bytes allocated (native): hxcpp's allocation volume over the measured
        // block when this fork exposes it (memInfo 117), otherwise 20 more
        // frames with the GC disabled (not reliable with the generational GC)
        #if cpp
        if (allocatedVolume > 0) {
            bytes = allocatedVolume;
        }
        else {
            cpp.vm.Gc.run(true);
            gcEnable(false);
            final bytesBefore = heapBytes();
            for (frame in 0...BYTES_FRAMES) {
                scenario.step(WARMUP_FRAMES + frames + frame);
                ceramic.App.app.flushImmediate();
                window.drawIfDirty();
            }
            bytes = (heapBytes() - bytesBefore) * frames / BYTES_FRAMES;
            gcEnable(true);
            cpp.vm.Gc.run(true);
        }
        #end
        times.sort(Reflect.compare);
        var sum = 0.0;
        for (t in times) sum += t;
        final mean = sum / times.length;
        final median = times[times.length >> 1];
        final modeLabel = caching ? 'cached     ' : 'full render';
        final runLabel = runs > 1 ? ' run ${run + 1}/$runs' : '';
        print('${scenario.name} $modeLabel$runLabel: $elementCount elements, draw ${fmt(mean)} ms mean, ${fmt(median)} ms median, '
            + 'p95 ${fmt(percentile(times, 0.95))} ms, p99 ${fmt(percentile(times, 0.99))} ms, max ${fmt(times[times.length - 1])} ms, '
            + 'views rendered ${fmt(renderedViews / frames)} / reused ${fmt(reusedViews / frames)} per frame, '
            + 'objects created ${fmt(counters / frames)} per frame (new AnyElement ${fmt(anyElements / frames)}), '
            + 'path tiles rasterized ${fmt(lastPathRasterizations / frames)} per frame'
            #if cpp + ', ${fmt(bytes / frames / 1024)} KiB allocated per frame' #end);
        wallTimes.sort(Reflect.compare);
        final wallMedian = wallTimes.length > 0 ? wallTimes[wallTimes.length >> 1] : 0.0;
        if (screen && wallTimes.length > 0) {
            print('  wall time between ticks: ${fmt(wallMedian)} ms median, p99 ${fmt(percentile(wallTimes, 0.99))} ms, max ${fmt(wallTimes[wallTimes.length - 1])} ms');
        }
        if (FrameProfiler.ENABLED) {
            print('  phases per frame (ms): ' + [for (phase in 0...FrameProfiler.PHASE_COUNT) '${FrameProfiler.NAMES[phase]}=${fmt(phases.get(FrameProfiler.NAMES[phase]))}'].join(' '));
        }
        #if cpp
        if (minorPauses > 0 || minorPauseTotal > 0) {
            print('  minor GC pauses: $minorPauses, total ${fmt(minorPauseTotal)} ms, max ${fmt(minorPauseMax)} ms, heap reserved ${mb(gcInfo(cpp_MEM_INFO_RESERVED))} MB, RSS ${mb(rssBytes())} MB, '
                + 'cycles ${fmt(cyclesPerSecond)} per s, main thread CPU ${fmt(threadCpu.length > 0 ? threadCpu[threadCpu.length >> 1] : 0.0)} ms median per frame, process CPU ${fmt(processCpuPerFrame)} ms per frame');
        }
        #end
        AllocationCounters.reset();
        window.draw();
        print('  objects created by one full frame: ' + AllocationCounters.summary());
        final allocation:haxe.DynamicAccess<Int> = {};
        allocation.set('divs', AllocationCounters.divs);
        allocation.set('texts', AllocationCounters.texts);
        allocation.set('svgs', AllocationCounters.svgs);
        allocation.set('viewElements', AllocationCounters.viewElements);
        allocation.set('styles', AllocationCounters.styles);
        allocation.set('styleRefinements', AllocationCounters.styleRefinements);
        allocation.set('textStyles', AllocationCounters.textStyles);
        allocation.set('globalElementIds', AllocationCounters.globalElementIds);
        allocation.set('layoutNodes', AllocationCounters.layoutNodes);

        final result = baseResult(scenario, caching, run, frames, elementCount);
        result.set('warmupFrames', WARMUP_FRAMES);
        result.set('metrics', {
            meanMs: mean,
            medianMs: median,
            p50Ms: percentile(times, 0.50),
            p95Ms: percentile(times, 0.95),
            p99Ms: percentile(times, 0.99),
            maxMs: times[times.length - 1],
            renderedViewsPerFrame: renderedViews / frames,
            reusedViewsPerFrame: reusedViews / frames,
            objectsPerFrame: counters / frames,
            anyElementsPerFrame: anyElements / frames,
            bytesPerFrame: bytes / frames,
            onScreen: screen,
            wallMedianMs: wallMedian,
            wallP99Ms: wallTimes.length > 0 ? percentile(wallTimes, 0.99) : 0.0,
            wallMaxMs: wallTimes.length > 0 ? wallTimes[wallTimes.length - 1] : 0.0,
            drawMedianMs: screen ? lastDrawMedian : 0.0,
            pathRasterizationsPerFrame: lastPathRasterizations / frames,
            drawP99Ms: screen ? lastDrawP99 : 0.0,
            drawMaxMs: screen ? lastDrawMax : 0.0,
            cpuMsPerFrame: screen ? lastCpuPerFrame : 0.0,
            gpuFinishMedianMs: screen ? lastGpuFinishMedian : 0.0,
            gpuFinishP99Ms: screen ? lastGpuFinishP99 : 0.0,
            renderToTexture: window.renderable.renderToTexture,
            partialRendering: window.renderable.partialRendering,
            phasesMsPerFrame: phases,
            phaseCounts: phaseCounts,
            gc: {
                minorPauses: minorPauses,
                lastMinorPauseMs: minorPauseLast,
                maxMinorPauseMs: minorPauseMax,
                totalMinorPauseMs: minorPauseTotal,
                reservedBytes: gcInfo(cpp_MEM_INFO_RESERVED),
                usedBytes: gcInfo(cpp_MEM_INFO_USAGE),
                rssBytes: rssBytes(),
                cyclesPerSecond: cyclesPerSecond
            },
            threadCpuMedianMs: threadCpu.length > 0 ? threadCpu[threadCpu.length >> 1] : 0.0,
            threadCpuP99Ms: percentile(threadCpu, 0.99),
            threadCpuMeanMs: {
                var sum = 0.0;
                for (t in threadCpu) sum += t;
                threadCpu.length > 0 ? sum / threadCpu.length : 0.0;
            },
            processCpuMsPerFrame: processCpuPerFrame,
            quietCpuMedianMs: {
                final a = blockQuietCpu.copy();
                a.sort(Reflect.compare);
                a.length > 0 ? a[a.length >> 1] : 0.0;
            },
            quietFrames: blockQuietCpu.length,
            cycleCpuMedianMs: {
                final a = blockCycleCpu.copy();
                a.sort(Reflect.compare);
                a.length > 0 ? a[a.length >> 1] : 0.0;
            },
            cycleFrames: blockCycleCpu.length
        });
        result.set('fullFrameAllocations', allocation);
        writeResult(result, scenario.name, caching, run);
    }

    /**
     * Idle frames through the real update loop: nothing changes, nothing is
     * drawn, nothing is allocated (by gpui or by the renderable).
     */
    function idle(scenario:IdleScenario, window:Window, caching:Bool, elementCount:Int, done:Void->Void):Void {
        final idleFrames = scenario.idleFrames;
        final scene = window.renderedScene();
        final drawCount = window.drawCount;
        final countersBefore = AllocationCounters.total();
        var ticks = 0;
        var bytesBefore = 0.0;
        var cpuBefore = 0.0;
        var wallBefore = 0.0;
        final drawTimes:Array<Float> = [];
        var drawStart = 0.0;
        final onBeginDraw = () -> drawStart = now();
        final onFinishDraw = () -> {
            if (ticks > 10 && ticks <= 10 + idleFrames) drawTimes.push(now() - drawStart);
        };
        ceramic.App.app.onBeginDraw(owner, onBeginDraw);
        ceramic.App.app.onFinishDraw(owner, onFinishDraw);
        ceramic.App.app.screen.add(window.renderable);
        var handler:Null<Float->Void> = null;
        handler = _ -> {
            ticks++;
            if (ticks == 10) {
                // Measure the idle frames with the GC disabled
                gcEnable(false);
                bytesBefore = heapBytes();
                cpuBefore = cpuTime();
                wallBefore = now();
                webMark('begin', '${scenario.name}-${caching ? 'cached' : 'full'}-r1');
            }
            else if (ticks == 10 + idleFrames) {
                webMark('end', '${scenario.name}-${caching ? 'cached' : 'full'}-r1');
                final bytes = heapBytes() - bytesBefore;
                final cpuMs = (cpuTime() - cpuBefore) / idleFrames;
                final wallMs = (now() - wallBefore) / idleFrames;
                gcEnable(true);
                ceramic.App.app.offUpdate(handler);
                ceramic.App.app.offBeginDraw(onBeginDraw);
                ceramic.App.app.offFinishDraw(onFinishDraw);
                drawTimes.sort(Reflect.compare);
                final drawMedian = drawTimes.length > 0 ? drawTimes[drawTimes.length >> 1] : 0.0;
                print('  idle frame: ceramic draw ${fmt(drawMedian)} ms median, p99 ${fmt(percentile(drawTimes, 0.99))} ms'
                    #if cpp + ', process CPU ${fmt(cpuMs)} ms' #end + ', wall ${fmt(wallMs)} ms per frame'
                    + ', renderToTexture ${window.renderable.renderToTexture}');
                final draws = window.drawCount - drawCount;
                final objects = AllocationCounters.total() - countersBefore;
                final ok = draws == 0 && scene == window.renderedScene() && objects == 0;
                print('${scenario.name}: $idleFrames frames, $draws draws, objects created $objects'
                    #if cpp + ', ${Std.int(bytes)} bytes allocated by the whole app' #end + (ok ? '' : ' (FAILED)'));
                if (!ok) {
                    failed = true;
                }
                final result = baseResult(scenario, caching, 0, idleFrames, elementCount);
                result.set('metrics', {
                    draws: draws,
                    objectsCreated: objects,
                    bytesTotal: bytes,
                    bytesPerFrame: bytes / idleFrames,
                    drawMedianMs: drawMedian,
                    drawP99Ms: percentile(drawTimes, 0.99),
                    cpuMsPerFrame: #if cpp cpuMs #else 0.0 #end,
                    wallMsPerFrame: wallMs,
                    renderToTexture: window.renderable.renderToTexture,
                    ok: ok
                });
                writeResult(result, scenario.name, caching, 0);
                ceramic.App.app.screen.remove(window.renderable);
                done();
            }
        };
        ceramic.App.app.onUpdate(owner, handler);
    }

    function baseResult(scenario:Scenario, caching:Bool, run:Int, frames:Int, elementCount:Int):haxe.DynamicAccess<Dynamic> {
        final result:haxe.DynamicAccess<Dynamic> = {};
        result.set('timestamp', timestamp);
        result.set('target', target);
        result.set('scenario', scenario.name);
        result.set('mode', caching ? 'cached' : 'full');
        result.set('run', run);
        result.set('runs', runs);
        result.set('frames', frames);
        result.set('elements', elementCount);
        result.set('build', buildInfo());
        return result;
    }

    static function buildInfo():Dynamic {
        return {
            defines: {
                gpui_count_allocations: #if gpui_count_allocations true #else false #end,
                gpui_profile_frames: #if gpui_profile_frames true #else false #end,
                debug: #if debug true #else false #end
            },
            gc: #if cpp {
                generational: #if HXCPP_GC_GENERATIONAL true #else false #end,
                concurrent: #if HXCPP_GC_CONCURRENT true #else false #end
            } #else null #end,
            system: #if sys Sys.systemName() #elseif js (isNode() ? 'node' : 'web') #else 'unknown' #end
        };
    }

    function writeResult(result:haxe.DynamicAccess<Dynamic>, scenario:String, caching:Bool, run:Int, ?kind:String):Void {
        final json = haxe.Json.stringify(result);
        print('BENCH_JSON ' + json);
        final suffix = (runs > 1 ? '-r${run + 1}' : '') + (kind != null ? kind : '');
        final fileName = '$timestamp-$target-$scenario-${caching ? 'cached' : 'full'}$suffix.json';
        final dir = resultsDirectory();
        if (dir == null) {
            return;
        }
        final path = dir + '/' + fileName;
        final pretty = haxe.Json.stringify(result, null, '  ') + '\n';
        try {
            #if js
            if (isNode()) {
                final fs:Dynamic = js.Syntax.code("require('fs')");
                fs.mkdirSync(dir, {recursive: true});
                fs.writeFileSync(path, pretty);
                written.push(path);
            }
            #elseif sys
            if (!sys.FileSystem.exists(dir)) {
                sys.FileSystem.createDirectory(dir);
            }
            sys.io.File.saveContent(path, pretty);
            written.push(path);
            #end
        }
        catch (e:Dynamic) {
            print('warning: could not write $path: $e');
        }
    }

    /**
     * `GPUI_BENCH_RESULTS`, or the `results` folder of the bench project
     * found by walking up from the working directory (the folder holding
     * `src/BenchRunner.hx`). Null on the web (no file system).
     */
    /**
     * With `--variant allocprof`: the allocation sites of the block just
     * measured (`AllocProfile`), printed and written next to the results as
     * `<label>-allocs.txt`.
     */
    function writeAllocProfile(label:String):Void {
        final report = AllocProfile.stop(frames, envInt('GPUI_BENCH_ALLOC_TOP', 60));
        if (report == null) return;
        print('  allocation profile of $label:');
        print(report);
        #if sys
        final dir = resultsDirectory();
        if (dir != null) {
            sys.FileSystem.createDirectory(dir);
            sys.io.File.saveContent(dir + '/' + label + '-allocs.txt', report);
        }
        #end
    }

    function resultsDirectory():Null<String> {
        if (resultsDir != null) {
            return resultsDir;
        }
        final fromEnv = env('GPUI_BENCH_RESULTS');
        if (fromEnv != null && fromEnv != '') {
            resultsDir = fromEnv;
            return resultsDir;
        }
        var dir:Null<String> = null;
        #if js
        if (!isNode()) {
            return null;
        }
        dir = js.Syntax.code('process.cwd()');
        #elseif sys
        dir = Sys.getCwd();
        #else
        return null;
        #end
        var current = haxe.io.Path.removeTrailingSlashes(haxe.io.Path.normalize(dir));
        for (_ in 0...8) {
            if (fileExists(current + '/src/BenchRunner.hx')) {
                resultsDir = current + '/results';
                return resultsDir;
            }
            final parent = haxe.io.Path.directory(current);
            if (parent == current || parent == '') {
                break;
            }
            current = parent;
        }
        resultsDir = haxe.io.Path.removeTrailingSlashes(haxe.io.Path.normalize(dir)) + '/results';
        return resultsDir;
    }

    static function fileExists(path:String):Bool {
        #if js
        return js.Syntax.code("require('fs').existsSync({0})", path);
        #elseif sys
        return sys.FileSystem.exists(path);
        #else
        return false;
        #end
    }

    function select(all:Array<Scenario>):Array<Scenario> {
        final list = env('GPUI_BENCH_SCENARIOS');
        if (list == null || StringTools.trim(list) == '') {
            return all;
        }
        final names = [for (name in list.split(',')) StringTools.trim(name)].filter(name -> name != '');
        final selected:Array<Scenario> = [];
        for (name in names) {
            var found = false;
            for (scenario in all) {
                if (scenario.name == name) {
                    selected.push(scenario);
                    found = true;
                    break;
                }
            }
            if (!found) {
                print('warning: unknown scenario "$name" (registered: ' + [for (s in all) s.name].join(', ') + ')');
            }
        }
        return selected;
    }

    public static var target(get, never):String;

    static function get_target():String {
        #if cpp
        return 'native';
        #elseif js
        return isNode() ? 'node' : 'web';
        #else
        return 'other';
        #end
    }

    #if js
    /** Node, not the renderer of the Electron runner (which has `process` too) */
    static function isNode():Bool {
        return js.Syntax.code("(typeof process !== 'undefined' && process.versions != null && process.versions.node != null && process.versions.electron == null)");
    }

    /** The web build under the Electron runner (Node integration in the renderer) */
    static function isElectron():Bool {
        return js.Syntax.code("(typeof process !== 'undefined' && process.versions != null && process.versions.electron != null)");
    }
    #end

    /**
     * Web under Electron: marks the measured block on the renderer's stdout,
     * where V8 also prints its `--trace-gc` lines, so `web-run.js` can sum
     * the collections of each block; with `GPUI_BENCH_PROFILE=1`, also a
     * `console.profile` around the block (recorded by `web-run.js --profile`
     * through the DevTools protocol).
     */
    static function webMark(kind:String, label:String):Void {
        #if js
        if (isNode() || !isElectron()) {
            return;
        }
        final profile = env('GPUI_BENCH_PROFILE') == '1';
        if (kind == 'end' && profile) {
            js.Syntax.code('console.profileEnd({0})', label);
        }
        final heap:Float = js.Syntax.code("(performance.memory != null ? performance.memory.usedJSHeapSize : 0)");
        js.Syntax.code("process.stdout.write({0})", 'GPUI_BENCH_MARK $kind $label ${js.Syntax.code("process.pid")} $heap\n');
        if (kind == 'begin' && profile) {
            js.Syntax.code('console.profile({0})', label);
        }
        #end
    }

    static function env(name:String):Null<String> {
        #if web
        // Under the Electron runner the page has Node's process.env. Read it
        // here rather than through `ceramic_use_electron`, which would also
        // send Ceramic's file reads (asset misses) to the main process over
        // synchronous IPC, a cost a browser does not have
        return js.Syntax.code("((typeof process !== 'undefined' && process.env != null) ? process.env[{0}] : null)", name);
        #else
        return ceramic.Platform.getEnv(name);
        #end
    }

    static function envInt(name:String, defaultValue:Int):Int {
        final value = env(name);
        if (value == null || value == '') {
            return defaultValue;
        }
        final parsed = Std.parseInt(value);
        return parsed == null || parsed <= 0 ? defaultValue : parsed;
    }

    static function percentile(sorted:Array<Float>, q:Float):Float {
        if (sorted.length == 0) {
            return 0;
        }
        var rank = Math.ceil(q * sorted.length) - 1;
        if (rank < 0) rank = 0;
        if (rank >= sorted.length) rank = sorted.length - 1;
        return sorted[Std.int(rank)];
    }

    static function gcInfo(which:Int):Float {
        #if cpp
        try {
            final value:Float = cpp.vm.Gc.memInfo64(which);
            return Math.isNaN(value) ? 0.0 : value;
        }
        catch (e:Dynamic) {
            return 0.0;
        }
        #else
        return 0.0;
        #end
    }

    static function now():Float {
        return haxe.Timer.stamp() * 1000.0;
    }

    /** Process CPU time in ms (native), 0 elsewhere */
    /** CPU time of the calling thread in ms (native), 0 elsewhere: unlike the wall time, other processes do not add to it */
    static function threadCpuTime():Float {
        #if cpp
        return untyped __cpp__('bench_thread_cpu_ms()');
        #else
        return 0.0;
        #end
    }

    /** Resident memory of the process in bytes (native macOS), 0 elsewhere */
    static function rssBytes():Float {
        #if cpp
        return untyped __cpp__('bench_rss_bytes()');
        #elseif js
        return isNode() ? js.Syntax.code("process.memoryUsage().rss") : 0.0;
        #else
        return 0.0;
        #end
    }

    static function cpuTime():Float {
        #if sys
        return Sys.cpuTime() * 1000.0;
        #else
        return 0.0;
        #end
    }

    static function heapBytes():Float {
        #if cpp
        return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
        #else
        return 0;
        #end
    }

    static inline function gcEnable(enabled:Bool):Void {
        #if cpp
        cpp.vm.Gc.enable(enabled);
        #end
    }

    /** The Ceramic Electron runner when the web build runs under it (`ceramic web project --run`), null otherwise. */
    static function electronRunner():Dynamic {
        #if (web && clay && !completion)
        return backend.ElectronRunner.electronRunner;
        #else
        return null;
        #end
    }

    public static function print(line:String):Void {
        #if js
        final runner = electronRunner();
        if (runner != null)
            runner.consoleLog(line);
        else
            js.Syntax.code('console.log({0})', line);
        #else
        Sys.println(line);
        #end
    }

    static function fmt(value:Float):String {
        final rounded = Math.round(value * 100) / 100;
        return Std.string(rounded);
    }

    static function exit(code:Int):Void {
        #if js
        if (isNode()) {
            js.Syntax.code('process.exit({0})', code);
        }
        else {
            // Under the Electron runner: quit it, so scripted web runs end
            // (when profiling, once web-run.js has its profiles, at most a
            // minute later)
            final runner = electronRunner();
            if (runner != null && runner.app != null) {
                if (env('GPUI_BENCH_PROFILE') == '1') {
                    var waited = 0;
                    function quitWhenDone() {
                        if (js.Syntax.code("window.gpuiBenchMayQuit") == true || waited++ > 600)
                            runner.app.quit();
                        else
                            haxe.Timer.delay(quitWhenDone, 100);
                    }
                    haxe.Timer.delay(quitWhenDone, 500);
                }
                else
                    runner.app.quit();
            }
        }
        #elseif sys
        Sys.exit(code);
        #end
    }

}
