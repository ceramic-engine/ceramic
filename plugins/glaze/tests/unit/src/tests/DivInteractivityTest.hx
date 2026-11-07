// Ported from gpui-pre 0.3.10: src/elements/div.rs (tests)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests;

import glaze.AnyElement;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Element;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.GlobalElementId;
import glaze.Interactivity;
import glaze.Interactivity.ActiveTooltip;
import glaze.Interactivity.ActiveTooltipCell;
import glaze.Interactivity.InteractiveElementState;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.LayoutId;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseExitEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.TestDispatcher;
import glaze.Window;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * Tests of `div.rs`: group hover, hover listeners, scroll handle alignment,
 * tooltips, keyboard activation, tab groups and scrollability.
 *
 * The touch tests `touch_tap_out_fires_once_after_release` and
 * `touch_pan_and_cancel_do_not_fire_mouse_down_out` are in `TouchWindowTest`.
 *
 * Not ported: accessibility tests (`test_accessibility_id_builder_writes_author_id`,
 * `test_write_a11y_info_string_and_numeric_properties`), `mouse_down_out_is_suppressed_while_window_prompt_is_active`
 * (window prompts are not ported) and `grid_cols_max_content_sizes_columns_to_their_content`
 * (grid layout and debug selectors are not ported).
 */
class DivInteractivityTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

/// Helpers

    /** Rust `cx.add_window(...)`: opens a 1920x1080 window (scale factor 2) and draws it once. */
    function addWindow<V:Model & Render>(build:(Window, Context<V>) -> V):Entity<V> {
        final opened = VisualTestContext.addWindowView(app, dispatcher, build);
        cx = opened.cx;
        return opened.view;
    }

    /** Rust `update_window(|_, window, cx| window.draw(cx).clear(cx))` */
    function draw():Void {
        cx.update((window, _) -> window.draw());
    }

    /** Rust `window.simulate_mouse_move(position, cx)` */
    static function simulateMouseMove(window:Window, position:Point, cx:App):Void {
        window.dispatchEvent(new MouseMoveEvent(position, null, window.modifiers()), cx);
    }

    function moveMouse(position:Point):Void {
        cx.update((window, cx) -> simulateMouseMove(window, position, cx));
    }

    function keyDown(key:String):Void {
        final keystroke = Keystroke.parse(key);
        cx.update((window, cx) -> {
            window.dispatchEvent(new KeyDownEvent(keystroke, false, false), cx);
        });
    }

    function keyUp(key:String):Void {
        final keystroke = Keystroke.parse(key);
        cx.update((window, cx) -> {
            window.dispatchEvent(new KeyUpEvent(keystroke), cx);
        });
    }

    static function isWaitingForShow(cell:ActiveTooltipCell):Bool {
        return cell.value != null && switch cell.value {
            case WaitingForShow(_): true;
            case _: false;
        }
    }

    static function isVisible(cell:ActiveTooltipCell):Bool {
        return cell.value != null && switch cell.value {
            case Visible(_, _): true;
            case _: false;
        }
    }

/// Group hover

    function testGroupHoverStylesUpdateOnlyOnTransitions() {
        final view = addWindow((_, _) -> new GroupHoverTestView()).read(app);

        draw();
        assertEquals(0, view.anonymousPaintCount);
        assertEquals(10.0, view.statefulWidth);

        final initialRenderCount = view.renderCount;
        moveMouse(point(px(25), px(25)));
        assertEquals(initialRenderCount + 1, view.renderCount);
        assertEquals(1, view.anonymousPaintCount);
        assertEquals(20.0, view.statefulWidth);

        moveMouse(point(px(30), px(30)));
        assertEquals(initialRenderCount + 1, view.renderCount);
        assertEquals(1, view.anonymousPaintCount);
        assertEquals(20.0, view.statefulWidth);

        moveMouse(point(px(5), px(5)));
        assertEquals(initialRenderCount + 2, view.renderCount);
        assertEquals(1, view.anonymousPaintCount);
        assertEquals(10.0, view.statefulWidth);

        moveMouse(point(px(10), px(10)));
        assertEquals(initialRenderCount + 2, view.renderCount);
        assertEquals(1, view.anonymousPaintCount);
        assertEquals(10.0, view.statefulWidth);
    }

