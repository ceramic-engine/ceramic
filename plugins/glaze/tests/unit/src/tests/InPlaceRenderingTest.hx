package tests;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Interactivity;
import glaze.KeyDownEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.scene.SceneDump;
import testing.TestCase;

import glaze.Prelude.*;

/**
 * In place rendering (port, see `Window.renderInPlace`): a view dirty only
 * because of its own reads, whose bounds do not change, renders alone and
 * its entries replace its old ones in the last frame, without rendering its
 * ancestors. Each test draws the same views in a window caching views and in
 * a window rendering everything (GPUI's frames), and requires the same
 * scene and frame state after every step, besides the render counts.
 */
class InPlaceRenderingTest extends TestCase {

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

    function openWindow(root:AnyView, caching:Bool):Window {
        final window = Window.open(app, {width: 400, height: 300, scaleFactor: 2, autoDraw: false, bindInput: false, viewCaching: caching}, (_, _) -> root);
        window.viewCachingDisabled = !caching;
        windows.push(window);
        return window;
    }

    /** Draws the dirty windows, like the GlazeSystem does every frame. */
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
            final from = Std.int(Math.max(0, line - 4));
            final context = [for (i in from...line + 3) '$i: in place=${linesA[i]} | reference=${linesB[i]}'].join('\n');
            fail('$step: scenes differ at line $line\n$context', pos);
            return;
        }
        // The views made by each window (tooltips) have their own ids
        final ids = ~/view=[0-9]+/g;
        final summaryA = ids.replace(cached.debugFrameSummary(), 'view');
        final summaryB = ids.replace(reference.debugFrameSummary(), 'view');
        if (summaryA != summaryB) {
            fail('$step: frames differ\nin place:\n$summaryA\nreference:\n$summaryB', pos);
            return;
        }
        assertTrue(true);
    }

    function rows(count:Int):InPlaceRows {
        final rows = new InPlaceRows(app, count);
        rows.cached = openWindow(rows.root, true);
        rows.reference = openWindow(rows.root, false);
        frame();
        return rows;
    }

    /** The middle of row `index` (the list starts at 24: padding, header, gap) */
    static inline function rowY(index:Int):Float {
        return 34 + 20 * index;
    }

    function renders(rows:InPlaceRows):Array<Int> {
        return [for (view in rows.rowViews) view.read(app).renders];
    }

