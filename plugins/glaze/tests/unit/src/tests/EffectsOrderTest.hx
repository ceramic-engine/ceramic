package tests;

import gpui.App;
import gpui.Entity;
import gpui.Model;
import gpui.TestDispatcher;
import testing.GpuiTruth;
import testing.TestCase;

/**
 * Runs the operations of the `effects-order` behaviour of the reference
 * harness (`reference/src/behaviours.rs`) and checks that the port logs
 * exactly what the original GPUI logged (`test/golden/gpui/effects-order.json`).
 */
class EffectsOrderTest extends TestCase {

    function testEffectsOrderMatchesGpui() {
        final expected:Array<String> = haxe.Json.parse(GpuiTruth.load('effects-order.json')).log;
        final actual = run(new App(new TestDispatcher()));
        assertEquals(expected.length, actual.length, 'log length');
        for (i in 0...Std.int(Math.max(expected.length, actual.length))) {
            assertEquals(expected[i], actual[i], 'log line $i');
        }
    }

    static function run(app:App):Array<String> {
        final log:Array<String> = [];
        final a:Entity<EffectsCounter> = app.newEntity(_ -> new EffectsCounter());
        final b:Entity<EffectsCounter> = app.newEntity(_ -> new EffectsCounter());

        // 1. App level observers, registered inside an update of `a`
        a.update(app, (_, cx) -> {
            final app = cx.app;
            app.observe(a, (a, cx) -> log.push('app observe a value=${a.read(cx).value}'));
            app.subscribe(a, EffectsChanged, (a, event, cx) -> log.push('app subscribe a event=${event.value} value=${a.read(cx).value}'));
            app.observe(b, (b, cx) -> log.push('app observe b value=${b.read(cx).value}'));
            app.observeRelease(b, (b, _) -> log.push('release b value=${b.value}'));
            log.push('setup app observers');
        });

        // 2. Entity level observers: b observes and subscribes to a
        b.update(app, (_, cx) -> {
            cx.observe(a, (b, a, cx) -> log.push('b observe a value=${a.read(cx).value} b=${b.value}'));
            cx.subscribe(a, EffectsChanged, (b, _, event, cx) -> {
                b.value += event.value;
                log.push('b subscribe a event=${event.value} b=${b.value}');
                cx.notify();
            });
            log.push('setup b observers');
        });

        // 3. Notify, emit, defer and a nested update in one update cycle
        a.update(app, (a, cx) -> {
            a.value = 1;
            log.push('update a begin');
            cx.notify();
            cx.emit(new EffectsChanged(1));
            cx.defer(cx -> {
                log.push('defer from a');
                cx.defer(_ -> log.push('nested defer'));
            });
            b.update(cx, (b, cx) -> {
                b.value = 10;
                log.push('nested update b');
                cx.notify();
                cx.emit(new EffectsChanged(2));
            });
            // Coalesced with the first notify
            cx.notify();
            log.push('update a end');
        });
        log.push('after update 3');

        // 4. Release b inside an update that also notifies and emits
        a.update(app, (a, cx) -> {
            (b : EffectsCounter).destroy();
            log.push('dropped b');
            a.value = 2;
            cx.notify();
            cx.emit(new EffectsChanged(3));
        });
        log.push('after update 4');

        return log;
    }

}

class EffectsCounter extends Model {

    public var value:Int = 0;

    public function new() {
        super();
    }

}

class EffectsChanged {

    public final value:Int;

    public function new(value:Int) {
        this.value = value;
    }

}