/// Computed styles

    function testComputedStyleFollowsTheStateOfEachPhase() {
        // GPUI computes a new style in each phase: the port reuses the style
        // of the previous phase only while the same refinements apply
        addWindow((_, _) -> new GroupHoverTestView());
        cx.update((window, app) -> {
            final element = div().w(px(10)).hover(style -> style.w(px(20))).active(style -> style.w(px(30)));
            final interactivity = element.interactivity;
            final state = new InteractiveElementState();
            state.hoverState = new glaze.Interactivity.ElementHoverState();
            inline function compute() {
                return @:privateAccess interactivity.computeStyleInternal(null, state, window, app);
            }
            inline function width(style:glaze.Style):Float {
                return switch style.sizeWidth {
                    case Definite(Absolute(Pixels(value))): value;
                    case _: Math.NaN;
                }
            }

            final layout = compute();
            assertEquals(10.0, width(layout));
            final prepaint = compute();
            assertTrue(prepaint == layout, 'same inputs: style reused');

            state.hoverState.element = true;
            final hovered = compute();
            assertTrue(hovered != layout, 'hover changed: new style');
            assertEquals(20.0, width(hovered));
            assertEquals(10.0, width(layout), 'the previous style is not modified');

            state.clickedState.element = true;
            final active = compute();
            assertEquals(30.0, width(active));

            state.hoverState.element = false;
            state.clickedState.element = false;
            final again = compute();
            assertTrue(again != active);
            assertEquals(10.0, width(again));
        });
    }

/// Hover listeners

    function testDefaultHoverListenerUpdatesWhenLayoutChangesUnderStationaryMouse() {
        final transitions:Array<Bool> = [];
        final window = addWindow((_, _) -> new HoverListenerLayoutTestView(40, transitions, false));

        cx.update((window, cx) -> {
            window.draw();
            simulateMouseMove(window, point(px(10), px(10)), cx);
        });
        assertEquals('', transitions.join(','));

        window.update(app, (view, cx) -> {
            view.targetLeft = 0;
            cx.notify();
        });
        draw();
        assertEquals('true', transitions.join(','));

        window.update(app, (view, cx) -> {
            view.targetLeft = 40;
            cx.notify();
        });
        draw();
        assertEquals('true,false', transitions.join(','));
    }

    function testDefaultHoverListenerEndsAfterKeyPress() {
        final transitions:Array<Bool> = [];
        addWindow((_, _) -> new HoverListenerLayoutTestView(0, transitions, false));

        cx.update((window, cx) -> {
            window.draw();
            simulateMouseMove(window, point(px(10), px(10)), cx);
        });
        assertEquals('true', transitions.join(','));

        keyDown('a');
        draw();
        assertEquals('true,false', transitions.join(','));
    }

    function testInputModalityIndependentHoverListenerUpdatesAfterKeyPress() {
        final transitions:Array<Bool> = [];
        final window = addWindow((_, _) -> new HoverListenerLayoutTestView(40, transitions, true));
        final pointerPosition = point(px(10), px(10));

        cx.update((window, cx) -> {
            window.draw();
            simulateMouseMove(window, pointerPosition, cx);
        });
        assertEquals('', transitions.join(','));

        keyDown('a');
        window.update(app, (view, cx) -> {
            view.targetLeft = 0;
            cx.notify();
        });
        draw();
        assertEquals('true', transitions.join(','));

        keyDown('b');
        draw();
        assertEquals('true', transitions.join(','));

        cx.update((window, cx) -> simulateMouseMove(window, point(px(30), px(10)), cx));
        assertEquals('true,false', transitions.join(','));

        cx.update((window, cx) -> {
            simulateMouseMove(window, pointerPosition, cx);
            window.dispatchEvent(new MouseExitEvent(pointerPosition, null, Modifiers.none()), cx);
        });
        assertEquals('true,false,true,false', transitions.join(','));
    }

    function testDefaultHoverListenerRemainsHoveredDuringStationaryMousePress() {
        final transitions:Array<Bool> = [];
        addWindow((_, _) -> new HoverListenerLayoutTestView(0, transitions, false));
        final mousePosition = point(px(10), px(10));

        cx.update((window, cx) -> {
            window.draw();
            simulateMouseMove(window, mousePosition, cx);
        });
        assertEquals('true', transitions.join(','));

        cx.update((window, cx) -> {
            window.dispatchEvent(new MouseDownEvent(Left, mousePosition, Modifiers.none(), 1, false), cx);
            window.draw();
        });
        assertEquals('true', transitions.join(','));

        cx.update((window, cx) -> {
            window.dispatchEvent(new MouseUpEvent(Left, mousePosition, Modifiers.none(), 1), cx);
            window.draw();
        });
        assertEquals('true', transitions.join(','));
    }

