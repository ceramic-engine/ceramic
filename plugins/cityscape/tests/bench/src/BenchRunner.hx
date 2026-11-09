package;

import haxe.Json;
import haxe.Timer;

/**
 * Runs the registered scenarios (`Scenarios.all()`) and writes one JSON
 * result per scenario in `tests/bench/results/`: frame time mean, median,
 * p95, p99 and max, in milliseconds, over the measured frames.
 *
 * Environment:
 * - `CITYSCAPE_BENCH_SCENARIOS`: comma separated names (default: all);
 * - `CITYSCAPE_BENCH_FRAMES`: measured frames per scenario (default 300);
 * - `CITYSCAPE_BENCH_WARMUP`: warmup frames (default 30);
 * - `CITYSCAPE_BENCH_RESULTS`: results directory (default `tests/bench/results`).
 */
class BenchRunner {

    public function new() {}

    public function run():Void {
        final filter = env('CITYSCAPE_BENCH_SCENARIOS');
        final names = filter != null && filter.length > 0 ? filter.split(',') : null;
        final frames = intEnv('CITYSCAPE_BENCH_FRAMES', 300);
        final warmup = intEnv('CITYSCAPE_BENCH_WARMUP', 30);
        var resultsDir = env('CITYSCAPE_BENCH_RESULTS');
        if (resultsDir == null || resultsDir.length == 0) {
            resultsDir = defaultResultsDir();
        }

        for (scenario in Scenarios.all()) {
            if (names != null && names.indexOf(scenario.name) == -1)
                continue;
            scenario.setup();
            for (frame in 0...warmup) {
                scenario.step(frame);
            }
            final times:Array<Float> = [];
            for (frame in 0...frames) {
                final start = Timer.stamp();
                scenario.step(warmup + frame);
                times.push((Timer.stamp() - start) * 1000);
            }
            scenario.teardown();

            final sorted = times.copy();
            sorted.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
            var total = 0.0;
            for (t in times)
                total += t;
            final result = {
                scenario: scenario.name,
                target: target(),
                frames: frames,
                mean: frames > 0 ? total / frames : 0.0,
                median: percentile(sorted, 0.5),
                p95: percentile(sorted, 0.95),
                p99: percentile(sorted, 0.99),
                max: sorted.length > 0 ? sorted[sorted.length - 1] : 0.0
            };
            print('${scenario.name} (${target()}): mean ${fmt(result.mean)} ms, median ${fmt(result.median)} ms, p95 ${fmt(result.p95)} ms, p99 ${fmt(result.p99)} ms, max ${fmt(result.max)} ms');
            write(resultsDir, '${scenario.name}-${target()}.json', Json.stringify(result, null, '  '));
        }
        exit(0);
    }

    static function percentile(sorted:Array<Float>, p:Float):Float {
        if (sorted.length == 0)
            return 0;
        final index = Std.int(Math.min(sorted.length - 1, Math.floor(p * sorted.length)));
        return sorted[index];
    }

    static function fmt(value:Float):String {
        return Std.string(Math.round(value * 1000) / 1000);
    }

    static function target():String {
        #if js
        return 'node';
        #elseif cpp
        return 'cpp';
        #elseif cs
        return 'cs';
        #else
        return 'other';
        #end
    }

    static function defaultResultsDir():String {
        // The macro lives in a macro-only module: a macro function here would
        // make the macro context type this module and every scenario with it
        return testing.BenchData.benchDir() + '/results';
    }

    static function write(dir:String, name:String, content:String):Void {
        #if js
        js.Syntax.code('(function(dir, name, content) { const fs = require("fs"); const path = require("path"); fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, name), content); })({0}, {1}, {2})', dir, name, content);
        #elseif sys
        sys.FileSystem.createDirectory(dir);
        sys.io.File.saveContent(dir + '/' + name, content);
        #end
    }

    static function print(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #else
        Sys.println(message);
        #end
    }

    static function env(name:String):Null<String> {
        #if js
        return js.Syntax.code('(typeof process !== "undefined" ? process.env[{0}] : null)', name);
        #elseif sys
        return Sys.getEnv(name);
        #else
        return null;
        #end
    }

    static function intEnv(name:String, defaultValue:Int):Int {
        final value = env(name);
        if (value == null || value.length == 0)
            return defaultValue;
        final parsed = Std.parseInt(value);
        return parsed != null ? parsed : defaultValue;
    }

    static function exit(code:Int):Void {
        #if js
        js.Syntax.code('process.exit({0})', code);
        #elseif sys
        Sys.exit(code);
        #end
    }

}
