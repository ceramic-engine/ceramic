package tests;

import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.Keystroke;
import gpui.Model;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.PathBuilder;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.StyleRefinement;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.scene.SceneDump;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * View caching: GPUI's opt-in `.cached(style)` and the port's default
 * caching driven by tracker. Besides render counts and reuse of hitboxes,
 * listeners and element states, the equivalence tests draw the same views
 * in two windows, one caching views and one rendering everything, and
 * require identical scenes (primitive by primitive) and frame state after
 * every step of scripted and random invalidation sequences.
 */
class ViewCacheTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final windows:Array<Window> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        flushImmediate();
    }

    override function teardown() {
        for (window in windows) {
            window.destroy();
        }
        windows.resize(0);
        flushImmediate();
    }

    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    /**
     * Opens a window showing `root`, with default view caching or without
     * any view cache at all (`.cached(style)` included).
     */
    function openWindow(root:AnyView, caching:Bool, width:Float = 400, height:Float = 400):Window {
        final window = Window.open(app, {width: width, height: height, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: caching}, (_, _) -> root);
        window.viewCachingDisabled = !caching;
        windows.push(window);
        return window;
    }

    function view(render:(Window, Context<Dynamic>) -> IntoElement):Entity<CountingView> {
        return app.newEntity((_:Context<CountingView>) -> new CountingView(render));
    }

    /** Draws the dirty windows, like the GpuiSystem does every frame. */
    function frame():Void {
        flushImmediate();
        for (window in windows) {
            window.drawIfDirty();
        }
    }

    static function dump(window:Window):String {
        return SceneDump.toJson(window.renderedScene(), window.viewportSize().width * 2, window.viewportSize().height * 2);
    }

    function assertSameFrames(cached:Window, reference:Window, step:String, ?pos:haxe.PosInfos):Void {
        final a = dump(cached);
        final b = dump(reference);
        if (a != b) {
            final linesA = a.split('\n');
            final linesB = b.split('\n');
            var line = 0;
            while (line < linesA.length && line < linesB.length && linesA[line] == linesB[line]) {
                line++;
            }
            final from = Std.int(Math.max(0, line - 6));
            final context = [for (i in from...line + 3) '$i: cached=${linesA[i]} | reference=${linesB[i]}'].join('\n');
            fail('$step: scenes differ at line $line\n$context', pos);
            return;
        }
        final summaryA = cached.debugFrameSummary();
        final summaryB = reference.debugFrameSummary();
        if (summaryA != summaryB) {
            fail('$step: frames differ\ncached:\n$summaryA\nreference:\n$summaryB', pos);
            return;
        }
        assertTrue(true);
    }