/// Scroll handle

    function testScrollHandleAlignsWideChildrenToLeftEdge() {
        final handle = new ScrollHandle();
        @:privateAccess {
            final state = handle.state;
            state.bounds = bounds(point(px(0), px(0)), size(px(80), px(20)));
            state.childBounds.push(bounds(point(px(25), px(0)), size(px(200), px(20))));
            state.overflowX = Scroll;
            state.activeItemIndex = 0;
        }

        @:privateAccess handle.scrollToActiveItem();

        assertEquals(-25.0, handle.offset().x);
    }

    function testScrollHandleAlignsTallChildrenToTopEdge() {
        final handle = new ScrollHandle();
        @:privateAccess {
            final state = handle.state;
            state.bounds = bounds(point(px(0), px(0)), size(px(20), px(80)));
            state.childBounds.push(bounds(point(px(0), px(25)), size(px(20), px(200))));
            state.overflowY = Scroll;
            state.activeItemIndex = 0;
        }

        @:privateAccess handle.scrollToActiveItem();

        assertEquals(-25.0, handle.offset().y);
    }

    /**
     * The root div and the content of a scrolled div sit at `(0px, 0px)` in
     * GPUI with a positive zero (`round_half_toward_zero` copies the sign of
     * its input, and `layout_bounds` always adds the element offset): GPUI's
     * inspector prints `(0px, 0px)` there, never `(-0px, -0px)`.
     */
    function testScrolledContentBoundsKeepPositiveZero() {
        final scrollHandle = new ScrollHandle();
        final prepainted:Array<Array<Bounds>> = [];
        addWindow((_, _) -> new ScrolledContent(scrollHandle, prepainted));
        draw();

        cx.update((window, cx) -> window.dispatchEvent(new ScrollEvent(point(px(10), px(10)), ScrollDelta.Pixels(point(px(0), px(-30)))), cx));
        draw();
        assertEquals(-30.0, scrollHandle.offset().y);
        var content = prepainted[prepainted.length - 1][1];
        assertTrue(isPositiveZero(content.origin.x));
        assertEquals(-30.0, content.origin.y);

        cx.update((window, cx) -> window.dispatchEvent(new ScrollEvent(point(px(10), px(10)), ScrollDelta.Pixels(point(px(0), px(30)))), cx));
        draw();
        assertEquals(0.0, scrollHandle.offset().y);
        final root = prepainted[prepainted.length - 1][0];
        content = prepainted[prepainted.length - 1][1];
        assertTrue(isPositiveZero(root.origin.x));
        assertTrue(isPositiveZero(root.origin.y));
        assertTrue(isPositiveZero(content.origin.x));
        assertTrue(isPositiveZero(content.origin.y));
    }

    /**
     * Ceramic's `mouseScroll` (browser sign: positive moves the content up or
     * left) becomes GPUI's `ScrollDelta` with the opposite sign, in pixels or
     * in lines like GPUI's platforms (`hasPreciseScrollingDeltas` on macOS,
     * `deltaMode` on the web).
     */
    function testCeramicScrollMapsToGpuiScrollDelta() {
        switch glaze.GlazeInput.scrollDeltaOf(3, 12.5, ceramic.ScrollUnit.PIXELS) {
            case Pixels(delta):
                assertEquals(-3.0, (delta.x : Float));
                assertEquals(-12.5, (delta.y : Float));
            case _:
                fail('expected a pixel delta');
        }
        switch glaze.GlazeInput.scrollDeltaOf(0, 2, ceramic.ScrollUnit.LINES) {
            case Lines(delta):
                assertEquals(0.0, delta.x);
                assertEquals(-2.0, delta.y);
            case _:
                fail('expected a line delta');
        }
    }

    /**
     * A line scroll moves a scrollable div by the line height (GPUI's
     * `ScrollDelta::pixel_delta`), a pixel scroll by the pixels as they are:
     * the speed of a notched wheel and of a trackpad match GPUI.
     */
    function testLineAndPixelScrollSpeeds() {
        final scrollHandle = new ScrollHandle();
        final prepainted:Array<Array<Bounds>> = [];
        addWindow((_, _) -> new ScrolledContent(scrollHandle, prepainted));
        draw();

        cx.update((window, cx) -> window.dispatchEvent(new ScrollEvent(point(px(10), px(10)), glaze.GlazeInput.scrollDeltaOf(0, 7, ceramic.ScrollUnit.PIXELS)), cx));
        draw();
        assertEquals(-7.0, scrollHandle.offset().y);

        final before = scrollHandle.offset().y;
        cx.update((window, cx) -> window.dispatchEvent(new ScrollEvent(point(px(10), px(10)), glaze.GlazeInput.scrollDeltaOf(0, 1, ceramic.ScrollUnit.LINES)), cx));
        draw();
        final moved = before - scrollHandle.offset().y;
        // One line is the line height of the window's text style (GPUI's default text style)
        assertTrue(moved > 10 && moved < 40, 'one line scrolled $moved px');
        assertEquals(-prepainted[prepainted.length - 1][1].origin.y, -scrollHandle.offset().y);
    }

    static function isPositiveZero(value:Float):Bool {
        return value == 0 && 1 / value > 0;
    }

