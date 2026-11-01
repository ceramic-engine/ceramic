package;

import ceramic.Entity;
import ceramic.InitSettings;
import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.util.AllocationCounters;

import gpui.Prelude.*;

/**
 * View caching benchmark (step 13 of the plan): a window of about 2000
 * elements (cards with text, icons, borders and shadows, one view per card
 * and per badge), where one observable field changes per frame.
 *
 * For each mode (full render: no view cache, like GPUI's uncached views;
 * cached: the default view caching) it reports the mean and median draw
 * time, the views rendered per frame and the objects created per frame
 * (`gpui.util.AllocationCounters`, pooled `AnyElement`s, and on native the
 * bytes allocated, measured with the GC disabled). Then idle frames (nothing
 * changes) through the real update loop: no draw, nothing allocated.
 *
 * Run: `ceramic headless run node --setup --assets` (Node) or
 * `ceramic clay build mac --setup --assets` then
 * `project/mac/bench.app/Contents/MacOS/bench` (native). Set `GPUI_BENCH_FRAMES`
 * to change the number of measured frames (300 by default), `GPUI_BENCH_ONLY`
 * (`full` or `cached`) to measure one mode only.
 */
class Project extends Entity {

    static inline final CARD_COUNT = 70;

    static inline final WARMUP_FRAMES = 30;

    static final ICON = haxe.io.Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="black" stroke-width="2"/><path d="M8 12 L11 15 L16 9" fill="none" stroke="black" stroke-width="2"/></svg>');

    var app:App;

    var cards:Array<gpui.Entity<BenchCard>> = [];

    var lines:Array<String> = [];

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 640;
        settings.targetHeight = 480;