/// Default caching

    function testCleanViewsAreReused() {
        final counter = app.newEntity(_ -> new CacheCounter());
        final children = [for (i in 0...3) view((window, cx) -> {
            final value = i == 1 ? counter.read(cx).count : 0;
            return div().id('child').w(px(50)).h(px(20 + value)).bg(hsla(i / 3, 0.5, 0.5, 1));
        })];
        final root = view((window, cx) -> div().flex().gap2().children([for (child in children) (child : AnyView)]));
        final window = openWindow(root, true);
        window.draw();
        assertEquals(4, window.renderedViewCount);
        assertEquals(0, window.reusedViewCount);
        for (child in children) assertEquals(1, child.read(app).renders);

        // Only the child reading the counter and its ancestor render again
        counter.read(app).count = 5;
        frame();
        assertEquals(2, window.renderedViewCount);
        assertEquals(2, window.reusedViewCount);
        assertEquals(2, root.read(app).renders);
        assertEquals(1, children[0].read(app).renders);
        assertEquals(2, children[1].read(app).renders);
        assertEquals(1, children[2].read(app).renders);
        assertEquals(25.0 * 2, window.renderedScene().quads[1].boundsHeight);

        // Idle: nothing drawn
        final drawCount = window.drawCount;
        frame();
        assertEquals(drawCount, window.drawCount);

        // Notifying a leaf view renders it and its ancestors only
        children[2].update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(2, window.renderedViewCount);
        assertEquals(2, children[2].read(app).renders);
        assertEquals(1, children[0].read(app).renders);

        // Refresh renders everything
        window.refresh();
        frame();
        assertEquals(4, window.renderedViewCount);
        assertEquals(0, window.reusedViewCount);

        // An explicit draw of a clean window renders views cached by default
        window.draw();
        assertEquals(4, window.renderedViewCount);
    }

    function testUncachedViewsRenderEveryFrame() {
        final child = view((_, _) -> div().size(px(10)).bg(red()));
        final other = view((_, _) -> div().size(px(10)).bg(blue()));
        final root = view((_, _) -> div().flex().child(child.uncached()).child((other : AnyView)));
        final window = openWindow(root, true);
        window.draw();
        root.update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(2, child.read(app).renders);
        assertEquals(1, other.read(app).renders);
        assertEquals(1, window.reusedViewCount);
    }

    function testReusedViewsKeepTheirTrackerBindingsAndElementStates() {
        final counter = app.newEntity(_ -> new CacheCounter());
        var state:Entity<gpui.Window.StateModel<Int>> = null;
        final child = view((window, cx) -> {
            state = window.useKeyedState('kept', cx.app, _ -> 7);
            return div().id('c').w(px(10 + counter.read(cx).count)).h(px(state.read(cx).value)).bg(red());
        });
        final root = view((_, _) -> div().child((child : AnyView)));
        final window = openWindow(root, true);
        window.draw();
        final first = state;

        // The parent renders, the child is reused several times
        for (_ in 0...3) {
            root.update(app, (_, cx) -> cx.notify());
            frame();
            assertEquals(1, child.read(app).renders);
            assertFalse((first : Model).destroyed);
        }
        assertTrue(window.viewTracker(child.entityId()) != null);

        // Its tracker still observes what it read
        counter.read(app).count = 3;
        frame();
        assertEquals(2, child.read(app).renders);
        assertTrue(first == state);
        assertEquals(13.0 * 2, window.renderedScene().quads[0].boundsWidth);

        // And the state still reacts too
        state.read(app).value = 9;
        frame();
        assertEquals(3, child.read(app).renders);
        assertEquals(9.0 * 2, window.renderedScene().quads[0].boundsHeight);
    }

    function testReusedHitboxesAndListenersStillWork() {
        final log:Array<String> = [];
        final child = view((_, _) -> div().id('button').w(px(40)).h(px(20)).bg(red())
            .onClick((e, _, _) -> log.push('click'))
            .hover(s -> s.bg(blue())));
        final root = view((_, _) -> div().p2().child((child : AnyView)));
        final window = openWindow(root, true);
        window.draw();
        root.update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(1, window.reusedViewCount);

        // Hover: the listener of the reused paint notifies the child
        window.dispatchEvent(new MouseMoveEvent(point(px(20), px(15))));
        frame();
        assertEquals(2, child.read(app).renders);
        assertTrue(window.renderedScene().quads[0].backgroundSolidH == blue().h);

        root.update(app, (_, cx) -> cx.notify());
        frame();
        window.dispatchEvent(new MouseDownEvent(Left, point(px(20), px(15))));
        window.dispatchEvent(new MouseUpEvent(Left, point(px(20), px(15))));
        assertEquals('click', log.join(','));
    }

    function testLayoutShiftRendersShiftedViewsAgain() {
        final counter = app.newEntity(_ -> new CacheCounter());
        final grower = view((_, cx) -> div().h(px(10 + counter.read(cx).count)).w(px(20)).bg(red()));
        final below = [for (i in 0...3) view((_, _) -> div().h(px(10)).w(px(20 + i)).bg(blue()).child('text $i'))];
        final above = view((_, _) -> div().h(px(10)).w(px(30)).bg(green()));
        final build = () -> view((_, _) -> div().flex().flexCol().gap1()
            .child((above : AnyView))
            .child((grower : AnyView))
            .children([for (v in below) (v : AnyView)]));
        final shared = build();
        final cached = openWindow(shared, true);
        final reference = openWindow(shared, false);
        frame();
        assertSameFrames(cached, reference, 'first frame');

        counter.read(app).count = 7;
        frame();
        assertSameFrames(cached, reference, 'grown');
        // The view above is reused, the shifted views render again
        assertEquals(1, cached.reusedViewCount);
        assertEquals(5, cached.renderedViewCount);

        // Nothing moves: everything but the root and the grower is reused
        grower.update(app, (_, cx) -> cx.notify());
        frame();
        assertSameFrames(cached, reference, 'notified');
        assertEquals(4, cached.reusedViewCount);
    }

    function testAncestorOpacityAndTextStyleChanges() {
        final style = app.newEntity(_ -> new CacheCounter());
        final child = view((_, _) -> div().p1().bg(red()).child('hello'));
        final build = () -> view((_, cx) -> {
            final count = style.read(cx).count;
            return div().opacity(1.0 - count * 0.25).textColor(hsla(count * 0.1, 0.5, 0.5, 1)).child((child : AnyView));
        });
        final shared = build();
        final cached = openWindow(shared, true);
        final reference = openWindow(shared, false);
        frame();
        for (i in 1...4) {
            style.read(app).count = i;
            frame();
            assertSameFrames(cached, reference, 'step $i');
            assertEquals(0, cached.reusedViewCount);
        }
    }

    function testUniformListScrollEquivalence() {
        final rows = [for (i in 0...40) view((_, _) -> div().id('row').h(px(18)).hover(s -> s.bg(hsla(0.1, 0.3, 0.9, 1))).child('Row $i'))];
        final sidebar = view((_, _) -> div().id('sidebar').w(px(90)).h(px(160)).flex().flexCol()
            .child(uniformList('rows', 30, (start, end, _, _) -> [for (i in start...end) (rows[i] : AnyView)]).flexGrow1()));
        final root = view((_, _) -> div().sizeFull().child((sidebar : AnyView)));
        final cached = openWindow(root, true);
        final reference = openWindow(root, false);
        frame();
        for (step in 0...4) {
            for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(50), px(100)), ScrollDelta.Pixels(point(px(0), px(-25)))));
            frame();
            assertSameFrames(cached, reference, 'scroll $step');
        }
    }

    /**
     * Scrolling moves clean views: they render again (their hitboxes and
     * paint move) but their layout does not change, so their nodes adopt
     * the retained ones and no layout runs again. The cached window lays out
     * exactly as often as the uncached one (GPUI: one layout per frame),
     * not once more per moved view (the combobox story page stuttered).
     */
    function testScrolledCleanViewsAreNotLaidOutAgain() {
        final inner = [for (i in 0...6) view((_, _) -> div().flex().gap1().child('inner $i').child(div().size(px(8)).bg(blue())))];
        final cards = [for (i in 0...6) view((_, _) -> div().flex().flexCol().p1().bg(hsla(i / 6, 0.5, 0.8, 1))
            .child('Card $i with some text')
            .child((inner[i] : AnyView))
            .child(div().h(px(30 + i * 3)).w(px(40 + i)).bg(red())))];
        final root = view((_, _) -> div().sizeFull().child(div().id('scroll').size(px(200)).overflowYScroll().flex().flexCol().gap2()
            .children([for (card in cards) (card : AnyView)])));
        final cached = openWindow(root, true);
        final reference = openWindow(root, false);
        frame();
        assertSameFrames(cached, reference, 'first frame');
        for (step in 0...6) {
            final dy = step < 3 ? -30 : 20;
            final cachedRuns = cached.layoutRunCount();
            final referenceRuns = reference.layoutRunCount();
            for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(100), px(100)), ScrollDelta.Pixels(point(px(0), px(dy)))));
            frame();
            assertSameFrames(cached, reference, 'scroll $step');
            // The moved views render again, none is laid out again
            assertTrue(cached.renderedViewCount > 6, 'scroll $step: moved views render again');
            assertEquals(reference.layoutRunCount() - referenceRuns, cached.layoutRunCount() - cachedRuns, 'scroll $step: layout runs');
        }
        // A moved view rendered after a notification still lays out
        cards[2].update(app, (_, cx) -> cx.notify());
        for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(100), px(100)), ScrollDelta.Pixels(point(px(0), px(-10)))));
        frame();
        assertSameFrames(cached, reference, 'notified and scrolled');
    }