/// Tooltips

    function createTooltipOwnerTest(showDelayOverride:Null<Float>):TooltipOwner {
        final owner = addWindow((_, _) -> new TooltipOwner(showDelayOverride)).read(app);
        draw();
        return owner;
    }

    function setupTooltipOwnerTest(showDelayOverride:Null<Float>):TooltipOwner {
        final owner = createTooltipOwnerTest(showDelayOverride);
        cx.update((window, cx) -> {
            window.dispatchEvent(new MouseMoveEvent(point(px(10), px(10)), null, Modifiers.none()), cx);
        });
        draw();
        return owner;
    }

    function testTooltipWaitingForShowIsReleasedWhenItsOwnerDisappears() {
        final owner = setupTooltipOwnerTest(null);

        final activeTooltip = owner.capturedActiveTooltip;
        assertNotNull(activeTooltip);
        assertTrue(activeTooltip.alive);
        assertTrue(isWaitingForShow(activeTooltip));

        // Rust `window.remove_window()`
        cx.update((window, _) -> window.destroy());
        cx.runUntilParked();

        assertFalse(activeTooltip.alive);
    }

    function testLongPressShowsTooltipUntilTouchEnds() {
        final owner = createTooltipOwnerTest(null);
        final activeTooltip = owner.capturedActiveTooltip;
        assertNotNull(activeTooltip);
        final touchPosition = point(px(49), px(10));

        cx.update((window, cx) -> {
            window.dispatchEvent(new glaze.TouchEvent(1, Started, touchPosition), cx);
        });
        cx.advanceClock(glaze.GestureTuning.defaults().longPressDuration + 0.001);
        cx.runUntilParked();

        assertTrue(isVisible(activeTooltip));

        final movedPosition = point(px(55), px(10));
        cx.update((window, cx) -> {
            window.dispatchEvent(new glaze.TouchEvent(1, Moved, movedPosition), cx);
            window.draw();
        });
        assertTrue(isVisible(activeTooltip));

        cx.update((window, cx) -> {
            window.dispatchEvent(new glaze.TouchEvent(1, Ended, movedPosition), cx);
        });

        assertNull(activeTooltip.value);
    }

    function testTooltipRespectsCustomShowDelay() {
        final extraDelay = 1.0;
        final showDelayOverride = Interactivity.DEFAULT_TOOLTIP_SHOW_DELAY + extraDelay;
        final owner = setupTooltipOwnerTest(showDelayOverride);

        final activeTooltip = owner.capturedActiveTooltip;
        assertNotNull(activeTooltip);

        cx.advanceClock(Interactivity.DEFAULT_TOOLTIP_SHOW_DELAY);
        cx.runUntilParked();

        assertTrue(isWaitingForShow(activeTooltip));

        cx.advanceClock(extraDelay);
        cx.runUntilParked();

        assertTrue(isVisible(activeTooltip));
    }

    function testTooltipIsReleasedWhenItsOwnerDisappears() {
        final owner = setupTooltipOwnerTest(null);

        final activeTooltip = owner.capturedActiveTooltip;
        assertNotNull(activeTooltip);

        cx.advanceClock(Interactivity.DEFAULT_TOOLTIP_SHOW_DELAY);
        cx.runUntilParked();

        assertTrue(isVisible(activeTooltip));

        // Rust `window.remove_window()`
        cx.update((window, _) -> window.destroy());
        cx.runUntilParked();

        assertFalse(activeTooltip.alive);
    }

    function testTooltipHidesAfterMouseLeavesOrigin() {
        final owner = setupTooltipOwnerTest(null);

        final activeTooltip = owner.capturedActiveTooltip;
        assertNotNull(activeTooltip);

        cx.advanceClock(Interactivity.DEFAULT_TOOLTIP_SHOW_DELAY);
        cx.runUntilParked();

        assertTrue(isVisible(activeTooltip));

        cx.update((window, cx) -> {
            window.dispatchEvent(new MouseMoveEvent(point(px(75), px(75)), null, Modifiers.none()), cx);
        });

        assertFalse(activeTooltip.isSome());
    }