/// One view alone

    function testOneRowRendersAlone() {
        countsRenders();
        final r = rows(40);
        assertSameFrames(r.cached, r.reference, 'first frame');
        final listRenders = r.list.read(app).renders;
        final rootRenders = r.root.read(app).renders;
        // Visible and scrolled out rows, labels of other lengths (the frame's
        // arrays change length after the view's range)
        for (step in 0...16) {
            final index = (step * 7) % 40;
            final before = renders(r);
            r.models[index].read(app).label = 'Row $index changed ${[for (_ in 0...step) 'x'].join('')}';
            frame();
            assertEquals(1, r.cached.inPlaceViewCount, 'step $step: in place');
            // With its badge when the list reused it last
            assertTrue(r.cached.renderedViewCount <= 2, 'step $step: rendered');
            final after = renders(r);
            for (i in 0...after.length) {
                // The reference window renders every view
                assertEquals(before[i] + (i == index ? 2 : 1), after[i], 'step $step: renders of row $i');
            }
            assertSameFrames(r.cached, r.reference, 'step $step');
        }
        // The list and the root rendered only in the reference window
        assertEquals(listRenders + 16, r.list.read(app).renders);
        assertEquals(rootRenders + 16, r.root.read(app).renders);
    }

    function testInPlaceRenderingCanBeTurnedOff() {
        countsRenders();
        final r = rows(10);
        r.cached.inPlaceRendering = false;
        final listRenders = r.list.read(app).renders;
        r.models[3].read(app).label = 'Row 3 changed';
        frame();
        assertEquals(0, r.cached.inPlaceViewCount);
        // GPUI: the row and its ancestors (list, root)
        assertEquals(3, r.cached.renderedViewCount);
        assertEquals(listRenders + 2, r.list.read(app).renders);
        assertSameFrames(r.cached, r.reference, 'GPUI rule');
    }

    function testARowWhoseSizeChangesRendersItsAncestors() {
        countsRenders();
        final r = rows(10);
        final fallbacks = r.cached.inPlaceFallbackCount;
        final listRenders = r.list.read(app).renders;
        final rowRenders = r.rowViews[2].read(app).renders;
        r.models[2].read(app).tall = true;
        frame();
        assertEquals(0, r.cached.inPlaceViewCount);
        assertEquals(fallbacks + 1, r.cached.inPlaceFallbackCount);
        // Rendered once in each window: the full frame took its render
        assertEquals(rowRenders + 2, r.rowViews[2].read(app).renders);
        assertEquals(listRenders + 2, r.list.read(app).renders);
        assertSameFrames(r.cached, r.reference, 'taller row');
        // The rows below moved and the next change of a row is in place again
        r.models[5].read(app).label = 'Row 5 changed';
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'row below');
    }

    function testNestedViews() {
        countsRenders();
        final r = rows(10);
        final badgeRenders = r.badgeViews[3].read(app).renders;
        final rowRenders = r.rowViews[3].read(app).renders;
        r.models[3].read(app).badge = 5;
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertEquals(1, r.cached.renderedViewCount);
        assertEquals(rowRenders + 1, r.rowViews[3].read(app).renders, 'the row renders in the reference window only');
        assertSameFrames(r.cached, r.reference, 'badge');
        // The row renders in place, its badge is reused
        final badgeAfter = r.badgeViews[3].read(app).renders;
        r.models[3].read(app).label = 'Row 3 changed';
        frame();
        assertEquals(1, r.cached.renderedViewCount);
        assertEquals(1, r.cached.reusedViewCount);
        assertEquals(badgeAfter + 1, r.badgeViews[3].read(app).renders, 'the badge renders in the reference window only');
        assertTrue(badgeAfter > badgeRenders);
        assertSameFrames(r.cached, r.reference, 'row around its badge');
    }

    function testTwoSiblingsInOneFrame() {
        countsRenders();
        final r = rows(20);
        r.models[2].read(app).label = 'Row 2 changed';
        r.models[13].read(app).label = 'Row 13 also changed, longer';
        frame();
        assertEquals(2, r.cached.inPlaceViewCount);
        assertEquals(2, r.cached.renderedViewCount);
        assertSameFrames(r.cached, r.reference, 'two rows');
    }

    function testADirtyViewInsideADirtyParent() {
        countsRenders();
        final r = rows(10);
        final badgeRenders = r.badgeViews[4].read(app).renders;
        r.models[4].read(app).label = 'Row 4 changed';
        r.models[4].read(app).badge = 9;
        frame();
        // The row renders in place with its badge, once each
        assertEquals(1, r.cached.inPlaceViewCount);
        assertEquals(2, r.cached.renderedViewCount);
        assertEquals(badgeRenders + 2, r.badgeViews[4].read(app).renders);
        assertSameFrames(r.cached, r.reference, 'row and badge');
    }

    function testAnAnimatedViewRendersWithItsAncestors() {
        countsRenders();
        final r = rows(5);
        r.models[1].read(app).animating = true;
        frame();
        assertEquals(1, r.cached.inPlaceViewCount, 'notified by a tracked change');
        // Its animation frames: GPUI's rule
        for (step in 0...3) {
            r.cached.runNextFrameCallbacks();
            r.reference.runNextFrameCallbacks();
            frame();
            assertEquals(0, r.cached.inPlaceViewCount, 'animation frame $step');
            assertSameFrames(r.cached, r.reference, 'animation frame $step');
        }
    }