/// GPUI's `.cached(style)`

    function testCachedWithStyleFollowsGpui() {
        final counter = app.newEntity(_ -> new CacheCounter());
        final inner = view((_, cx) -> div().size(px(5)).bg(red()));
        final cachedChild = view((_, cx) -> div().sizeFull().bg(hsla(counter.read(cx).count / 10, 0.5, 0.5, 1)).child(inner.cached(gpui.StyleBuilder.build(s -> s.sizeFull()))));
        final root = view((_, _) -> div().size(px(100)).child(cachedChild.cached(gpui.StyleBuilder.build(s -> s.size(px(50))))));
        final window = openWindow(root, true);
        window.viewCaching = false;
        window.draw();
        assertEquals(3, window.renderedViewCount);

        // The parent renders, the cached child is reused
        root.update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(1, window.renderedViewCount);
        assertEquals(1, cachedChild.read(app).renders);

        // The cached child renders: GPUI renders its nested cached views too
        counter.read(app).count = 2;
        frame();
        assertEquals(2, cachedChild.read(app).renders);
        assertEquals(2, inner.read(app).renders);
    }

    /**
     * GPUI's `test_nested_deferred_draws_with_reused_views` (elements/deferred.rs).
     */
    function testNestedDeferredDrawsWithReusedViews() {
        final panel = view((_, _) -> div().keyContext('Panel').sizeFull().child(
            deferred(
                anchored().position(point(px(10), px(10))).child(
                    div().keyContext('Popover').w(px(200)).h(px(200)).bg(red()).child(
                        deferred(
                            anchored().position(point(px(30), px(30))).child(
                                div().keyContext('NestedMenu').w(px(50)).h(px(50)).bg(blue())
                            )
                        ).withPriority(2)
                    )
                )
            ).withPriority(1)
        ));
        final root = view((_, _) -> div().keyContext('Root').sizeFull().child(panel.cached(gpui.StyleBuilder.build(s -> s.sizeFull()))));
        final window = openWindow(root, true, 800, 600);
        window.viewCaching = false;
        window.draw();
        final first = dump(window);
        assertEquals(2, @:privateAccess window.renderedFrame.deferredDraws.length);

        // Re-render only the root view; the panel is cached, so its subtree,
        // including both deferred draw records, is reused from the previous frame.
        root.update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(1, window.renderedViewCount);
        // Reuse the subtree a second time, exercising ranges that were
        // themselves recorded during a reused frame.
        root.update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(first, dump(window));

        // Re-render the panel itself again to prove the popovers still draw.
        panel.update(app, (_, cx) -> cx.notify());
        frame();
        assertEquals(2, @:privateAccess window.renderedFrame.deferredDraws.length);
        assertEquals(first, dump(window));
    }