/// Keyboard activation

    function setupKeyboardActivationTest():KeyboardActivationTest {
        final focusA = app.focusHandle();
        final focusB = app.focusHandle();
        final view = addWindow((_, _) -> new KeyboardActivationTest(focusA, focusB)).read(app);
        return view;
    }

    /**
     * Move focus to `handle`, flush effects, then paint so the newly focused
     * element registers its key handlers for the next dispatched event.
     */
    function focusAndDraw(handle:FocusHandle):Void {
        cx.update((window, cx) -> window.focus(handle, cx));
        cx.runUntilParked();
        draw();
    }

    /** Pressing and releasing Enter on the same focused element fires a click. */
    function testKeyboardActivationFiresClickOnSameElement() {
        final test = setupKeyboardActivationTest();

        focusAndDraw(test.focusA);
        keyDown('enter');
        keyUp('enter');

        assertEquals('a', test.clicks.join(','));
    }

    /**
     * A key-down whose key-up lands on a different element (because focus
     * moved in between) must not leak a synthesized click onto the newly
     * focused element.
     */
    function testKeyboardActivationDoesNotLeakAcrossFocusChange() {
        final test = setupKeyboardActivationTest();

        // Enter pressed while "a" is focused...
        focusAndDraw(test.focusA);
        keyDown('enter');

        // ...focus moves to "b" before the release (as a confirm action would)...
        focusAndDraw(test.focusB);
        keyUp('enter');

        // ...so neither element is clicked.
        assertEquals('', test.clicks.join(','));
    }

    /**
     * A keydown whose flag is left pending because focus moved away before
     * the keyup must not fire a click when focus later returns to the same element.
     */
    function testKeyboardActivationDoesNotLeakWhenFocusReturns() {
        final test = setupKeyboardActivationTest();

        focusAndDraw(test.focusA);
        keyDown('enter');

        focusAndDraw(test.focusB);
        focusAndDraw(test.focusA);
        keyUp('enter');

        assertEquals('', test.clicks.join(','));
    }

    /**
     * A non-activation key released during the press must cancel the pending activation.
     */
    function testKeyboardActivationClearedByInterveningKeyRelease() {
        final test = setupKeyboardActivationTest();

        focusAndDraw(test.focusA);
        keyDown('escape');
        keyDown('space');
        keyUp('escape');
        keyUp('space');

        assertEquals('', test.clicks.join(','));
    }

    /**
     * A Space down paired with an Enter up on the same element still fires a click.
     */
    function testKeyboardActivationDoesNotDistinguishSpaceAndEnter() {
        final test = setupKeyboardActivationTest();

        focusAndDraw(test.focusA);
        keyDown('space');
        keyUp('enter');

        assertEquals('a', test.clicks.join(','));
    }

    /**
     * A non-activation key pressed between the activation down and up clears
     * the pending flag, suppressing the click.
     */
    function testKeyboardActivationClearedByInterveningKeydown() {
        final test = setupKeyboardActivationTest();

        focusAndDraw(test.focusA);
        keyDown('enter');
        keyDown('a');
        keyUp('enter');

        assertEquals('', test.clicks.join(','));
    }

    /**
     * A modified Enter (e.g. cmd-enter) is not treated as an activation key.
     */
    function testKeyboardActivationIgnoresModifiedKeys() {
        final test = setupKeyboardActivationTest();

        focusAndDraw(test.focusA);
        keyDown('cmd-enter');
        keyUp('cmd-enter');

        assertEquals('', test.clicks.join(','));
    }