        this.app = null;
        ceramic.App.app.onceReady(this, ready);

    }

    static function now():Float {
        return haxe.Timer.stamp() * 1000.0;
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

    function print(line:String):Void {
        lines.push(line);
        #if js
        js.Syntax.code('console.log({0})', line);
        #else
        Sys.println(line);
        #end
    }

    function ready() {

        final framesEnv = ceramic.Platform.getEnv('GPUI_BENCH_FRAMES');
        final frames = framesEnv != null && framesEnv != '' ? Std.parseInt(framesEnv) : 300;
        final dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        for (i in 0...CARD_COUNT) {
            cards.push(app.newEntity(_ -> new BenchCard('Card $i')));
        }

        print('gpui view caching benchmark (${#if cpp 'native' #elseif js 'node' #else 'other' #end}), $CARD_COUNT cards, $frames measured frames');
        var cachedWindow:Null<Window> = null;
        final only = ceramic.Platform.getEnv('GPUI_BENCH_ONLY');
        for (caching in (only == 'cached' ? [true] : only == 'full' ? [false] : [false, true])) {
            final window = measure(caching, frames);
            if (caching) {
                cachedWindow = window;
            }
            else {
                window.destroy();
            }
        }
        idle(cachedWindow);

    }

    function buildRoot():AnyView {
        final cardViews = [for (card in cards) {
            final badge = app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> {
                final value = card.read(cx).value % 10;
                return div().px1().roundedFull().bg(hsla(value / 10, 0.6, 0.5, 1)).textXs().child('$value');
            }));
            app.newEntity((_:Context<BenchView>) -> new BenchView((_, cx) -> renderCard(card, badge, cx.app)));
        }];
        return app.newEntity((_:Context<BenchView>) -> new BenchView((_, _) ->
            div().id('root').sizeFull().flex().flexWrap().gap2().p2().bg(hsla(0.6, 0.1, 0.96, 1))
                .children([for (view in cardViews) (view : AnyView)])
        ));
    }

    function renderCard(card:gpui.Entity<BenchCard>, badge:gpui.Entity<BenchView>, cx:App):IntoElement {
        final model = card.read(cx);
        final value = model.value;
        return div().id('card').w(px(150)).h(px(118)).flex().flexCol().gap1().p2()
            .bg(white()).border1().borderColor(hsla(0.6, 0.2, 0.8, 1)).roundedMd().shadowSm()
            .hover(s -> s.borderColor(hsla(0.6, 0.6, 0.5, 1)))
            .child(div().flex().gap1().itemsCenter()
                .child(svg().path('bench/icon.svg').data(ICON).size(px(12)).textColor(hsla(0.6, 0.6, 0.4, 1)))
                .child(div().textSm().child(model.title))
                .child((badge : AnyView)))
            .child(div().textXs().textColor(hsla(0, 0, 0.3, 1)).child('Value $value'))
            .child(div().h(px(4)).w(px(130)).bg(hsla(0, 0, 0.9, 1)).roundedFull()
                .child(div().h(px(4)).w(px(10 + (value * 7) % 120)).bg(hsla(0.6, 0.7, 0.5, 1)).roundedFull()))
            .child(div().textXs().textColor(hsla(0, 0, 0.5, 1)).child('Updated every 70 frames'))
            .child(div().flex().gap2().children([for (j in 0...3)
                div().flex().gap1().itemsCenter()
                    .child(svg().path('bench/icon.svg').data(ICON).size(px(10)).textColor(hsla(j / 3, 0.5, 0.5, 1)))
                    .child(div().textXs().child('${j * 10 + 1}'))
            ]));
    }

    function measure(caching:Bool, frames:Int):Window {
        final window = Window.open(app, {width: 1280, height: 1024, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: caching}, (_, _) -> buildRoot());
        window.viewCachingDisabled = !caching;
        AllocationCounters.reset();
        window.draw();
        final elementCount = AllocationCounters.divs + AllocationCounters.texts + AllocationCounters.svgs + AllocationCounters.viewElements;
        final times:Array<Float> = [];
        var renderedViews = 0;
        var reusedViews = 0;
        var counters = 0;
        var anyElements = 0;
        var bytes = 0.0;
        for (frame in 0...(WARMUP_FRAMES + frames)) {
            final card = cards[frame % cards.length].read(app);
            final measured = frame >= WARMUP_FRAMES;
            final countersBefore = AllocationCounters.total();
            final elementsBefore = AnyElement.allocatedCount;
            final start = now();
            card.value = card.value + 1;
            ceramic.App.app.flushImmediate();
            window.drawIfDirty();
            final time = now() - start;
            if (measured) {
                times.push(time);
                renderedViews += window.renderedViewCount;
                reusedViews += window.reusedViewCount;
                counters += AllocationCounters.total() - countersBefore;
                anyElements += AnyElement.allocatedCount - elementsBefore;
            }
        }
        // Bytes allocated (native): 20 more frames with the GC disabled
        #if cpp
        cpp.vm.Gc.run(true);
        gcEnable(false);
        final bytesBefore = heapBytes();
        for (frame in 0...20) {
            final card = cards[frame % cards.length].read(app);
            card.value = card.value + 1;
            ceramic.App.app.flushImmediate();
            window.drawIfDirty();
        }
        bytes = (heapBytes() - bytesBefore) * frames / 20;
        gcEnable(true);
        cpp.vm.Gc.run(true);
        #end
        times.sort(Reflect.compare);
        var sum = 0.0;
        for (t in times) sum += t;
        final mode = caching ? 'cached     ' : 'full render';
        print('$mode: $elementCount elements, draw ${fmt(sum / times.length)} ms mean, ${fmt(times[times.length >> 1])} ms median, '
            + 'views rendered ${fmt(renderedViews / frames)} / reused ${fmt(reusedViews / frames)} per frame, '
            + 'objects created ${fmt(counters / frames)} per frame (new AnyElement ${fmt(anyElements / frames)})'
            #if cpp + ', ${fmt(bytes / frames / 1024)} KiB allocated per frame' #end);
        AllocationCounters.reset();
        window.draw();
        print('  objects created by one full frame: ' + AllocationCounters.summary());
        return window;
    }

    /**
     * Idle frames through the real update loop: nothing changes, nothing is
     * drawn, nothing is allocated (by gpui or by the renderable).
     */
    function idle(window:Window):Void {
        final scene = window.renderedScene();
        final drawCount = window.drawCount;
        final countersBefore = AllocationCounters.total();
        var ticks = 0;
        var bytes = 0.0;
        var bytesBefore = 0.0;
        ceramic.App.app.screen.add(window.renderable);
        ceramic.App.app.onUpdate(this, _ -> {
            ticks++;
            if (ticks == 10) {
                // Measure 120 frames with the GC disabled
                gcEnable(false);
                bytesBefore = heapBytes();
            }
            else if (ticks == 130) {
                bytes = heapBytes() - bytesBefore;
                gcEnable(true);
                final ok = window.drawCount == drawCount && scene == window.renderedScene() && AllocationCounters.total() == countersBefore;
                print('idle: 120 frames, ${window.drawCount - drawCount} draws, objects created ${AllocationCounters.total() - countersBefore}'
                    #if cpp + ', ${Std.int(bytes)} bytes allocated by the whole app' #end + (ok ? '' : ' (FAILED)'));
                exit(ok ? 0 : 1);
            }
        });
    }

    static function fmt(value:Float):String {
        final rounded = Math.round(value * 100) / 100;
        return Std.string(rounded);
    }

    static function exit(code:Int):Void {
        #if js
        js.Syntax.code('process.exit({0})', code);
        #elseif sys
        Sys.exit(code);
        #end
    }

}

class BenchCard extends Model {

    @observe public var value:Int = 0;

    @observe public var title:String;

    public function new(title:String) {
        super();
        this.title = title;
    }

}