/// Behaviour against the original GPUI

    /**
     * Replays `reference/src/view_cache.rs` (views cached with a style, the
     * default caching of the port disabled like in GPUI): the views rendered
     * after every step must be exactly those GPUI renders
     * (`test/golden/gpui/view-cache.json`).
     */
    function testViewCacheBehaviourMatchesGpui() {
        final behaviourDispatcher = new TestDispatcher();
        final behaviourApp = testing.InteractionScript.testApp(behaviourDispatcher);
        flushImmediate();
        final log:Array<String> = [];
        final leaves:Array<Entity<ScriptLeaf>> = [];
        final opened = testing.InteractionScript.open(behaviourApp, behaviourDispatcher, log, (window, cx:Context<ScriptRoot>) -> {
            final d = cx.newEntity((_:Context<ScriptLeaf>) -> new ScriptLeaf('D', log, hsla(0.8, 0.5, 0.5, 1), null));
            final a = cx.newEntity((_:Context<ScriptLeaf>) -> new ScriptLeaf('A', log, hsla(0.0, 0.5, 0.5, 1), d));
            final b = cx.newEntity((_:Context<ScriptLeaf>) -> new ScriptLeaf('B', log, hsla(0.3, 0.5, 0.5, 1), null));
            final c = cx.newEntity((_:Context<ScriptLeaf>) -> new ScriptLeaf('C', log, hsla(0.6, 0.5, 0.5, 1), null));
            for (leaf in [a, b, c, d]) leaves.push(leaf);
            return new ScriptRoot(log, a, b, c);
        });
        final s = opened.script;
        final root = opened.view;
        // GPUI's views are uncached unless embedded with `.cached(style)`
        s.window.viewCaching = false;
        final a = leaves[0], b = leaves[1], c = leaves[2], d = leaves[3];
        inline function notify<T:Model>(entity:Entity<T>, cx:App):Void {
            entity.update(cx, (_, cx) -> cx.notify());
        }
        inline function click(window:Window, cx:App, x:Float, y:Float):Void {
            window.dispatchEvent(new MouseDownEvent(Left, point(px(x), px(y))), cx);
            window.dispatchEvent(new MouseUpEvent(Left, point(px(x), px(y))), cx);
        }
        s.stepWithoutRefresh('notify A', (_, cx) -> notify(a, cx));
        s.stepWithoutRefresh('notify root', (_, cx) -> notify(root, cx));
        s.stepWithoutRefresh('notify B', (_, cx) -> notify(b, cx));
        s.stepWithoutRefresh('notify C', (_, cx) -> notify(c, cx));
        s.stepWithoutRefresh('notify D', (_, cx) -> notify(d, cx));
        s.stepWithoutRefresh('click B', (window, cx) -> click(window, cx, 250, 100));
        s.stepWithoutRefresh('move 100 100', (window, cx) -> window.dispatchEvent(new MouseMoveEvent(point(px(100), px(100))), cx));
        s.stepWithoutRefresh('move 60 60', (window, cx) -> window.dispatchEvent(new MouseMoveEvent(point(px(60), px(60))), cx));
        s.stepWithoutRefresh('click D', (window, cx) -> click(window, cx, 60, 60));
        s.stepWithoutRefresh('move 400 400', (window, cx) -> window.dispatchEvent(new MouseMoveEvent(point(px(400), px(400))), cx));
        s.stepWithoutRefresh('notify root', (_, cx) -> notify(root, cx));
        s.stepWithoutRefresh('click A and C', (window, cx) -> {
            click(window, cx, 120, 120);
            click(window, cx, 100, 250);
        });
        s.stepWithoutRefresh('refresh', (window, _) -> window.refresh());
        s.destroy();

        final expected:Array<String> = haxe.Json.parse(testing.GpuiTruth.load('view-cache.json')).log;
        var firstDifference = -1;
        for (i in 0...Std.int(Math.max(expected.length, log.length))) {
            if (expected[i] != log[i]) {
                firstDifference = i;
                break;
            }
        }
        if (firstDifference != -1) {
            final from = Std.int(Math.max(0, firstDifference - 3));
            fail('view-cache: logs differ at line $firstDifference\n' + [for (i in from...firstDifference + 4) '$i: gpui=${expected[i]} | port=${log[i]}'].join('\n'));
        }
        assertEquals(expected.length, log.length);
    }