/// Tab groups

    /**
     * Focusing a tab-group container and pressing Tab (`focusNext`) must move
     * focus to the first tab stop inside that container.
     */
    function testFocusNextFromTabGroupContainerEntersThatGroup() {
        final groupA = app.focusHandle();
        final itemA = app.focusHandle().tabStop(true);
        final groupB = app.focusHandle();
        final itemB = app.focusHandle().tabStop(true);
        addWindow((_, _) -> new TabGroupFocus(groupA, itemA, groupB, itemB));
        draw();

        // Focus the second group's container, then advance like Tab would.
        final focused = cx.update((window, cx) -> {
            window.focus(groupB, cx);
            window.focusNext(cx);
            final handle = window.focused(cx);
            return handle != null ? handle.id : -1;
        });

        assertEquals(itemB.id, focused);
    }

/// Scrollability

    function testFractionalPaddingDoesNotMakeAFittingContainerScrollable() {
        final scrollHandle = new ScrollHandle();
        addWindow((_, _) -> new PaddedContainer(scrollHandle));
        draw();

        assertEquals(0.0, scrollHandle.maxOffset().y);
    }

}

private class GroupHoverTestView extends Model implements Render {

    public var renderCount:Int = 0;

    public var anonymousPaintCount:Int = 0;

    public var statefulWidth:Float = 0;

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renderCount++;
        return div().sizeFull().child(
            div()
                .ml(px(20))
                .mt(px(20))
                .size(px(50))
                .relative()
                .group('hover-group')
                .child(
                    div()
                        .absolute()
                        .sizeFull()
                        .invisible()
                        .groupHover('hover-group', style -> style.visible())
                        .child(canvas((_, _, _) -> 0, (_, _, _, _) -> anonymousPaintCount++))
                )
                .child(
                    div()
                        .id('stateful-group-hover-target')
                        .absolute()
                        .top0()
                        .left0()
                        .size(px(10))
                        .groupHover('hover-group', style -> style.size(px(20)))
                        .child(canvas((bounds, _, _) -> {
                            statefulWidth = bounds.size.width;
                            return 0;
                        }, (_, _, _, _) -> {}))
                )
        );
    }

}

/**
 * Rust `HoverListenerLayoutTestView` and `HoverListenerModeLayoutTestView` (the
 * latter uses `HoverListenerMode.InputModalityIndependent` and has no click listener).
 */
private class HoverListenerLayoutTestView extends Model implements Render {

    public var targetLeft:Float;

    final hoverTransitions:Array<Bool>;

    final modalityIndependent:Bool;

    public function new(targetLeft:Float, hoverTransitions:Array<Bool>, modalityIndependent:Bool) {
        super();
        this.targetLeft = targetLeft;
        this.hoverTransitions = hoverTransitions;
        this.modalityIndependent = modalityIndependent;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var target = div()
            .id('hover-target')
            .absolute()
            .left(px(targetLeft))
            .top0()
            .size(px(20));
        if (modalityIndependent) {
            target = target.hoverListenerMode(InputModalityIndependent);
        }
        else {
            target = target.onClick((_, _, _) -> {});
        }
        return div().relative().sizeFull().child(
            target.onHover((isHovered, _, _) -> hoverTransitions.push(isHovered))
        );
    }

}

private class TestTooltipView extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(20)).h(px(20));
    }

}

/**
 * Paints its child, then captures the active tooltip of the element with id `target`
 * from its interactive element state.
 */
private class TooltipCaptureElement extends Element {

    final child:AnyElement;

    final owner:TooltipOwner;

