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
 * 107 to 110, 0 until hxcpp exposes them).
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
 *   default (`SceneRenderable.defaultRenderToTexture`).
 */
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

    final owner:ceramic.Entity;

    final app:App;

    final frames:Int;

    final runs:Int;

    final only:Null<String>;

    final screen:Bool;

    final renderToTexture:Null<Bool>;

    final scenarios:Array<Scenario>;

    final timestamp:String;

    var resultsDir:Null<String> = null;

    var failed:Bool = false;

    var written:Array<String> = [];

    /** Ceramic draw time of the last on screen measure (median and p99, ms) */
    var lastDrawMedian:Float = 0.0;

    /** Path tiles rasterized during the last measure */
    var lastPathRasterizations:Int = 0;
    var lastDrawP99:Float = 0.0;

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
        if (env('GPUI_BENCH_ATLAS') == '1') {
            atlasBench();
            exit(0);
            return;
        }
        print('gpui benchmark ($target), ${scenarios.length} scenario(s): ' + [for (s in scenarios) s.name].join(', ') + ', $frames measured frames, $runs run(s)' + (screen ? ', on screen' : '')
            + (renderToTexture != null ? ', renderToTexture $renderToTexture' : ''));
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
        final onBeginDraw = () -> drawStart = now();
        final onFinishDraw = () -> {
            if (measuringDraws) drawTimes.push(now() - drawStart);
        };
        function frameBody(frame:Int):Void {
            measuringDraws = frame > WARMUP_FRAMES;
            final measured = frame >= WARMUP_FRAMES;
            if (frame == WARMUP_FRAMES) {
                FrameProfiler.reset();
                minorPausesBefore = gcInfo(MEM_INFO_MINOR_PAUSE_COUNT);
                minorPauseTotalBefore = gcInfo(MEM_INFO_TOTAL_MINOR_PAUSE_MS);
                volumeBefore = gcInfo(MEM_INFO_ALLOCATION_VOLUME);
            }
            final countersBefore = AllocationCounters.total();
            final elementsBefore = AnyElement.allocatedCount;
            final rasterizedBefore = gpui.PathRasterizer.rasterizedCount;
            final start = now();
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
                renderedViews += window.renderedViewCount;
                reusedViews += window.reusedViewCount;
                counters += AllocationCounters.total() - countersBefore;
                anyElements += AnyElement.allocatedCount - elementsBefore;
                pathRasterizations += gpui.PathRasterizer.rasterizedCount - rasterizedBefore;
            }
        }
        final total = WARMUP_FRAMES + frames;
        if (!screen) {
            for (frame in 0...total) {
                frameBody(frame);
            }
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
                frameBody(frame++);
                return;
            }
            ceramic.App.app.offUpdate(handler);
            ceramic.App.app.offBeginDraw(onBeginDraw);
            ceramic.App.app.offFinishDraw(onFinishDraw);
            drawTimes.sort(Reflect.compare);
            if (drawTimes.length > 0) {
                print('  ceramic draw per frame: ${fmt(drawTimes[drawTimes.length >> 1])} ms median, p99 ${fmt(percentile(drawTimes, 0.99))} ms');
            }
            lastPathRasterizations = pathRasterizations;
            lastDrawMedian = drawTimes.length > 0 ? drawTimes[drawTimes.length >> 1] : 0.0;
            lastDrawP99 = drawTimes.length > 0 ? percentile(drawTimes, 0.99) : 0.0;
            finishMeasure(scenario, window, caching, elementCount, run, times, wallTimes, renderedViews, reusedViews, counters, anyElements, minorPausesBefore, minorPauseTotalBefore, gcInfo(MEM_INFO_ALLOCATION_VOLUME) - volumeBefore);
            done();
        };
        ceramic.App.app.onUpdate(owner, handler);
    }

    function finishMeasure(scenario:Scenario, window:Window, caching:Bool, elementCount:Int, run:Int, times:Array<Float>, wallTimes:Array<Float>,
        renderedViews:Int, reusedViews:Int, counters:Int, anyElements:Int, minorPausesBefore:Float, minorPauseTotalBefore:Float, allocatedVolume:Float):Void {
        var bytes = 0.0;
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
            print('  minor GC pauses: $minorPauses, total ${fmt(minorPauseTotal)} ms, max ${fmt(minorPauseMax)} ms');
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
            renderToTexture: window.renderable.renderToTexture,
            phasesMsPerFrame: phases,
            phaseCounts: phaseCounts,
            gc: {
                minorPauses: minorPauses,
                lastMinorPauseMs: minorPauseLast,
                maxMinorPauseMs: minorPauseMax,
                totalMinorPauseMs: minorPauseTotal
            }
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
            }
            else if (ticks == 10 + idleFrames) {
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

    function writeResult(result:haxe.DynamicAccess<Dynamic>, scenario:String, caching:Bool, run:Int):Void {
        final json = haxe.Json.stringify(result);
        print('BENCH_JSON ' + json);
        final suffix = runs > 1 ? '-r${run + 1}' : '';
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
    static function isNode():Bool {
        return js.Syntax.code("(typeof process !== 'undefined' && process.versions != null && process.versions.node != null)");
    }
    #end

    static function env(name:String):Null<String> {
        return ceramic.Platform.getEnv(name);
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
            final runner = electronRunner();
            if (runner != null && runner.app != null)
                runner.app.quit();
        }
        #elseif sys
        Sys.exit(code);
        #end
    }

}