/// Equivalence with uncached rendering

    function testEquivalenceOfScriptedSteps() {
        final dashboard = new Dashboard(app);
        final cached = openWindow(dashboard.root, true);
        final reference = openWindow(dashboard.root, false);
        frame();
        assertSameFrames(cached, reference, 'first frame');
        for (step in 0...Dashboard.STEP_COUNT) {
            final name = dashboard.step(step, windows);
            frame();
            assertSameFrames(cached, reference, name);
        }
        assertTrue(dashboard.clicks > 0);
    }

    function testEquivalenceOfRandomSteps() {
        for (seed in [12345, 777, 4242]) {
            randomSteps(seed, 400);
            for (window in windows) window.destroy();
            windows.resize(0);
        }
    }

    function randomSteps(initialSeed:Int, count:Int):Void {
        final dashboard = new Dashboard(app);
        final cached = openWindow(dashboard.root, true);
        final reference = openWindow(dashboard.root, false);
        frame();
        var seed = initialSeed;
        var reused = 0;
        var rendered = 0;
        for (i in 0...count) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            final name = dashboard.step(seed % Dashboard.STEP_COUNT, windows);
            frame();
            reused += cached.reusedViewCount;
            rendered += cached.renderedViewCount;
            if (dump(cached) != dump(reference) && Sys.getEnv('GPUI_CACHE_DEBUG') != null) {
                sys.io.File.saveContent(Sys.getEnv('GPUI_CACHE_DEBUG') + '/cached.json', dump(cached) + cached.debugFrameSummary());
                sys.io.File.saveContent(Sys.getEnv('GPUI_CACHE_DEBUG') + '/reference.json', dump(reference) + reference.debugFrameSummary());
            }
            if (!sameFrames(cached, reference)) {
                assertSameFrames(cached, reference, 'seed $initialSeed, random step $i: $name');
                return;
            }
        }
        assertTrue(reused * 3 > rendered, 'seed $initialSeed: $reused views reused, $rendered rendered');
    }

    static function sameFrames(a:Window, b:Window):Bool {
        return dump(a) == dump(b) && a.debugFrameSummary() == b.debugFrameSummary();
    }
}