    public function new(child:AnyElement, owner:TooltipOwner) {
        this.child = child;
        this.owner = owner;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        return child.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        child.paint(window, cx);
        window.withGlobalId('target', (globalId, window) -> {
            window.withElementState(globalId, InteractiveElementState, (state, _) -> {
                owner.capturedActiveTooltip = state.value.activeTooltip;
                return null;
            });
        });
    }

}

private class TooltipOwner extends Model implements Render {

    public var capturedActiveTooltip:Null<ActiveTooltipCell> = null;

    final showDelayOverride:Null<Float>;

    public function new(showDelayOverride:Null<Float>) {
        super();
        this.showDelayOverride = showDelayOverride;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        var target = div()
            .id('target')
            .w(px(50))
            .h(px(50))
            .tooltip((_, cx) -> cx.newEntity(_ -> new TestTooltipView()));
        if (showDelayOverride != null) {
            target = target.tooltipShowDelay(showDelayOverride);
        }
        return new TooltipCaptureElement(div().sizeFull().child(target).intoAnyElement(), this);
    }

}

/**
 * Two focusable, clickable elements ("a" and "b") used to exercise the
 * Enter/Space to synthesized click press/release pairing.
 */
private class KeyboardActivationTest extends Model implements Render {

    public final focusA:FocusHandle;

    public final focusB:FocusHandle;

    public final clicks:Array<String> = [];

    public function new(focusA:FocusHandle, focusB:FocusHandle) {
        super();
        this.focusA = focusA;
        this.focusB = focusB;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .child(
                div()
                    .id('a')
                    .w(px(50))
                    .h(px(50))
                    .trackFocus(focusA)
                    .onClick((_, _, _) -> clicks.push('a'))
            )
            .child(
                div()
                    .id('b')
                    .w(px(50))
                    .h(px(50))
                    .trackFocus(focusB)
                    .onClick((_, _, _) -> clicks.push('b'))
            );
    }

}

/**
 * Two sibling tab groups, each a focusable container that is not itself a
 * tab stop and holds a single tab stop.
 */
private class TabGroupFocus extends Model implements Render {

    final groupA:FocusHandle;

    final itemA:FocusHandle;

    final groupB:FocusHandle;

    final itemB:FocusHandle;

    public function new(groupA:FocusHandle, itemA:FocusHandle, groupB:FocusHandle, itemB:FocusHandle) {
        super();
        this.groupA = groupA;
        this.itemA = itemA;
        this.groupB = groupB;
        this.itemB = itemB;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        inline function group(container:FocusHandle, item:FocusHandle) {
            return div()
                .trackFocus(container)
                .tabGroup()
                .child(div().trackFocus(item));
        }
        return div()
            .child(group(groupA, itemA))
            .child(group(groupB, itemB));
    }

}

/** A scroll container at the origin; its bounds and the bounds of its scrolled content are recorded at each prepaint. */
private class ScrolledContent extends Model implements Render {

    final scrollHandle:ScrollHandle;

    final prepainted:Array<Array<Bounds>>;

    public function new(scrollHandle:ScrollHandle, prepainted:Array<Array<Bounds>>) {
        super();
        this.scrollHandle = scrollHandle;
        this.prepainted = prepainted;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final prepainted = this.prepainted;
        return div()
            .sizeFull()
            .child(
                div()
                    .id('scroll')
                    .h(px(50))
                    .w(px(100))
                    .overflowYScroll()
                    .trackScroll(scrollHandle)
                    .child(
                        div()
                            .wFull()
                            .h(px(200))
                            .onChildrenPrepainted((b, _, _) -> prepainted.push([scrollHandle.bounds(), b[0]]))
                            .child(div().sizeFull())
                    )
            );
    }

}

private class PaddedContainer extends Model implements Render {

    final scrollHandle:ScrollHandle;

    public function new(scrollHandle:ScrollHandle) {
        super();
        this.scrollHandle = scrollHandle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        // 4.25px of padding snaps to 4px in layout, so a 42px child
        // fits the 50px box exactly.
        return div().sizeFull().child(
            div()
                .id('container')
                .h(px(50))
                .w(px(100))
                .py(px(4.25))
                .overflowYScroll()
                .trackScroll(scrollHandle)
                .child(div().wFull().h(px(42)))
        );
    }

}
