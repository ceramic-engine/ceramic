// Ported from gpui-kit 0.8.1: crates/kit/tests/integration/touch_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.LongPressEvent;
import gpui.Model;
import gpui.Modifiers;
import gpui.MouseButton;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.MouseUpEvent;
import gpui.Point;
import gpui.Render;
import gpui.ScrollDelta;
import gpui.ScrollEvent;
import gpui.TestDispatcher;
import gpui.TouchDragEvent;
import gpui.TouchPhase;
import gpui.Window;
import gpui.base.TextSelection;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputState;
import gpui.base.input.InputTouch;
import gpui.base.input.TouchSelectionSnapshot;
import gpui.base.text.TextViewState;
import gpui.component.Component;
import gpui.component.input.Input;
import gpui.component.text.TextView;
import tests.kit.ComponentScrollTest.Probe;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * gpui-kit's touch selection integration tests: a long press leaves a
 * selection with grab handles and an edit menu, in an `Input` and in a
 * `TextView`.
 *
 * Rust finds elements by test support ids and asserts the edit menu by
 * finding its "Copy" item; the port probes bounds with `Probe` and reads the
 * menu's state from the touch selection snapshot (`isMenuOpen`). The tests
 * that press the menu's items (`long_press_in_input_offers_copy_which_closes_the_menu`,
 * `long_press_in_input_select_all_keeps_the_menu`, `long_press_in_text_view_offers_copy_and_select_all`,
 * `copy_after_select_all_keeps_the_whole_selection`, `select_all_after_a_drag_stays_put_frame_after_frame`)
 * and `a_selection_under_a_cached_view_holds_still_and_keeps_its_handles`
 * (cached view frames in the Rust harness) are not ported yet: the port has
 * no test support finder for the menu's items.
 */
class TouchSelectionIntegrationTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Component.init(cx));
        Probe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        Probe.bounds.clear();
        ceramic.App.app.flushImmediate();
    }

    /** `common::open_window`: a `Root` around the content built by `build`. */
    function openRoot<V:Model & Render>(build:(Window, Context<V>) -> V):{content:Entity<V>, cx:VisualTestContext} {
        var content:Entity<V> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, rootCx:Context<gpui.base.Root>) -> {
            content = rootCx.newEntity((cx:Context<V>) -> build(window, cx));
            return new gpui.base.Root(content, window, rootCx);
        });
        contexts.push(opened.cx);
        return {content: content, cx: opened.cx};
    }

    /** `window.render_frame(cx)`. */
    static function renderFrame(window:Window):Void {
        window.refresh();
        window.draw();
    }

    static function longPress(window:Window, cx:App, position:Point):Void {
        for (phase in [TouchPhase.Started, TouchPhase.Ended]) {
            window.dispatchEvent(new LongPressEvent(phase, position, position), cx);
            renderFrame(window);
        }
    }

    /**
     * `window.drag(from, to)` (gpui-kit `test.rs`): a frame, a move to the
     * start, a press, eight moves to the end and a release, each followed
     * by a frame.
     */
    static function mouseDrag(window:Window, cx:App, from:Point, to:Point):Void {
        renderFrame(window);
        window.dispatchEvent(new MouseMoveEvent(from, null, Modifiers.none()), cx);
        renderFrame(window);
        window.dispatchEvent(new MouseDownEvent(Left, from, Modifiers.none(), 1, false), cx);
        renderFrame(window);
        for (step in 1...9) {
            final fraction = step / 8.;
            window.dispatchEvent(new MouseMoveEvent(new Point(from.x + (to.x - from.x) * fraction, from.y + (to.y - from.y) * fraction), Left, Modifiers.none()), cx);
            renderFrame(window);
        }
        window.dispatchEvent(new MouseUpEvent(Left, to, Modifiers.none(), 1), cx);
        renderFrame(window);
    }

    /** The knob the finger takes hangs below the line for the end handle. */
    static function endKnob(snapshot:TouchSelectionSnapshot):Point {
        final end = snapshot.end();
        return new Point(end.left(), end.bottom() + 6.);
    }

    function screen():{content:Entity<Screen>, cx:VisualTestContext} {
        return openRoot((window, cx) -> new Screen(window, cx));
    }

    static function focusedInput(window:Window, cx:App):InputBaseState {
        return @:privateAccess gpui.component.WindowExt.focusedInput(window, cx).asInput().read(cx);
    }

    function testEndHandleDragsTheInputSelectionWithAFinger() {
        final cx = screen().cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final inputBounds = Probe.bounds.get('input');
            longPress(window, app, new Point(inputBounds.left() + 24., inputBounds.center().y));
            final input = focusedInput(window, app);
            final snapshot = InputTouch.touchSelection(input);
            assertNotNull(snapshot, 'handles are shown');
            assertTrue(snapshot.isMenuOpen());
            final start = endKnob(snapshot);

            // The drag is offered on the first touch; the handle claims it
            // and the menu steps aside until the finger lifts.
            final farRight = new Point(inputBounds.right() - 8., start.y);
            for (step in [{phase: TouchPhase.Started, position: start}, {phase: TouchPhase.Moved, position: farRight}]) {
                window.dispatchEvent(new TouchDragEvent(step.phase, start, step.position), app);
                renderFrame(window);
            }
            assertFalse(InputTouch.touchSelection(focusedInput(window, app)).isMenuOpen(), 'the menu hides while dragging');
            assertEquals('quick select value', focusedInput(window, app).selectedText().toString());

            window.dispatchEvent(new TouchDragEvent(Ended, start, farRight), app);
            renderFrame(window);
            assertTrue(InputTouch.touchSelection(focusedInput(window, app)).isMenuOpen(), 'the menu is back once the finger lifts');
            assertEquals('quick select value', focusedInput(window, app).selectedText().toString());
        });
    }

    function testEndHandleDragsTheTextViewSelectionWithAMouse() {
        final cx = screen().cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final text = Probe.bounds.get('text');
            longPress(window, app, new Point(text.left() + 8., text.top() + 10.));
            final snapshot = TextSelection.touchSelection(window, app);
            assertNotNull(snapshot, 'handles are shown');
            final start = endKnob(snapshot);
            mouseDrag(window, app, start, new Point(text.right() - 8., start.y));
            assertEquals('quick select value', StringTools.trim(TextSelection.selectedText(window, app)));
            final snapshot = TextSelection.touchSelection(window, app);
            assertTrue(snapshot.isMenuOpen(), 'the menu is back once the button is released');
            assertNull(snapshot.dragging());
        });
    }

    function testAHandleStopsAtTheOtherEndInsteadOfCollapsingTheSelection() {
        final cx = screen().cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final text = Probe.bounds.get('text');
            longPress(window, app, new Point(text.left() + 8., text.top() + 10.));
            assertEquals('quick', StringTools.trim(TextSelection.selectedText(window, app)));

            // Pull the end handle back over the word, one short drag at a
            // time, then past its start where the paragraph has nothing more
            // to select.
            for (delta in [-6., -12., -20., -30., -40.]) {
                final snapshot = TextSelection.touchSelection(window, app);
                assertNotNull(snapshot, 'still live');
                final start = endKnob(snapshot);
                mouseDrag(window, app, start, new Point(start.x + delta, start.y));
            }
            assertEquals('q', StringTools.trim(TextSelection.selectedText(window, app)));
            final snapshot = TextSelection.touchSelection(window, app);
            assertNotNull(snapshot, 'a character is left');
            assertTrue(snapshot.isMenuOpen());
        });

        cx.update((window, app) -> {
            // The text's menu floats over the input; put it away first.
            TextSelection.clear(window, app);
            renderFrame(window);
            final inputBounds = Probe.bounds.get('input');
            longPress(window, app, new Point(inputBounds.left() + 24., inputBounds.center().y));
            assertEquals('quick', focusedInput(window, app).selectedText().toString());
            for (delta in [-6., -12., -20., -30.]) {
                final snapshot = InputTouch.touchSelection(focusedInput(window, app));
                assertNotNull(snapshot, 'still live');
                final start = endKnob(snapshot);
                mouseDrag(window, app, start, new Point(start.x + delta, start.y));
            }
            assertEquals('q', focusedInput(window, app).selectedText().toString());
            assertNotNull(InputTouch.touchSelection(focusedInput(window, app)));
        });
    }

    function testTheFirstMoveAfterTakingAHandleIsNotLost() {
        final cx = screen().cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final inputBounds = Probe.bounds.get('input');
            longPress(window, app, new Point(inputBounds.left() + 24., inputBounds.center().y));
            final snapshot = InputTouch.touchSelection(focusedInput(window, app));
            final start = endKnob(snapshot);
            final farRight = new Point(inputBounds.right() - 8., start.y);
            // No frame between the three phases: the drag begins, moves and
            // ends before the handles could re-render around it.
            for (step in [{phase: TouchPhase.Started, position: start}, {phase: TouchPhase.Moved, position: farRight}, {phase: TouchPhase.Ended, position: farRight}]) {
                window.dispatchEvent(new TouchDragEvent(step.phase, start, step.position), app);
            }
            renderFrame(window);
            assertEquals('quick select value', focusedInput(window, app).selectedText().toString());
            final snapshot = InputTouch.touchSelection(focusedInput(window, app));
            assertNull(snapshot.dragging());
            assertTrue(snapshot.isMenuOpen());
        });
    }

    function testADoubleTapInTextViewSelectsNothing() {
        final cx = screen().cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final text = Probe.bounds.get('text');
            final position = new Point(text.left() + 8., text.top() + 10.);
            // A finger's double tap: the touch is offered as a drag first, as
            // GPUI does, then arrives as a two-click press.
            window.dispatchEvent(new TouchDragEvent(Started, position, position), app);
            window.dispatchEvent(new MouseDownEvent(Left, position, Modifiers.none(), 2, false), app);
            window.dispatchEvent(new MouseUpEvent(Left, position, Modifiers.none(), 2), app);
            renderFrame(window);
            renderFrame(window);
            // Read-only text takes a finger's long press only.
            assertEquals('', StringTools.trim(TextSelection.selectedText(window, app)));
            assertNull(TextSelection.touchSelection(window, app));
        });
    }

    function testSelectAllTakesTheTextBeyondTheViewport() {
        final cx = openRoot((window, cx) -> new TallScreen(window, cx)).cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final text = Probe.bounds.get('text');
            longPress(window, app, new Point(text.left() + 8., text.top() + 10.));
            assertEquals('first', StringTools.trim(TextSelection.selectedText(window, app)));

            // Rust clicks the menu's "Select All", which calls this.
            TextSelection.selectAll(window, app);
            renderFrame(window);
            assertEquals('first line\nsecond line\nthird line\nlast line', StringTools.trim(TextSelection.selectedText(window, app)), 'the whole text, not the lines the box shows');
        });
    }

    function testTheMenuComesBackAfterAScrollTheContainerSwallowed() {
        final cx = openRoot((window, cx) -> new SwallowingScreen(window, cx)).cx;
        cx.update((window, app) -> {
            renderFrame(window);
            final text = Probe.bounds.get('text');
            longPress(window, app, new Point(text.left() + 8., text.top() + 10.));
            assertTrue(TextSelection.touchSelection(window, app).isMenuOpen(), 'the menu is up');

            // A finger scrolls: the menu steps aside while it moves, and
            // comes back when it lifts, even when the scroll container
            // stopped every packet before the selection's own listener.
            final position = new Point(text.center().x, text.bottom() + 40.);
            final menuSeen:Array<Bool> = [];
            for (step in [{phase: TouchPhase.Started, dy: 0.}, {phase: TouchPhase.Moved, dy: -12.}, {phase: TouchPhase.Ended, dy: 0.}]) {
                window.dispatchEvent(new ScrollEvent(position, ScrollDelta.Pixels(new Point(0., step.dy)), Modifiers.none(), step.phase), app);
                renderFrame(window);
                final snapshot = TextSelection.touchSelection(window, app);
                menuSeen.push(snapshot != null && snapshot.isMenuOpen());
            }
            assertEquals('false,false,true', menuSeen.join(','), 'aside while the finger moves, back when it lifts');
            assertEquals('quick', StringTools.trim(TextSelection.selectedText(window, app)));
        });
    }

}