/// The frame after: hit test, hover, focus, keys, tooltips, deferred draws

    function testInteractionAfterInPlaceRendering() {
        countsRenders();
        final r = rows(12);
        // Changed in place, with one more hitbox and one more dispatch node
        r.models[3].read(app).label = 'Row 3 changed';
        r.models[3].read(app).extra = true;
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'extra child');

        // Clicks on the row, its new child and the next row
        for (point in [point(px(60), px(rowY(3))), point(px(110), px(rowY(3))), point(px(60), px(rowY(4)))]) {
            for (window in windows) {
                window.dispatchEvent(new MouseDownEvent(Left, point));
                window.dispatchEvent(new MouseUpEvent(Left, point));
            }
        }
        // Each click in both windows (the extra child's handler runs before its row's)
        assertEquals('click 3,click 3,extra 3,click 3,extra 3,click 3,click 4,click 4', r.log.join(','));
        // The clicks focused the rows: drawn whole
        frame();
        assertSameFrames(r.cached, r.reference, 'after the clicks');

        // Hover: the row's hover listener notifies it, rendered in place
        for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(60), px(rowY(5)))));
        frame();
        assertEquals(2, r.cached.inPlaceViewCount, 'hover leaves row 4 and enters row 5');
        assertSameFrames(r.cached, r.reference, 'hover row 5');
        for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(60), px(rowY(3)))));
        frame();
        assertEquals(2, r.cached.inPlaceViewCount, 'hover leaves row 4 and enters row 3');
        assertSameFrames(r.cached, r.reference, 'hover row 3');

        // Focus (a refresh: drawn whole), then the focused row changes in place
        for (window in windows) window.focus(r.focusHandles[3], app);
        frame();
        assertSameFrames(r.cached, r.reference, 'focus');
        r.models[3].read(app).label = 'Row 3 focused';
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'focused row changed');
        r.log.resize(0);
        for (window in windows) window.dispatchEvent(new KeyDownEvent(Keystroke.parse('a')));
        assertEquals('key 3 a,key 3 a', r.log.join(','));

        // Tab order across the row rendered in place
        for (window in windows) window.focusNext(app);
        frame();
        assertSameFrames(r.cached, r.reference, 'focus next');
        assertEquals(r.focusHandles[4].id, r.cached.focusId());

        // Tooltip: shown by the row's own notify, drawn after the tree
        for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(60), px(rowY(6)))));
        frame();
        dispatcher.advanceClock(Interactivity.DEFAULT_TOOLTIP_SHOW_DELAY + 0.01);
        dispatcher.runUntilParked();
        frame();
        assertSameFrames(r.cached, r.reference, 'tooltip');
        assertTrue(r.cached.debugFrameSummary().indexOf('tooltips 1') != -1, 'the tooltip request is drawn');
        for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(390), px(290))));
        frame();
        assertSameFrames(r.cached, r.reference, 'tooltip hidden');
    }

    function testDeferredDrawsOfARowRenderedInPlace() {
        countsRenders();
        final r = rows(8);
        // The frame has no deferred draw: the row's popover is drawn in place
        r.models[1].read(app).popover = true;
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'popover 1');
        // Deferred draws in the frame: drawn whole
        r.models[2].read(app).popover = true;
        frame();
        assertEquals(0, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'popover 2');
        r.models[5].read(app).label = 'Row 5 changed';
        frame();
        assertEquals(0, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'row 5 with popovers');
        r.models[1].read(app).popover = false;
        r.models[2].read(app).popover = false;
        frame();
        assertSameFrames(r.cached, r.reference, 'no popover');
        r.models[5].read(app).label = 'Row 5 again';
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'in place again');
    }

    function testElementStatesFollowTheRow() {
        countsRenders();
        final r = rows(6);
        r.models[2].read(app).extra = true;
        frame();
        // The extra child counts its clicks in an element state
        final point = point(px(110), px(rowY(2)));
        for (_ in 0...3) {
            for (window in windows) {
                window.dispatchEvent(new MouseDownEvent(Left, point));
                window.dispatchEvent(new MouseUpEvent(Left, point));
            }
            frame();
        }
        assertSameFrames(r.cached, r.reference, 'three clicks');
        // Gone for a frame: its state is dropped, it starts again at 0
        r.models[2].read(app).extra = false;
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        r.models[2].read(app).extra = true;
        frame();
        assertEquals(1, r.cached.inPlaceViewCount);
        assertSameFrames(r.cached, r.reference, 'state dropped');
    }

    function testScrolledListThenRowsInPlace() {
        countsRenders();
        final r = rows(40);
        for (step in 0...6) {
            for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(60), px(100)), ScrollDelta.Pixels(point(px(0), px(-37)))));
            frame();
            assertSameFrames(r.cached, r.reference, 'scroll $step');
            r.models[(step * 5 + 3) % 40].read(app).label = 'Row changed at scroll $step';
            frame();
            assertSameFrames(r.cached, r.reference, 'row after scroll $step');
        }
    }

