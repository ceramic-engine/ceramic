// Ported from gpui-kit 0.8.1: crates/base/src/input/base/touch.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.LongPressEvent;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Modifiers;
import glaze.Point;
import glaze.TouchPhase;
import glaze.kit.base.GlobalState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.SelectionEdge;
import glaze.kit.base.input.TextareaState;
import glaze.kit.base.input.InputTouch;
import tests.kit.InputStateTestCase.InputView;

using glaze.kit.base.input.InputTouch;

/**
 * Touch selection of the input engine: a long press selects the word under
 * the finger and sweeps from there, a double tap keeps a word selection
 * with handles and the edit menu, the handles move one end at a time and
 * swap when crossed, and the touch selection goes away when something else
 * moves the selection.
 */
@:access(glaze.kit.base.input.InputTouch)
class InputTouchTest extends InputStateTestCase {

    override function setup() {
        super.setup();
        // Rust `cx.update(crate::init)`
        glaze.kit.base.Base.init(app);
    }

    function openInput(value:String):InputView {
        final view = build(state -> {
            return state;
        });
        view.update((state, window, cx) -> state.setValue(value, window, cx));
        view.cx.runUntilParked();
        view.cx.update((window, _) -> window.draw());
        return view;
    }

    function longPress(view:InputView, phase:TouchPhase, start:Point, at:Point):Void {
        view.cx.simulateEvent(new LongPressEvent(phase, start, at));
        view.cx.update((window, _) -> window.draw());
    }

    /** The window position of the caret before `offset`, in the input's line. */
    static function caretAt(view:InputView, offset:Int):Point {
        final state:InputBaseState = view.input.read(view.cx.app);
        final position = state.lineAndPositionForOffset(offset).position;
        final origin = state.lastBounds.origin;
        final lineHeight:Float = state.lastLayout.lineHeight;
        return new Point(origin.x + position.x, origin.y + position.y + lineHeight * 0.5);
    }

    static function text(view:InputView):String {
        return view.input.read(view.cx.app).selectedText().toString();
    }

    static function state(view:InputView):InputBaseState {
        return view.input.read(view.cx.app);
    }

    function testLongPressSelectsWordThenReleaseOpensMenu() {
        final view = openInput("quick select value");
        final start = caretAt(view, 8);
        longPress(view, Started, start, start);
        assertEquals("select", text(view));
        assertFalse(InputTouch.isEditMenuOpen(state(view)));
        var snapshot = InputTouch.touchSelection(state(view));
        assertNotNull(snapshot, "touch selection is live");
        assertFalse(snapshot.isEmpty());
        assertFalse(snapshot.isMenuOpen());

        final end = caretAt(view, 18);
        longPress(view, Moved, start, end);
        assertEquals("select value", text(view));

        longPress(view, Ended, start, end);
        assertEquals("select value", text(view));
        assertTrue(InputTouch.isEditMenuOpen(state(view)));
        snapshot = InputTouch.touchSelection(state(view));
        assertNotNull(snapshot);
        assertTrue(snapshot.isMenuOpen());
        assertTrue(snapshot.start().left() < snapshot.end().left());
    }

    function testDoubleTapSelectsWordWithHandlesAndMenu() {
        final view = openInput("quick select value");
        final position = caretAt(view, 8);
        // A tap arrives as mouse events; the touch that began it is what
        // tells the input they came from a finger.
        view.cx.update((_, cx) -> GlobalState.noteTouch(cx));
        for (clickCount in [1, 2]) {
            view.cx.simulateEvent(new MouseDownEvent(MouseButton.Left, position, Modifiers.none(), clickCount, false));
            view.cx.simulateEvent(new MouseUpEvent(MouseButton.Left, position, Modifiers.none(), clickCount));
        }
        view.cx.update((window, _) -> window.draw());
        assertEquals("select", text(view));
        final snapshot = InputTouch.touchSelection(state(view));
        assertNotNull(snapshot, "a double tap is a touch selection");
        assertTrue(snapshot.isMenuOpen());
    }

    function testLongPressOnEmptyInputPlacesCaretWithMenu() {
        final view = openInput("");
        final caret = caretAt(view, 0);
        longPress(view, Started, caret, caret);
        longPress(view, Ended, caret, caret);
        final range = state(view).selectedRange();
        assertEquals(0, range.start);
        assertEquals(0, range.end);
        final snapshot = InputTouch.touchSelection(state(view));
        assertNotNull(snapshot, "caret still gets a menu");
        assertTrue(snapshot.isEmpty());
        assertTrue(snapshot.isMenuOpen());
    }

    function testDraggingAHandleMovesThatEndOnly() {
        final view = openInput("quick select value");
        final start = caretAt(view, 8);
        longPress(view, Started, start, start);
        longPress(view, Ended, start, start);

        // The finger holds the end knob, which hangs below the line.
        final endCaret = caretAt(view, 12);
        final finger = new Point(endCaret.x, endCaret.y + 20);
        view.update((state, _, cx) -> state.beginEdgeDrag(SelectionEdge.End, finger, cx));
        var snapshot = InputTouch.touchSelection(state(view));
        assertEquals(SelectionEdge.End, snapshot.dragging());
        assertFalse(snapshot.isMenuOpen());

        var target = caretAt(view, 18);
        view.update((state, _, cx) -> state.updateEdgeDrag(new Point(target.x, target.y + 20), cx));
        assertEquals("select value", text(view));

        // Pull the start handle past the end: the ends swap, the finger keeps
        // its handle.
        view.update((state, _, cx) -> {
            state.endEdgeDrag(cx);
            assertTrue(InputTouch.isEditMenuOpen(state));
            final startCaret = InputTouch.touchSelection(state).start();
            state.beginEdgeDrag(SelectionEdge.Start, startCaret.origin, cx);
        });
        target = caretAt(view, 0);
        view.update((state, _, cx) -> state.updateEdgeDrag(target, cx));
        assertEquals("quick select value", text(view));
        final range = InputTouch.touchSelectionRange(state(view));
        assertEquals(0, range.start);
        assertEquals(18, range.end);
    }