/**
 * A leaf of the `view-cache` behaviour (`reference/src/view_cache.rs`).
 */
class ScriptLeaf extends Model implements Render {

    final name:String;
    final log:Array<String>;
    final color:Hsla;
    final child:Null<Entity<ScriptLeaf>>;

    public function new(name:String, log:Array<String>, color:Hsla, child:Null<Entity<ScriptLeaf>>) {
        super();
        this.name = name;
        this.log = log;
        this.color = color;
        this.child = child;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        log.push('$name render');
        final element = div().id(name).sizeFull().bg(color).hover(s -> s.bg(hsla(0.15, 0.8, 0.6, 1)))
            .onClick((e, _, _) -> log.push('$name click ${testing.InteractionScript.pt(e.position())}'));
        if (child != null) {
            element.child(child.cached(gpui.StyleBuilder.build(s -> s.size(px(20)))));
        }
        return element;
    }

}

/**
 * The root of the `view-cache` behaviour.
 */
class ScriptRoot extends Model implements Render {

    final log:Array<String>;
    final a:Entity<ScriptLeaf>;
    final b:Entity<ScriptLeaf>;
    final c:Entity<ScriptLeaf>;

    public function new(log:Array<String>, a:Entity<ScriptLeaf>, b:Entity<ScriptLeaf>, c:Entity<ScriptLeaf>) {
        super();
        this.log = log;
        this.a = a;
        this.b = b;
        this.c = c;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        log.push('root render');
        inline function at(x:Float, y:Float) return div().absolute().left(px(x)).top(px(y)).size(px(100));
        return div().sizeFull().relative().bg(hsla(0.61, 0.20, 0.13, 1.0))
            .child(at(50, 50).child(a.cached(gpui.StyleBuilder.build(s -> s.sizeFull()))))
            .child(at(200, 50).child(b.cached(gpui.StyleBuilder.build(s -> s.sizeFull()))))
            .child(at(50, 200).child((c : AnyView)));
    }

}

class CacheCounter extends Model {

    @observe public var count:Int = 0;

    public function new() {
        super();
    }

}

class CountingView extends Model implements Render {

    public var renders:Int = 0;

    public var renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders++;
        return renderFn(window, cx);
    }

}

/**
 * The state of a card of the dashboard.
 */
class CardModel extends Model {

    @observe public var value:Int = 0;

    @observe public var title:String;

    @observe public var expanded:Bool = false;

    @observe public var hidden:Bool = false;

    public function new(title:String) {
        super();
        this.title = title;
    }

}

class DashboardModel extends Model {

    @observe public var opacity:Float = 1.0;

    @observe public var accent:Float = 0.6;

    @observe public var columns:Int = 2;

    @observe public var showPopover:Bool = false;

    @observe public var rowCount:Int = 30;

    public function new() {
        super();
    }

}

/**
 * A tree of views exercising most of what a cached view must replay:
 * text (wrapping), SVG icons, borders, shadows, hover and group hover,
 * clicks, tooltips, deferred popovers, focus and tab stops, scrolling,
 * uniform lists of views, opacity, paths, and views cached with a style.
 */
class Dashboard {

    public static inline final STEP_COUNT = 22;

    static final ICON = haxe.io.Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M12 2 L22 22 L2 22 Z" fill="black"/></svg>');

    public final app:App;

