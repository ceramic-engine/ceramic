package tests;

import gpui.AnyElement;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.RenderOnce;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.scene.BorderStyle;
import testing.TestCase;

import gpui.Prelude.*;

/**
 * Tests for elements and the window frame cycle: painting into the scene,
 * element state, and redraws driven by the tracker.
 */
class WindowTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var window:Window;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        flushImmediate();
    }

    override function teardown() {
        if (window != null) {
            window.destroy();
            window = null;
        }
        flushImmediate();
    }

    inline function flushImmediate():Void {
        ceramic.App.app.flushImmediate();
    }

    function open(render:(Window, Context<Dynamic>) -> IntoElement):Entity<TestView> {
        var view:Entity<TestView> = null;
        window = Window.open(app, {width: 200, height: 100, scaleFactor: 2, autoDraw: false}, (window, cx) -> {
            view = cx.newEntity((_:Context<TestView>) -> new TestView(render));
            return view;
        });
        return view;
    }

    function testDrawPaintsDivsInScaledPixels() {
        open((window, cx) -> div().flex().p2().gap2().bg(hsla(0.5, 0.5, 0.5, 1))
            .child(div().size(px(20)).bg(red()).roundedMd())
            .child(div().w(px(30)).h(px(10)).border2().borderColor(blue()).bg(white()))
        );
        window.draw();
        final scene = window.renderedScene();
        // root background, child 1, child 2 background, then child 2 border: borders are
        // painted with a transparent background, so GPUI splits them in 4 strips
        assertEquals(7, scene.quads.length);
        final root = scene.quads[0];
        assertEquals(0.0, root.boundsX);
        assertEquals(400.0, root.boundsWidth);
        assertEquals(200.0, root.boundsHeight);
        final first = scene.quads[1];
        // p2 = 8px, scale 2
        assertEquals(16.0, first.boundsX);
        assertEquals(16.0, first.boundsY);
        assertEquals(40.0, first.boundsWidth);
        // roundedMd = 0.375rem = 6px = 12 device pixels
        assertEquals(12.0, first.cornerRadiusTopLeft);
        final second = scene.quads[2];
        // 8 + 20 + gap 8 = 36 logical
        assertEquals(72.0, second.boundsX);
        for (i in 3...7) {
            final border = scene.quads[i];
            assertEquals(4.0, border.borderWidthTop);
            assertEquals(0.0, border.backgroundSolidA);
            assertEquals(1.0, border.borderColorA);
            assertEquals(72.0, border.boundsX);
        }
    }

    function testTextStyleCompositionFollowsTheStack() {
        // `textStyle()` composes the stack once per depth: pushes, pops and a
        // replaced stack (deferred draws) compose again
        open((window, cx) -> div());
        inline function size(style:gpui.TextStyle):Float {
            return switch style.fontSize {
                case Pixels(value): value;
                case _: Math.NaN;
            }
        }
        function refinement(fontSize:Null<Float>, ?color:gpui.Hsla):gpui.TextStyleRefinement {
            final result = new gpui.TextStyleRefinement();
            if (fontSize != null) result.fontSize = gpui.AbsoluteLength.Pixels(fontSize);
            if (color != null) result.color = color;
            return result;
        }
        final a = refinement(10);
        final b = refinement(20);
        final c = refinement(null, red());
        assertTrue(window.textStyle().equals(new gpui.TextStyle()), 'empty stack: default style');
        window.pushTextStyle(a);
        assertEquals(10.0, size(window.textStyle()));
        window.pushTextStyle(c);
        final ac = window.textStyle();
        assertEquals(10.0, size(ac));
        assertTrue(ac.color.equals(red()));
        window.popTextStyle();
        window.popTextStyle();
        window.pushTextStyle(b);
        window.pushTextStyle(c);
        final bc = window.textStyle();
        assertEquals(20.0, size(bc));
        assertTrue(bc.color.equals(red()));
        // The returned style is a copy that can be changed
        bc.fontSize = gpui.AbsoluteLength.Pixels(99);
        assertEquals(20.0, size(window.textStyle()));
        window.popTextStyle();
        assertEquals(20.0, size(window.textStyle()));
        assertTrue(!window.textStyle().color.equals(red()));
        window.popTextStyle();
        // A stack replaced in place (like `prepaintDeferredDraws`)
        final stack = @:privateAccess window.textStyleStack;
        stack.push(a);
        assertEquals(10.0, size(window.textStyle()));
        stack.resize(0);
        stack.push(b);
        assertEquals(20.0, size(window.textStyle()));
        stack.resize(0);
        assertTrue(window.textStyle().equals(new gpui.TextStyle()));
    }

    function testDashedBorderWithoutBackgroundIsSplitIntoStrips() {
        open((window, cx) -> div().child(div().w(px(100)).h(px(60)).border2().borderDashed().borderColor(red())));
        window.draw();
        final quads = window.renderedScene().quads;
        assertEquals(4, quads.length);
        for (quad in quads) {
            assertEquals(BorderStyle.Dashed, quad.borderStyle);
            assertEquals(200.0, quad.boundsWidth);
        }
        // Top strip: border 4 + antialias 1
        assertEquals(5.0, quads[0].contentMaskHeight);
        assertEquals(200.0, quads[0].contentMaskWidth);
        // Bottom strip
        assertEquals(115.0, quads[1].contentMaskY);
        // Left strip
        assertEquals(5.0, quads[2].contentMaskWidth);
        assertEquals(110.0, quads[2].contentMaskHeight);
        // Right strip
        assertEquals(195.0, quads[3].contentMaskX);
    }

    function testOpacityAndContentMasks() {
        open((window, cx) -> div().size(px(100)).overflowHidden().opacity(0.5).bg(red())
            .child(div().w(px(300)).h(px(20)).opacity(0.5).bg(blue()))
        );
        window.draw();
        final quads = window.renderedScene().quads;
        assertEquals(2, quads.length);
        assertEquals(0.5, quads[0].backgroundSolidA);
        assertEquals(0.25, quads[1].backgroundSolidA);
        // The child is clipped by the parent's overflow mask
        assertEquals(600.0, quads[1].boundsWidth);
        assertEquals(200.0, quads[1].contentMaskWidth);
    }

    function testShadowsAreFilledWithElementBounds() {
        open((window, cx) -> div().p4().child(div().size(px(40)).roundedLg().bg(white()).shadowSm()));
        window.draw();
        final shadows = window.renderedScene().shadows;
        assertEquals(2, shadows.length);
        // offset (0, 1), blur 3, element at 16, 16
        assertEquals(32.0, shadows[0].boundsX);
        assertEquals(34.0, shadows[0].boundsY);
        assertEquals(6.0, shadows[0].blurRadius);
        assertEquals(32.0, shadows[0].elementBoundsX);
        assertEquals(80.0, shadows[0].elementBoundsWidth);
        // spread -1 shrinks the second shadow
        assertEquals(34.0, shadows[1].boundsX);
        assertEquals(76.0, shadows[1].boundsWidth);
        assertEquals(16.0, shadows[1].elementCornerRadiusTopLeft);
    }

    function testTrackerDrivenRedrawWithoutNotify() {
        final counter:Entity<TestCounter> = app.newEntity(_ -> new TestCounter());
        var renders = 0;
        open((window, cx) -> {
            renders++;
            final count = counter.read(cx).count;
            return div().w(px(10 + count * 10)).h(px(10)).bg(red());
        });
        window.draw();
        assertEquals(1, renders);
        assertFalse(window.dirty);

        // A timer changes the observable field: no notify() needed
        app.backgroundExecutor().timer(1).then(_ -> counter.read(app).count++);
        dispatcher.advanceClock(1);
        dispatcher.runUntilParked();
        flushImmediate();
        assertTrue(window.dirty, 'the view reacted');
        assertTrue(window.drawIfDirty());
        assertEquals(2, renders);
        assertEquals(40.0, window.renderedScene().quads[0].boundsWidth);

        // Nothing changed: nothing is drawn
        flushImmediate();
        assertFalse(window.drawIfDirty());
        assertEquals(2, renders);

        // Writing a field the view did not read does nothing
        counter.read(app).label = 'unused';
        flushImmediate();
        assertFalse(window.dirty);
    }

    function testReadsDuringPaintSubscribeTheView() {
        final counter:Entity<TestCounter> = app.newEntity(_ -> new TestCounter());
        open((window, cx) -> div().size(px(50)).child(
            canvas((_, _, _) -> 0, (bounds, _, window, cx) -> {
                // Read in the paint phase of the canvas
                final count = counter.read(cx).count;
                window.paintQuad(fill(bounds, hsla(count / 10, 1, 0.5, 1)));
            }).size(px(10))
        ));
        window.draw();
        counter.read(app).count = 3;
        flushImmediate();
        assertTrue(window.dirty);
    }

    function testNotifyMarksTheWindowDirty() {
        final view = open((window, cx) -> div());
        window.draw();
        assertFalse(window.dirty);
        view.update(app, (_, cx) -> cx.notify());
        assertTrue(window.dirty);
    }

    function testIdleFramesAllocateNothing() {
        final counter:Entity<TestCounter> = app.newEntity(_ -> new TestCounter());
        open((window, cx) -> div().flex().gap2().children([for (i in 0...counter.read(cx).count + 5) div().size(px(10)).bg(red())]));
        window.draw();
        window.draw();
        final elements = AnyElement.allocatedCount;
        final scene = window.renderedScene();
        final drawCount = window.drawCount;

        // Idle frames: nothing is dirty, nothing is drawn or allocated
        for (_ in 0...10) {
            flushImmediate();
            assertFalse(window.drawIfDirty());
        }
        assertEquals(drawCount, window.drawCount);
        assertTrue(scene == window.renderedScene());
        assertTrue(window.renderable.scene == scene);
        assertEquals(elements, AnyElement.allocatedCount);

        // Redrawing the same tree reuses pooled elements and primitives
        window.refresh();
        window.drawIfDirty();
        window.refresh();
        window.drawIfDirty();
        assertEquals(elements, AnyElement.allocatedCount);
    }

    function testElementStateLifetime() {
        final flags:Entity<TestCounter> = app.newEntity(_ -> new TestCounter());
        flags.read(app).count = 1;
        var state:Entity<gpui.Window.StateModel<Int>> = null;
        var renders = 0;
        open((window, cx) -> {
            renders++;
            final root = div();
            if (flags.read(cx).count > 0) {
                state = window.useKeyedState('counter', cx.app, _ -> 42);
                root.child(div().w(px(state.read(cx).value)).h(px(1)).bg(red()));
            }
            return root;
        });
        window.draw();
        final first = state;
        assertEquals(42, first.read(app).value);

        // Kept across frames while accessed
        window.refresh();
        window.draw();
        assertTrue(first == state);
        assertFalse((first : Model).destroyed);

        // Writing the state value draws the view again (tracker)
        state.read(app).value = 10;
        flushImmediate();
        assertTrue(window.drawIfDirty());
        assertEquals(20.0, window.renderedScene().quads[0].boundsWidth);

        // Not accessed during a frame: dropped and destroyed
        flags.read(app).count = 0;
        flushImmediate();
        window.drawIfDirty();
        assertTrue((first : Model).destroyed);

        // Accessed again: a new state
        flags.read(app).count = 1;
        flushImmediate();
        window.drawIfDirty();
        assertFalse(first == state);
        assertEquals(42, state.read(app).value);
    }

    function testChangingElementIdsKeepTheIdTrieBounded() {
        // Ids that change every frame would intern a new path each frame:
        // the trie is swept so that it stays bounded (GPUI has no trie)
        var frame = 0;
        open((window, cx) -> {
            final root = div();
            for (i in 0...8) {
                root.child(div().id(gpui.ElementId.Integer(frame * 8 + i)).w(px(1)).h(px(1)));
            }
            return root;
        });
        final trie = @:privateAccess window.elementIdRoot.trie;
        var maxNodes = 0;
        for (_ in 0...10000) {
            frame++;
            window.refresh();
            window.draw();
            if (trie.nodeCount > maxNodes) maxNodes = trie.nodeCount;
        }
        assertTrue(trie.sweeps > 0);
        // 80000 paths were interned: at most about two sweep thresholds survive at once
        assertTrue(maxNodes < 3 * gpui.GlobalElementId.ElementIdTrie.MIN_SWEEP_NODES);
        assertTrue(trie.nodeCount < 3 * gpui.GlobalElementId.ElementIdTrie.MIN_SWEEP_NODES);
    }

    function testElementStateOnStableIdSurvivesTheSweep() {
        var frame = 0;
        var state:Entity<gpui.Window.StateModel<Int>> = null;
        final view = open((window, cx) -> {
            state = window.useKeyedState('counter', cx.app, _ -> 42);
            final root = div().child(div().id('stable').w(px(state.read(cx).value)).h(px(1)));
            for (i in 0...8) {
                root.child(div().id(gpui.ElementId.Integer(frame * 8 + i)).w(px(1)).h(px(1)));
            }
            return root;
        });
        final trie = @:privateAccess window.elementIdRoot.trie;
        window.draw();
        final first = state;
        final viewId = gpui.ElementId.View(view.entityId());
        final stableNode = @:privateAccess window.elementIdRoot.child(viewId);
        for (_ in 0...10000) {
            frame++;
            window.refresh();
            window.draw();
        }
        assertTrue(trie.sweeps > 0);
        // The keyed state (on the view's path) is the same entity, never dropped
        assertTrue(first == state);
        assertFalse((first : Model).destroyed);
        assertEquals(42, state.read(app).value);
        // Its node is still the interned one for that path
        assertTrue(stableNode == @:privateAccess window.elementIdRoot.child(viewId));
    }

    function testComponentReadsSubscribeTheEnclosingView() {
        final counter:Entity<TestCounter> = app.newEntity(_ -> new TestCounter());
        open((window, cx) -> div().child(new TestComponent(counter)));
        window.draw();
        assertEquals(1, window.renderedScene().quads.length);
        counter.read(app).count = 2;
        flushImmediate();
        assertTrue(window.drawIfDirty());
        assertEquals(60.0, window.renderedScene().quads[0].boundsWidth);
    }

    function testNestedViewsReactIndependently() {
        final counter:Entity<TestCounter> = app.newEntity(_ -> new TestCounter());
        var childRenders = 0;
        final child:Entity<TestView> = app.newEntity((_:Context<TestView>) -> new TestView((window, cx) -> {
            childRenders++;
            return div().size(px(counter.read(cx).count + 1)).bg(red());
        }));
        final parent = open((window, cx) -> div().child((child : TestView)));
        window.draw();
        assertEquals(1, childRenders);
        assertEquals(2, window.renderedViewCount);
        assertTrue(window.viewTracker(child.entityId()) != null);

        // The parent did not read the counter, the child did
        counter.read(app).count = 1;
        flushImmediate();
        assertTrue(window.dirty);
        window.draw();
        assertEquals(2, childRenders);

        // A view that is not rendered anymore stops reacting
        parent.read(app).renderFn = (window, cx) -> div();
        window.refresh();
        window.draw();
        assertEquals(1, window.renderedViewCount);
        assertNull(window.viewTracker(child.entityId()));
        counter.read(app).count = 2;
        flushImmediate();
        assertFalse(window.dirty);
    }

    function testTextStyleStack() {
        var color:gpui.Hsla = null;
        open((window, cx) -> div().textColor(red()).child(
            canvas((_, window, _) -> {
                color = window.textStyle().color;
                return 0;
            }, (_, _, _, _) -> {})
        ));
        window.draw();
        assertTrue(color.equals(red()));
    }


    #if cpp
    @:noInline
    static function failInRender():IntoElement {
        throw 'render failed';
    }

    @:noInline
    static function failAndRethrowPlainly():Void {
        try {
            failInRender();
        }
        catch (e:haxe.Exception) {
            throw e;
        }
    }

    static function hasFrame(stack:Array<haxe.CallStack.StackItem>, className:String, method:String):Bool {
        for (item in stack) {
            var current = item;
            while (current != null) {
                switch current {
                    case FilePos(s, _, _, _):
                        current = s;
                    case Method(c, m):
                        if (c == className && m == method) return true;
                        current = null;
                    case _:
                        current = null;
                }
            }
        }
        return false;
    }

    /**
     * A crash inside a view's render is reported from the render, not from
     * the `catch` blocks of `ViewElement` and `Window.draw` that clean up
     * and rethrow it (they rethrow with `cpp.Lib.rethrow`, see
     * `gpui.util.Exceptions`).
     */
    function testRenderCrashKeepsTheRenderFrame() {
        open((window, cx) -> failInRender());
        var caught:Dynamic = null;
        try {
            window.draw();
        }
        catch (e:Dynamic) {
            caught = e;
        }
        assertTrue(caught != null);
        assertTrue(hasFrame(haxe.CallStack.exceptionStack(), 'tests.WindowTest', 'failInRender'));
        final stack = @:privateAccess ceramic.Errors.uncaughtErrorStack(caught);
        assertTrue(hasFrame(stack, 'tests.WindowTest', 'failInRender'));
        assertTrue(hasFrame(stack, 'gpui.ViewElement', 'renderAndRequestLayout'));
        assertTrue(hasFrame(stack, 'gpui.Window', 'draw'));
    }

    /**
     * `ceramic.Errors` reports an exception rethrown with a plain `throw e`
     * from its original frames (kept by the `haxe.Exception`), followed by
     * the frames of the rethrow.
     */
    function testUncaughtErrorStackOfPlainRethrow() {
        var caught:Dynamic = null;
        try {
            failAndRethrowPlainly();
        }
        catch (e:Dynamic) {
            caught = e;
        }
        assertTrue(Std.isOfType(caught, haxe.Exception));
        // The global stack starts at the rethrow
        assertFalse(hasFrame(haxe.CallStack.exceptionStack(), 'tests.WindowTest', 'failInRender'));
        final stack = @:privateAccess ceramic.Errors.uncaughtErrorStack(caught);
        assertTrue(hasFrame(stack, 'tests.WindowTest', 'failInRender'));
        assertTrue(hasFrame(stack, 'tests.WindowTest', 'failAndRethrowPlainly'));
    }
    #end

}

class TestView extends Model implements Render {

    public var renderFn:(Window, Context<Dynamic>) -> IntoElement;

    public function new(renderFn:(Window, Context<Dynamic>) -> IntoElement) {
        super();
        this.renderFn = renderFn;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return renderFn(window, cx);
    }

}

class TestCounter extends Model {

    @observe public var count:Int = 0;

    @observe public var label:String = '';

    public function new() {
        super();
    }

}

class TestComponent implements RenderOnce {

    final counter:Entity<TestCounter>;

    public function new(counter:Entity<TestCounter>) {
        this.counter = counter;
    }

    public function render(window:Window, cx:App):IntoElement {
        return div().w(px(10 + counter.read(cx).count * 10)).h(px(10)).bg(blue());
    }

}