private class Screen extends Model implements Render {

    public final input:Entity<InputState>;

    public final text:Entity<TextViewState>;

    public function new(window:Window, cx:Context<Screen>) {
        super();
        input = cx.newEntity((c:Context<InputState>) -> {
            final state = new InputState(window, c);
            state.defaultValue('quick select value');
            return state;
        });
        text = cx.newEntity((c:Context<TextViewState>) -> TextViewState.markdown('quick select value', c));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .gap4()
            .p4()
            .child(new Probe('input', new Input(input).id('input').w(px(320.))))
            .child(new Probe('text', div()
                .id('text')
                .w(px(320.))
                .child(TextView.create(text).selectable(true))));
    }

}

/** A screen whose text is taller than the scroll box it sits in. */
private class TallScreen extends Model implements Render {

    public final text:Entity<TextViewState>;

    public function new(window:Window, cx:Context<TallScreen>) {
        super();
        text = cx.newEntity((c:Context<TextViewState>) -> TextViewState.markdown('first line\n\nsecond line\n\nthird line\n\nlast line', c));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().p4().child(
            div()
                .id('box')
                .w(px(200.))
                .h(px(48.))
                .overflowYScroll()
                .child(new Probe('text', div()
                    .id('text')
                    .child(TextView.create(text).selectable(true))))
        );
    }

}

/**
 * A screen whose scroll container swallows every scroll packet on capture,
 * as `ScrollBounce` does while it is stretched past the end of its list.
 */
private class SwallowingScreen extends Model implements Render {

    public final text:Entity<TextViewState>;

    public function new(window:Window, cx:Context<SwallowingScreen>) {
        super();
        text = cx.newEntity((c:Context<TextViewState>) -> TextViewState.markdown('quick select value', c));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .p4()
            .child(canvas((_, _, _) -> 0, (_, _, window, _) -> {
                window.onMouseEvent(Scroll, (_, phase, _, cx) -> {
                    if (phase == Capture) {
                        cx.stopPropagation();
                    }
                });
            }).absolute().size(px(0)))
            .child(new Probe('text', div()
                .id('text')
                .w(px(320.))
                .child(TextView.create(text).selectable(true))));
    }

}