    function testDraggingOneHandlePastTheOtherSwapsThem() {
        final view = openInput("quick select value");
        final start = caretAt(view, 8);
        longPress(view, Started, start, start);
        longPress(view, Ended, start, start);
        assertEquals("select", text(view));

        // Take the start handle and pull it past the end of "select" to the
        // end of the text: the finger now holds the end handle.
        final startCaret = caretAt(view, 6);
        view.update((state, _, cx) -> state.beginEdgeDrag(SelectionEdge.Start, startCaret, cx));
        var target = caretAt(view, 18);
        view.update((state, _, cx) -> state.updateEdgeDrag(target, cx));
        assertEquals(" value", text(view));
        assertEquals(SelectionEdge.End, InputTouch.touchSelection(state(view)).dragging());

        // And back across again: it is the start handle once more.
        target = caretAt(view, 0);
        view.update((state, _, cx) -> {
            state.updateEdgeDrag(target, cx);
            state.endEdgeDrag(cx);
        });
        assertEquals("quick select", text(view));
        assertTrue(InputTouch.isEditMenuOpen(state(view)));
    }

    function testTouchSelectionGoesAwayWhenSomethingElseMovesTheSelection() {
        final view = openInput("quick select value");
        final start = caretAt(view, 2);
        longPress(view, Started, start, start);
        longPress(view, Ended, start, start);
        assertNotNull(InputTouch.touchSelection(state(view)));

        // Select All from the menu keeps it, over the new range.
        view.update((state, window, cx) -> state.selectAllFromEditMenu(window, cx));
        final range = state(view).selectedRange();
        assertEquals(0, range.start);
        assertEquals(18, range.end);
        assertNotNull(InputTouch.touchSelection(state(view)));
        assertTrue(InputTouch.isEditMenuOpen(state(view)));

        // Copy closes the menu but keeps the handles.
        view.update((state, _, cx) -> state.closeEditMenu(cx));
        assertFalse(InputTouch.touchSelection(state(view)).isMenuOpen());

        // Typing replaces the selection; nothing is left to hold a handle.
        view.update((state, window, cx) -> state.replaceTextInRangeSilent(null, "x", window, cx));
        assertNull(InputTouch.touchSelection(state(view)));

        // A press elsewhere drops it too.
        longPress(view, Started, start, start);
        longPress(view, Ended, start, start);
        assertNotNull(InputTouch.touchSelection(state(view)));
        final elsewhere = caretAt(view, 0);
        view.cx.simulateMouseDown(elsewhere, MouseButton.Left);
        assertNull(InputTouch.touchSelection(state(view)));
    }

    function testScrollingClosesTheMenuAndKeepsTheHandles() {
        // Short enough that forty lines scroll (Rust `TextareaRoot`).
        var input:glaze.Entity<InputBaseState> = null;
        final opened = testing.VisualTestContext.addWindowView(app, dispatcher, (window, cx:glaze.Context<testing.InteractionScript.ScriptView>) -> {
            glaze.kit.base.theme.Theme.globalMut(cx.app);
            glaze.kit.base.input.InputKeyBindings.init(cx.app);
            input = cx.app.newEntity((cx:glaze.Context<InputBaseState>) -> (new TextareaState(window, cx) : InputBaseState));
            final child = input;
            return new testing.InteractionScript.ScriptView((_, _) -> glaze.Prelude.div().w(glaze.Prelude.px(300)).h(glaze.Prelude.px(80)).child(child));
        });
        contexts.push(opened.cx);
        final view = new InputView(input, opened.cx);
        view.update((state, window, cx) -> state.setValue([for (ix in 0...40) 'line $ix'].join("\n"), window, cx));
        view.cx.runUntilParked();
        view.cx.update((window, _) -> window.draw());
        final s = state(view);
        final position = s.lineAndPositionForOffset(2).position;
        final start = new Point(s.lastBounds.origin.x + position.x, s.lastBounds.origin.y + position.y + 4);
        longPress(view, Started, start, start);
        longPress(view, Ended, start, start);
        assertEquals("line", text(view));
        assertTrue(InputTouch.touchSelection(state(view)).isMenuOpen());

        view.update((state, _, cx) -> {
            state.setScrollOffset(new Point(0, -8), cx);
            state.closeEditMenu(cx);
        });
        view.cx.update((window, _) -> window.draw());
        var snapshot = InputTouch.touchSelection(state(view));
        assertNotNull(snapshot, "handles follow the text");
        assertFalse(snapshot.isMenuOpen());
        assertEquals("line", text(view));

        // Scrolled far enough, the selection leaves the viewport: no handle
        // for it, and no menu anchored to nothing.
        view.update((state, _, cx) -> state.setScrollOffset(new Point(0, -600), cx));
        view.cx.update((window, _) -> window.draw());
        snapshot = InputTouch.touchSelection(state(view));
        assertNotNull(snapshot, "the selection is still the touch one");
        assertFalse(snapshot.isEdgeVisible(SelectionEdge.Start));
        assertFalse(snapshot.isEdgeVisible(SelectionEdge.End));
        assertNull(snapshot.bounds());
    }

}