/// Sequences

    /**
     * Frames drawn in place can follow each other without a full frame:
     * the nodes a view no longer uses are freed as it renders in place
     * (otherwise only a full frame frees them).
     */
    function testManyFramesInPlaceKeepTheLayoutTreeSize() {
        countsRenders();
        final r = rows(20);
        r.models[2].read(app).label = 'Row 2 warm';
        frame();
        final nodes = r.cached.layoutNodeCount();
        final framesBefore = r.cached.inPlaceFrameCount;
        for (step in 0...300) {
            final model = r.models[step % 20].read(app);
            model.label = 'Row ${step % 20} step $step';
            model.extra = step % 3 == 0;
            frame();
        }
        assertEquals(framesBefore + 300, r.cached.inPlaceFrameCount, 'every frame drawn in place');
        // At most the extra child of each row (two nodes) more
        final after300 = r.cached.layoutNodeCount();
        assertTrue(after300 <= nodes + 2 * 20, 'layout nodes: $after300, $nodes before');
        // The same rows again: no growth
        for (step in 0...300) {
            final model = r.models[step % 20].read(app);
            model.label = 'Row ${step % 20} again $step';
            model.extra = step % 3 == 0;
            frame();
        }
        assertEquals(after300, r.cached.layoutNodeCount(), 'layout nodes after 600 frames');
        assertSameFrames(r.cached, r.reference, 'after 300 frames');
    }

    function testRandomSequencesStayEquivalent() {
        countsRenders();
        for (seed in [91, 31337]) {
            randomSteps(seed, 250);
            for (window in windows) window.destroy();
            windows.resize(0);
        }
    }

    function randomSteps(initialSeed:Int, count:Int):Void {
        final r = rows(24);
        final trail:Array<String> = [];
        var seed = initialSeed;
        var inPlace = 0;
        for (i in 0...count) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            final row = (seed >> 8) % 24;
            final model = r.models[row].read(app);
            final name = switch seed % 9 {
                case 0 | 1:
                    model.label = model.label.length > 30 ? 'Row $row' : model.label + ' +';
                    'label $row';
                case 2:
                    model.extra = !model.extra;
                    'extra $row';
                case 3:
                    model.badge = model.badge + 1;
                    'badge $row';
                case 4:
                    model.tall = !model.tall;
                    'tall $row';
                case 5:
                    for (window in windows) window.dispatchEvent(new MouseMoveEvent(point(px(60), px(rowY(row)))));
                    'hover $row';
                case 6:
                    final at = point(px(110), px(rowY(row)));
                    for (window in windows) {
                        window.dispatchEvent(new MouseDownEvent(Left, at));
                        window.dispatchEvent(new MouseUpEvent(Left, at));
                    }
                    'click $row';
                case 7:
                    for (window in windows) window.dispatchEvent(new ScrollEvent(point(px(60), px(100)), ScrollDelta.Pixels(point(px(0), px((seed & 1) == 0 ? -23 : 23)))));
                    'scroll';
                case _:
                    model.label = 'Row $row';
                    model.badge = model.badge + 2;
                    final other = r.models[(row + 5) % 24].read(app);
                    other.label = other.label + '.';
                    'two rows $row';
            }
            frame();
            inPlace += r.cached.inPlaceViewCount;
            trail.push('$name (in place ${r.cached.inPlaceViewCount}, fallbacks ${r.cached.inPlaceFallbackCount})');
            // The ranges recorded by the views point at their own entries
            // (rows and badges, not the list: its content is scrolled)
            final problem = r.cached.debugCheckViewRanges(40);
            if (problem != null) {
                fail('seed $initialSeed, random step $i: $name: $problem\n' + trail.slice(-6).join('\n'));
                return;
            }
            if (!sameFrames(r.cached, r.reference)) {
                trace(trail.slice(-6).join('\n'));
                assertSameFrames(r.cached, r.reference, 'seed $initialSeed, random step $i: $name');
                return;
            }
        }
        assertTrue(inPlace * 3 > count, 'seed $initialSeed: $inPlace views rendered in place in $count steps');
    }

    static function sameFrames(a:Window, b:Window):Bool {
        return dump(a) == dump(b) && a.debugFrameSummary() == b.debugFrameSummary();
    }

/// With the check of `glaze_verify_cache` (every frame drawn in place is compared with a full frame)

    function testFramesDrawnInPlaceAreChecked() {
        final r = rows(16);
        #if glaze_verify_cache
        final compared = Window.inPlaceVerifications;
        final failures = Window.inPlaceVerificationFailures;
        #end
        for (step in 0...8) {
            final model = r.models[(step * 3) % 16].read(app);
            model.label = 'Row checked $step';
            model.extra = step % 2 == 0;
            frame();
            assertSameFrames(r.cached, r.reference, 'step $step');
        }
        #if glaze_verify_cache
        assertTrue(Window.inPlaceVerifications > compared, 'compared with a full frame');
        assertEquals(failures, Window.inPlaceVerificationFailures);
        #end
    }

}

/**
 * The state of a row.
 */
class InPlaceRowModel extends Model {