    public final model:Entity<DashboardModel>;

    public final cards:Array<Entity<CardModel>> = [];

    public final cardViews:Array<Entity<CountingView>> = [];

    public final badgeViews:Array<Entity<CountingView>> = [];

    public final rowViews:Array<Entity<CountingView>> = [];

    public final focusHandles:Array<FocusHandle> = [];

    public final root:Entity<CountingView>;

    public final sidebar:Entity<CountingView>;

    public final pinned:Entity<CountingView>;

    public var clicks:Int = 0;

    public function new(app:App) {
        this.app = app;
        model = app.newEntity(_ -> new DashboardModel());
        for (i in 0...8) {
            final card = app.newEntity(_ -> new CardModel('Card $i'));
            cards.push(card);
            focusHandles.push(app.focusHandle().tabIndex(i).tabStop(true));
            final badge = app.newEntity((_:Context<CountingView>) -> new CountingView((_, cx) -> {
                final value = card.read(cx).value;
                return div().id('badge').px1().roundedFull().bg(hsla(value / 20, 0.6, 0.5, 1)).textXs().child('$value');
            }));
            badgeViews.push(badge);
            final index = i;
            cardViews.push(app.newEntity((_:Context<CountingView>) -> new CountingView((window, cx) -> renderCard(index, window, cx))));
        }
        for (i in 0...40) {
            final row = i;
            rowViews.push(app.newEntity((_:Context<CountingView>) -> new CountingView((_, cx) -> {
                final card = cards[row % cards.length].read(cx);
                return div().id('row').h(px(18)).flex().gap1().px1().hover(s -> s.bg(hsla(0.1, 0.3, 0.9, 1)))
                    .child(svg().path('dashboard/icon.svg').data(ICON).size(px(10)).textColor(hsla(row / 40, 0.5, 0.4, 1)))
                    .child('Row $row ${card.title} ${card.value}');
            })));
        }
        sidebar = app.newEntity((_:Context<CountingView>) -> new CountingView((_, cx) -> {
            final accent = model.read(cx).accent;
            return div().id('sidebar').w(px(90)).h(px(160)).flex().flexCol().bg(hsla(accent, 0.2, 0.95, 1))
                .child(div().p1().textSm().child('Sidebar'))
                .child(
                    uniformList('rows', model.read(cx).rowCount, (start, end, _, _) -> [for (i in start...end) (rowViews[i] : AnyView)])
                        .flexGrow1()
                );
        }));
        pinned = app.newEntity((_:Context<CountingView>) -> new CountingView((_, cx) -> {
            final card = cards[0].read(cx);
            return div().sizeFull().bg(hsla(0.3, 0.4, 0.8, 1)).p1().child('Pinned ${card.value}')
                .child(canvas((_, _, _) -> 0, (bounds, _, window, _) -> {
                    final builder = PathBuilder.fill();
                    builder.moveTo(point(bounds.origin.x, bounds.origin.y + 4));
                    builder.lineTo(point(bounds.origin.x + 10 + card.value, bounds.origin.y + 4));
                    builder.lineTo(point(bounds.origin.x + 5, bounds.origin.y + 14));
                    builder.close();
                    window.paintPath(builder.build(), hsla(0.0, 0.7, 0.5, 1));
                }).size(px(30)));
        }));
        root = app.newEntity((_:Context<CountingView>) -> new CountingView((_, cx) -> {
            final m = model.read(cx);
            final columns = m.columns;
            final grid = div().id('grid').flex().flexWrap().gap1().w(px(columns * 140)).overflowYScroll().h(px(260));
            for (i in 0...cardViews.length) {
                if (!cards[i].read(cx).hidden) {
                    grid.child((cardViews[i] : AnyView));
                }
            }
            return div().id('root').sizeFull().flex().gap2().p2().bg(hsla(0.6, 0.1, 0.97, 1)).opacity(m.opacity)
                .child((sidebar : AnyView))
                .child(div().flex().flexCol().gap1()
                    .child(div().textColor(hsla(m.accent, 0.6, 0.3, 1)).child('Dashboard with ${cardViews.length} cards'))
                    .child(grid)
                    .child(div().w(px(80)).h(px(40)).child(pinned.cached(gpui.StyleBuilder.build(s -> s.sizeFull()))))
                );
        }));
    }

    function renderCard(index:Int, window:Window, cx:Context<Dynamic>):IntoElement {
        final card = cards[index].read(cx);
        final accent = model.read(cx).accent;
        final element = div().id('card').group('card').w(px(130)).flex().flexCol().gap1().p1()
            .bg(white()).border1().borderColor(hsla(accent, 0.3, 0.7, 1)).roundedMd().shadowSm()
            .hover(s -> s.borderColor(hsla(accent, 0.8, 0.4, 1)))
            .trackFocus(focusHandles[index])
            .focus(s -> s.border2())
            .onClick((_, _, _) -> clicks++)
            .tooltip((_, cx) -> cx.newEntity((_:Context<CountingView>) -> new CountingView((_, _) -> div().p1().bg(black()).textColor(white()).child('Tooltip $index'))))
            .child(div().flex().gap1()
                .child(svg().path('dashboard/icon.svg').data(ICON).size(px(12)).textColor(hsla(index / 8, 0.6, 0.4, 1)))
                .child(div().textSm().child(card.title))
                .child((badgeViews[index] : AnyView)))
            .child(div().textXs().textColor(hsla(0, 0, 0.4, 1)).child('A description long enough to wrap on two lines in the card ${card.value}'))
            .child(div().size(px(6)).groupHover('card', s -> s.bg(hsla(accent, 0.8, 0.5, 1))));
        if (card.expanded) {
            element.child(deferred(anchored().child(div().w(px(80)).p1().bg(hsla(0.15, 0.7, 0.8, 1)).shadowMd().child('Popover $index'))));
        }
        return element;
    }

    /**
     * Applies step `index` (the same change to every window) and returns its name.
     */
    public function step(index:Int, windows:Array<Window>):String {
        final card = cards[index % cards.length].read(app);
        switch index {
            case 0 | 1 | 2:
                card.value = card.value + 1;
                return 'increment card ${index % cards.length}';
            case 3:
                card.title = card.title + '!';
                return 'longer title';
            case 4:
                card.expanded = !card.expanded;
                return 'toggle popover';
            case 5:
                final hidden = cards[5].read(app);
                hidden.hidden = !hidden.hidden;
                return 'toggle card 5';
            case 6:
                final m = model.read(app);
                m.opacity = m.opacity == 1.0 ? 0.5 : 1.0;
                return 'opacity';
            case 7:
                final m = model.read(app);
                m.accent = m.accent == 0.6 ? 0.2 : 0.6;
                return 'accent';
            case 8:
                final m = model.read(app);
                m.columns = m.columns == 2 ? 3 : 2;
                return 'columns';
            case 9:
                for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(170), px(60))));
                return 'hover card';
            case 10:
                for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(50), px(80))));
                return 'hover row';
            case 11:
                for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(390), px(390))));
                return 'mouse out';
            case 12:
                for (window in windows) {
                    window.dispatchEvent(new MouseDownEvent(Left, point(px(170), px(60))));
                    window.dispatchEvent(new MouseUpEvent(Left, point(px(170), px(60))));
                }
                return 'click card';
            case 13:
                for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(170), px(100)), ScrollDelta.Pixels(point(px(0), px(-30)))));
                return 'scroll grid';
            case 14:
                for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(50), px(100)), ScrollDelta.Pixels(point(px(0), px(-25)))));
                return 'scroll list';
            case 15:
                for (window in windows) window.focusNext(app);
                return 'focus next';
            case 16:
                badgeViews[2].update(app, (_, cx) -> cx.notify());
                return 'notify badge';
            case 17:
                rowViews[3].update(app, (_, cx) -> cx.notify());
                return 'notify row';
            case 18:
                final m = model.read(app);
                m.rowCount = m.rowCount == 30 ? 35 : 30;
                return 'row count';
            case 19:
                for (window in windows) window.refresh();
                return 'refresh';
            case 20:
                final first = cards[0].read(app);
                first.value = first.value + 3;
                return 'pinned value';
            case _:
                pinned.update(app, (_, cx) -> cx.notify());
                return 'notify pinned';
        }
    }

}