    @observe public var label:String;

    @observe public var tall:Bool = false;

    @observe public var extra:Bool = false;

    @observe public var popover:Bool = false;

    @observe public var badge:Int = 0;

    /** Requests an animation frame on each render */
    @observe public var animating:Bool = false;

    public function new(label:String) {
        super();
        this.label = label;
    }

}

/**
 * A view counting its renders.
 */
class InPlaceView extends Model implements Render {

    public var renders:Int = 0;

    final renderFn:(Window, Context<Dynamic>) -> IntoElement;

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
 * A list of row views, each with a nested badge view, under a list view
 * and a root view.
 */
class InPlaceRows {

    public final models:Array<Entity<InPlaceRowModel>> = [];

    public final rowViews:Array<Entity<InPlaceView>> = [];

    public final badgeViews:Array<Entity<InPlaceView>> = [];

    public final focusHandles:Array<FocusHandle> = [];

    public final list:Entity<InPlaceView>;

    public final root:Entity<InPlaceView>;

    public final log:Array<String> = [];

    public var cached:Window = null;

    public var reference:Window = null;

    public function new(app:App, count:Int) {
        for (i in 0...count) {
            final model = app.newEntity(_ -> new InPlaceRowModel('Row $i'));
            models.push(model);
            focusHandles.push(app.focusHandle().tabIndex(i).tabStop(true));
            badgeViews.push(app.newEntity((_:Context<InPlaceView>) -> new InPlaceView((window, cx) -> {
                final value = model.read(cx).badge;
                return div().id('badge').px1().roundedFull().bg(hsla(value / 10, 0.6, 0.5, 1)).textXs().child('$value');
            })));
            final index = i;
            rowViews.push(app.newEntity((_:Context<InPlaceView>) -> new InPlaceView((window, cx) -> renderRow(index, window, cx))));
        }
        list = app.newEntity((_:Context<InPlaceView>) -> new InPlaceView((_, _) -> div().id('list').flex().flexCol().h(px(260)).overflowYScroll()
            .children([for (view in rowViews) (view : AnyView)])));
        root = app.newEntity((_:Context<InPlaceView>) -> new InPlaceView((_, _) -> div().sizeFull().flex().flexCol().p2().gap1()
            .child(div().h(px(12)).textXs().child('In place'))
            .child((list : AnyView))));
    }

    function renderRow(index:Int, window:Window, cx:Context<Dynamic>):IntoElement {
        final model = models[index].read(cx);
        if (model.animating) {
            window.requestAnimationFrame();
        }
        final row = div().id('row').flexNone().h(px(model.tall ? 34 : 20)).flex().gap1().px1().itemsCenter()
            .hover(s -> s.bg(hsla(0.1, 0.3, 0.9, 1)))
            .trackFocus(focusHandles[index])
            .focus(s -> s.bg(hsla(0.6, 0.3, 0.9, 1)))
            .onClick((_, _, _) -> log.push('click $index'))
            .onKeyDown((event:KeyDownEvent) -> log.push('key $index ${event.keystroke.key}'))
            .tooltip((_, cx) -> cx.newEntity((_:Context<InPlaceView>) -> new InPlaceView((_, _) -> div().p1().bg(black()).textColor(white()).child('Tooltip $index'))))
            .child(div().w(px(70)).flexNone().whitespaceNowrap().overflowHidden().textSm().child(model.label))
            .child((badgeViews[index] : AnyView));
        // A slot of a fixed size, clipping its content: the row lays out
        // the same with or without it (its content would otherwise change
        // the row's overflow, which the scrolling list depends on)
        final slot = div().flexNone().w(px(30)).h(px(14)).overflowHidden();
        if (model.extra) {
            final clicks = window.useKeyedState('extra-clicks', cx.app, _ -> 0);
            slot.child(div().id('extra').sizeFull().bg(red()).textXs().child('${clicks.read(cx).value}')
                .onClick((_, _, cx) -> {
                    log.push('extra $index');
                    final state = clicks.read(cx);
                    state.value = state.value + 1;
                }));
        }
        row.child(slot);
        // The popover in a clipped box of no size, always there: the row lays
        // out the same with or without it
        final popover = div().flexNone().size(px(0)).overflowHidden();
        if (model.popover) {
            popover.child(deferred(anchored().child(div().w(px(60)).p1().bg(hsla(0.15, 0.7, 0.8, 1)).child('Popover $index'))));
        }
        row.child(popover);
        return row;
    }

}
