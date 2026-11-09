// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (tests: cursors, multi-cursor, pairs and indentation)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.ClipboardItem;
import glaze.Context;
import glaze.Modifiers;
import glaze.Point;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.input.BlinkCursor;
import glaze.kit.base.input.CursorSelection;
import glaze.kit.base.input.InputBaseState.ColumnarPoint;
import glaze.Entity;
import glaze.Range;
import glaze.Window;
import glaze.kit.base.NumberStep;
import glaze.kit.base.StepAction;
import glaze.kit.base.input.HighlightStyleResolver;
import glaze.kit.base.input.InputEdit;
import glaze.kit.base.input.InputBaseState.TextEdit;
import glaze.kit.base.input.LspPosition;
import glaze.kit.base.input.StyledRange;
import glaze.kit.base.input.TabSize;
import glaze.kit.base.input.TextElement;
import glaze.kit.base.input.WrappingIndent;
import ropey.Rope;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputKeyBindings;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.MaskPattern;
import glaze.kit.base.input.TextareaState;
import testing.InteractionScript.ScriptView;
import testing.VisualTestContext;
import tests.kit.InputStateTestCase.InputView;

import glaze.Prelude.*;

using glaze.kit.base.input.InputMovement;
using glaze.kit.base.input.InputIndentExt;
using glaze.kit.base.input.MaskPattern.MaskPatternTools;
using glaze.kit.base.NumberStep.NumberStepTools;

/**
 * Tests of the input state (Rust `state.rs`): cursors, multi-cursor editing
 * and indentation.
 */
class InputStateEditingTest extends InputStateTestCase {

    /**
     * Parse a cursor spec into `(text, cursorOffsets)`. Non-empty lines are
     * joined with `\n` plus a trailing `\n`. `|` marks a cursor. Leading
     * whitespace is kept, so a spec can express indentation.
     */
    function parseCursorSpec(input:String):{text:String, cursors:Array<Int>} {
        var fullText = "";
        final cursorOffsets = [];
        final lines = [for (l in input.split("\n")) if (l.length > 0) l];
        for (lineIdx in 0...lines.length) {
            final positions = [];
            var text = "";
            for (ch in new haxe.iterators.StringIteratorUnicode(lines[lineIdx])) {
                if (ch == '|'.code) {
                    positions.push(glaze.util.Utf8.byteLength(text));
                }
                else {
                    text += glaze.util.Utf8.fromCodePoint(ch);
                }
            }
            if (lineIdx > 0) {
                fullText += "\n";
            }
            final lineStart = glaze.util.Utf8.byteLength(fullText);
            for (pos in positions) {
                cursorOffsets.push(lineStart + pos);
            }
            fullText += text;
        }
        fullText += "\n";
        return {text: fullText, cursors: cursorOffsets};
    }

    /** Build a multi-line input for multi-cursor tests. */
    function multiLine():InputView {
        return buildTextarea();
    }

    /** Set the text and cursor positions from a spec (see `parseCursorSpec`). */
    function setupCursors(view:InputView, spec:String):Void {
        final parsed = parseCursorSpec(spec);
        view.update((state, window, cx) -> {
            state.setValue(parsed.text, window, cx);
            final selections = [for (offset in parsed.cursors) new CursorSelection(state.selections.generateId(), offset, offset)];
            state.selections.replaceAll(selections);
            cx.notify();
        });
    }

    /** Assert the text and cursor positions match a spec. */
    function assertCursors(view:InputView, spec:String, ?pos:haxe.PosInfos):Void {
        final expected = parseCursorSpec(spec);
        final expectedCursors = expected.cursors.copy();
        expectedCursors.sort((a, b) -> a - b);

        final state = view.state();
        final actualCursors = [for (s in state.selections.iter()) s.cursorOffset()];
        actualCursors.sort((a, b) -> a - b);

        assertEquals(expected.text, state.text.toString(), "Text mismatch", pos);
        assertEquals(expectedCursors.join(","), actualCursors.join(","), "Cursor mismatch", pos);
    }

    function rangesOf(state:InputBaseState):String {
        return [for (sel in state.selections.iter()) sel.start + ".." + sel.end].join(",");
    }

    /** The point of a column of a laid-out row (Rust `origin + point(x, line_height * (row + 0.5))` once the gutter is gone). */
    function positionAt(state:InputBaseState, row:Int, col:Int):Point {
        final layout = state.lastLayout;
        final origin = state.lastBounds.origin;
        final local = layout.lines[row].positionForIndex(col, layout, false);
        return origin.add(new Point(local.x, layout.lineHeight * (row + 0.5)));
    }

    function testAltDragSelectsABlockAndReplacesEachRow() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final view = buildTextarea();
        for (modifiers in [Modifiers.of(false, true), Modifiers.of(false, true, true)]) {
            setupCursors(view, "|abcd\nabcd\nabcd");
            view.update((state, window, cx) -> state.focus(window, cx));
            view.cx.runUntilParked();
            final start = positionAt(view.state(), 0, 1);
            var end = positionAt(view.state(), 2, 3);
            // Land inside the third column instead of exactly on its trailing
            // glyph boundary, where pixel rounding can select the next column.
            end = new Point(end.x - 0.5, end.y);
            view.cx.simulateMouseDown(start, Left, modifiers);
            view.cx.simulateMouseMove(end, Left, modifiers);
            view.cx.simulateMouseUp(end, Left, modifiers);
            assertEquals("1..3,6..8,11..13", rangesOf(view.state()));
            // Moving after release must leave the block intact.
            view.cx.simulateMouseMove(start, null, modifiers);
            view.cx.simulateKeystrokes("x");
            assertCursors(view, "ax|d\nax|d\nax|d");
        }
    }

    function testAltDragExtendsUpwardFromAnExistingCursor() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final view = buildTextarea();
        setupCursors(view, "abcd\nabcd\na|bcd");
        view.update((state, window, cx) -> state.focus(window, cx));
        view.cx.runUntilParked();
        final state = view.state();
        final layout = state.lastLayout;
        final origin = state.lastBounds.origin;
        final x = layout.lines[0].positionForIndex(1, layout, false).x;
        final start = origin.add(new Point(x, layout.lineHeight * 2.5));
        final end = origin.add(new Point(x, layout.lineHeight * 0.5));
        final modifiers = Modifiers.of(false, true);
        view.cx.simulateMouseDown(start, Left, modifiers);
        view.cx.simulateMouseMove(end, Left, modifiers);
        view.cx.simulateMouseUp(end, Left, modifiers);
        assertCursors(view, "a|bcd\na|bcd\na|bcd");
    }

    function testAltDragOverAShortRowKeepsTheBlockWidth() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final view = buildTextarea();
        setupCursors(view, "abcdef\nab\nabcdef");
        view.update((state, window, cx) -> state.focus(window, cx));
        view.cx.runUntilParked();
        // Drag from row 0 column 1 down to row 1, at the x of row 0's column 5. Row 1
        // only has two characters, so the pointer ends past its end.
        final state = view.state();
        final layout = state.lastLayout;
        final origin = state.lastBounds.origin;
        final xOf = (index:Int) -> layout.lines[0].positionForIndex(index, layout, false).x;
        final start = origin.add(new Point(xOf(1), layout.lineHeight * 0.5));
        final end = origin.add(new Point(xOf(5), layout.lineHeight * 1.5));
        final modifiers = Modifiers.of(false, true, true);
        view.cx.simulateMouseDown(start, Left, modifiers);
        view.cx.simulateMouseMove(end, Left, modifiers);
        view.cx.simulateMouseUp(end, Left, modifiers);

        // The short row is clipped to its own end; the long row keeps the full span.
        // Rust expects "1..5,8..9": the columns past the short row's end are
        // counted in space widths, so the span depends on the font. With the
        // port's font the pointer reaches the column computed the same way.
        final pastEnd:Float = ((end.x : Float) - (origin.x : Float)) - (layout.lines[1].wrappedLines[0].width : Float);
        final column = 2 + Std.int(glaze.util.MathUtil.round(pastEnd / (layout.spaceWidth : Float)));
        final blockEnd = column < 6 ? column : 6;
        assertEquals('1..$blockEnd,8..9', rangesOf(view.state()));
    }

    function testAltMouseReleaseOutsideEditorEndsColumnSelection() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final view = buildTextarea();
        setupCursors(view, "|abcd\nabcd");
        view.cx.runUntilParked();
        final state = view.state();
        final layout = state.lastLayout;
        final position = state.lastBounds.origin.add(new Point(2., layout.lineHeight * 0.5));
        final modifiers = Modifiers.of(false, true);
        view.cx.simulateMouseDown(position, Left, modifiers);
        view.cx.simulateMouseUp(new Point(-100., -100.), Left, modifiers);
        assertFalse(view.state().selecting);
        assertNull(view.state().columnSelectStart);
    }

    function testConsumedKeystrokesKeepCursorVisible() {
        final view = buildTextarea();
        setupCursors(view, "a|b");
        view.update((state, window, cx) -> {
            state.focus(window, cx);
            state.pauseBlinkCursor(cx);
        });
        view.cx.runUntilParked();
        view.cx.advanceClock(0.3);
        view.cx.runUntilParked();
        assertFalse(view.state().blinkCursor.read(app).visible());
        // Copy consumes its shortcut without editing text or moving selections.
        for (_ in 0...5) {
            view.cx.simulateKeystrokes("cmd-c");
            view.cx.runUntilParked();
            view.cx.advanceClock(0.2);
            view.cx.runUntilParked();
            assertTrue(view.state().blinkCursor.read(app).visible());
        }
    }

    function testMouseDownShowsCursorLikeACursorMove() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final view = buildTextarea();
        setupCursors(view, "abcd|efgh");
        view.cx.runUntilParked();
        final position = (offset:Float) -> {
            final state = view.state();
            final layout = state.lastLayout;
            return state.lastBounds.origin.add(new Point(offset, layout.lineHeight * 0.5));
        };
        final visible = () -> view.state().blinkCursor.read(app).visible();

        // The press itself shows the caret, without waiting for the focus
        // observer, and the idle delay holds it there like a cursor move.
        final first = position(2.);
        view.cx.simulateMouseDown(first, Left);
        assertTrue(visible());
        view.cx.simulateMouseUp(first, Left);
        view.cx.runUntilParked();

        // Pressing elsewhere in the focused input, in the hidden phase of the
        // blink, shows the caret again at the press.
        view.cx.advanceClock(0.4);
        view.cx.runUntilParked();
        assertFalse(visible());
        final second = position(30.);
        view.cx.simulateMouseDown(second, Left);
        assertTrue(visible());
        view.cx.advanceClock(0.25);
        view.cx.runUntilParked();
        assertTrue(visible());
        view.cx.simulateMouseUp(second, Left);
    }

    function testMultiCursorActionsRevealHiddenCarets() {
        final view = buildTextarea();
        setupCursors(view, "ab\na|b\nab");
        // Start each action in the hidden phase without depending on a
        // key-down listener: actions and text input also arrive directly.
        for (action in 0...6) {
            view.update((state, _, cx) -> {
                state.blinkCursor = cx.newEntity(cx -> new BlinkCursor(cx));
                state.blinkCursor.update(cx, (cursor, cx) -> cursor.start(cx));
            });
            view.cx.runUntilParked();
            view.cx.advanceClock(0.5);
            view.cx.runUntilParked();
            assertFalse(view.state().blinkCursor.read(app).visible(), 'action $action');

            view.update((state, window, cx) -> {
                switch action {
                    case 0: state.addCursorAbove(new AddCursorAbove(), window, cx);
                    case 1: state.addCursorBelow(new AddCursorBelow(), window, cx);
                    case 2: state.selectUp(new SelectUp(), window, cx);
                    case 3: state.selectDown(new SelectDown(), window, cx);
                    case 4: state.replaceTextInRange(null, "x", window, cx);
                    case _: state.backspace(new Backspace(), window, cx);
                }
                assertTrue(state.blinkCursor.read(cx.app).visible(), 'action $action');
            });
        }
    }

    function testMultiCursorKeyboardDispatch() {
        final view = buildTextarea();
        setupCursors(view, "ab\na|b\nab");
        view.update((state, window, cx) -> state.focus(window, cx));
        view.cx.simulateKeystrokes("cmd-alt-up");
        assertEquals(2, view.state().selections.len());
        view.cx.simulateKeystrokes("cmd-alt-down");
        assertEquals(3, view.state().selections.len());
        view.cx.simulateKeystrokes("x");
        assertCursors(view, "ax|b\nax|b\nax|b");
    }

    function testMultiCursorPlatformWordSelectionDispatch() {
        final view = buildTextarea();
        setupCursors(view, "one |two\none |two");
        view.update((state, window, cx) -> state.focus(window, cx));
        view.cx.simulateKeystrokes("alt-shift-right");
        view.cx.simulateKeystrokes("x");
        assertCursors(view, "one x|\none x|");
        setupCursors(view, "one two|\none two|");
        view.cx.simulateKeystrokes("alt-shift-left");
        view.cx.simulateKeystrokes("x");
        assertCursors(view, "one x|\none x|");
    }

    function testMultiCursorAltClickDispatch() {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        final view = buildTextarea();
        setupCursors(view, "a|b\nab\nab");
        view.update((state, window, cx) -> state.focus(window, cx));
        view.cx.runUntilParked();
        final state = view.state();
        final layout = state.lastLayout;
        final position = state.lastBounds.origin.add(new Point(2., layout.lineHeight * 1.5));
        view.cx.simulateClick(position, Modifiers.of(false, true));
        assertEquals(2, view.state().selections.len());
    }

    function testAddSelection() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.focus(window, cx);
            state.setValue("foo bar foo", window, cx);
            state.setSelectedRange(range(0, 3), cx);
            // The programmatic second cursor: the next occurrence.
            state.addSelection(range(8, 11), cx);
            // Adding a range that is already selected changes nothing.
            state.addSelection(range(0, 3), cx);
        });
        final ranges = [for (s in view.state().selections.iter()) s.toRange()];
        ranges.sort((a, b) -> a.start - b.start);
        assertEquals("0..3,8..11", [for (r in ranges) r.start + ".." + r.end].join(","));
        // Typing replaces every selection at once.
        view.cx.simulateKeystrokes("x");
        assertEquals("x bar x", view.state().text.toString());
    }

    function testAddSelectionPreservesCrlfBoundaries() {
        final view = buildTextarea(state -> state.defaultValue("a\r\nb"));
        view.update((state, window, cx) -> {
            state.focus(window, cx);
            state.setSelectedRange(range(4, 4), cx);
            state.addSelection(range(2, 2), cx);
            assertEquals("4..4,1..1", rangesOf(state));
        });
        view.cx.simulateKeystrokes("x");
        assertEquals("ax\r\nbx", view.state().value());
        view.update((state, window, cx) -> {
            state.setValue("a\r\nb", window, cx);
            state.setSelectedRange(range(4, 4), cx);
            state.addSelection(range(2, 3), cx);
            state.cut(new Cut(), window, cx);
            assertEquals("\r\n", cx.readFromClipboard().text());
            assertEquals("ab", state.value());
        });
    }

    function testAddSelectionMergesOverlapsBeforeCopyAndCut() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            // Cover partial overlaps, a containing range, and a bridge
            // between two previously disjoint selections.
            for (additions in [[range(2, 5)], [range(0, 5)], [range(4, 5), range(2, 4)]]) {
                state.setValue("abcdef", window, cx);
                state.setSelectedRange(range(0, 3), cx);
                final activeId = state.activeSelection().id;
                for (r in additions) {
                    state.addSelection(r, cx);
                }
                assertTrue(state.activeSelection().id == activeId);
                assertRange(0, 5, state.selectedRange());
                assertEquals(1, state.selections.len());
                state.copy(new Copy(), window, cx);
                assertEquals("abcde", cx.readFromClipboard().text());
                state.cut(new Cut(), window, cx);
                assertEquals("abcde", cx.readFromClipboard().text());
                assertEquals("f", state.value());
                state.undo(new Undo(), window, cx);
                assertEquals("abcdef", state.value());
                assertRange(0, 5, state.selectedRange());
            }
        });
    }

    function testWordDeleteUndoRestoresCaret() {
        final view = multiLine();
        setupCursors(view, "hello|");
        view.update((state, window, cx) -> {
            state.deletePreviousWord(new DeleteToPreviousWordStart(), window, cx);
            state.undo(new Undo(), window, cx);
            assertRange(5, 5, state.selectedRange());
        });
    }

    function testMergedDeleteUndoRestoresAllCarets() {
        final view = multiLine();
        setupCursors(view, "a|b|c");
        view.update((state, window, cx) -> {
            state.backspace(new Backspace(), window, cx);
            state.undo(new Undo(), window, cx);
        });
        assertCursors(view, "a|b|c");
    }

    function testShiftEndRespectsSoftWrapEnd() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.setValue([for (_ in 0...30) "abcdef "].join(""), window, cx);
            state.displayMap.onLayoutChanged(60., cx.app);
            final line = state.displayMap.line(0);
            assertTrue(line.wrappedLines.length > 1);
            final boundary = line.wrappedLines[0].end;
            state.moveToWithAffinity(boundary, null, true, cx);
            state.selectToEndOfLine(new SelectToEndOfLine(), window, cx);
            assertRange(boundary, state.text.len(), state.selectedRange());
        });
    }

    function testOutdentUnindentedUnicodeIsUnchanged() {
        final view = multiLine();
        setupCursors(view, "|你好\n|世界");
        view.update((state, window, cx) -> {
            state.outdent(false, window, cx);
            state.outdent(true, window, cx);
        });
        assertCursors(view, "|你好\n|世界");
    }

    function testColumnSelectionStaysOnUnicodeBoundaries() {
        final view = multiLine();
        setupCursors(view, "ab\n你好\ncd");
        view.update((state, window, cx) -> {
            state.buildColumnarSelection(new ColumnarPoint(1, 0), new ColumnarPoint(11, 0), cx);
            for (sel in state.selections.iter()) {
                assertTrue(state.text.isCharBoundary(sel.start));
                assertTrue(state.text.isCharBoundary(sel.end));
            }
            state.replaceTextInRange(null, "X", window, cx);
        });
    }


    function testBlockIndentTracksAllPrecedingEdits() {
        final view = multiLine();
        setupCursors(view, "|ab\n|cd\n|ef");
        view.update((state, window, cx) -> state.indent(true, window, cx));
        assertCursors(view, "  |ab\n  |cd\n  |ef");
        view.update((state, window, cx) -> state.outdent(true, window, cx));
        assertCursors(view, "|ab\n|cd\n|ef");
    }

    function testBlockOutdentClampsCursorInsideIndent() {
        final view = multiLine();
        setupCursors(view, "ab\n | cd");
        view.update((state, window, cx) -> state.outdent(true, window, cx));
        assertCursors(view, "ab\n|cd");
    }

    function testImeRestoresOriginalSelection() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("abc", window, cx);
            state.setSelectedRange(range(1, 2), cx);
            state.replaceAndMarkTextInRange(null, "ni", null, window, cx);
            state.replaceTextInRange(null, "你", window, cx);
            state.undo(new Undo(), window, cx);
            assertEquals("abc", state.value());
            assertRange(1, 2, state.selectedRange());
            state.redo(new Redo(), window, cx);
            assertRange(4, 4, state.selectedRange());
        });
    }

    function testNoopDoesNotChangeRedoSelection() {
        final view = multiLine();
        view.update((state, window, cx) -> {
            state.setValue("abc", window, cx);
            state.setSelectedRange(range(1, 1), cx);
            state.replaceTextInRange(null, "X", window, cx);
            state.setSelectedRange(range(0, 0), cx);
            state.replaceTextInRange(null, "", window, cx);
            state.undo(new Undo(), window, cx);
            state.redo(new Redo(), window, cx);
            assertEquals("aXbc", state.value());
            assertRange(2, 2, state.selectedRange());
        });
    }

    function testMultiCursorInsertText() {
        final view = multiLine();
        setupCursors(view, "|hello |world|");
        view.update((state, window, cx) -> state.replaceTextInRange(null, ">>>", window, cx));
        assertCursors(view, ">>>|hello >>>|world>>>|");
    }

    function testMultiCursorDeleteBackward() {
        final view = multiLine();
        setupCursors(view, "|islands| cars|");
        view.update((state, window, cx) -> state.backspace(new Backspace(), window, cx));
        // The first cursor has nothing to delete. The others delete an `s`.
        assertCursors(view, "|island| car|");
    }

    function testMultiCursorDeleteForwardMerges() {
        final view = multiLine();
        setupCursors(view, "hello| |world");
        view.update((state, window, cx) -> state.delete(new Delete(), window, cx));
        // Adjacent deletions merge into a single cursor.
        assertCursors(view, "hello|orld");
    }

    function testMultiCursorMultilineInsertAndDelete() {
        final view = multiLine();
        setupCursors(view, "|1\n|2\n|3");
        view.update((state, window, cx) -> state.replaceTextInRange(null, "a", window, cx));
        assertCursors(view, "a|1\na|2\na|3");

        // The whole multi-edit insert is a single undo transaction.
        assertEquals(1, @:privateAccess view.state().undoManager.undoCount());

        view.update((state, window, cx) -> state.backspace(new Backspace(), window, cx));
        assertCursors(view, "|1\n|2\n|3");
    }

    function testAddCursorBelowPreservesColumn() {
        final view = multiLine();
        setupCursors(view, "ab|cd\nabcd");
        view.update((state, window, cx) -> state.addCursorBelow(new AddCursorBelow(), window, cx));
        assertCursors(view, "ab|cd\nab|cd");
    }

    function testAddCursorAtRejectsDuplicates() {
        final view = multiLine();
        setupCursors(view, "he|llo");
        view.update((state, _, cx) -> {
            // Duplicate of the existing cursor is rejected.
            state.addCursorAt(2, cx);
            assertEquals(1, state.selections.len());
            // A distinct offset adds a cursor.
            state.addCursorAt(4, cx);
            assertEquals(2, state.selections.len());
        });
    }

    function testMultiCursorUndoRedoRestoresSelections() {
        final view = multiLine();
        setupCursors(view, "|1\n|2\n|3");
        view.update((state, window, cx) -> state.replaceTextInRange(null, "a", window, cx));
        assertCursors(view, "a|1\na|2\na|3");
        view.update((state, window, cx) -> state.undo(new Undo(), window, cx));
        assertCursors(view, "|1\n|2\n|3");
        view.update((state, window, cx) -> state.redo(new Redo(), window, cx));
        assertCursors(view, "a|1\na|2\na|3");
    }

    function testMultiCursorUndoRedoDifferentLineLengths() {
        final view = multiLine();
        setupCursors(view, "abc123|\nabc12345|\nabc1234567|");
        view.update((state, window, cx) -> state.replaceTextInRange(null, "a", window, cx));
        assertCursors(view, "abc123a|\nabc12345a|\nabc1234567a|");
        view.update((state, window, cx) -> state.undo(new Undo(), window, cx));
        assertCursors(view, "abc123|\nabc12345|\nabc1234567|");
        view.update((state, window, cx) -> state.redo(new Redo(), window, cx));
        assertCursors(view, "abc123a|\nabc12345a|\nabc1234567a|");
    }

    function testMultiCursorUndoMultipleInserts() {
        final view = multiLine();
        setupCursors(view, "|1\n|2\n|3");
        for (ch in ["a", "b", "c"]) {
            view.update((state, window, cx) -> state.replaceTextInRange(null, ch, window, cx));
        }
        assertCursors(view, "abc|1\nabc|2\nabc|3");

        // The repeated keystrokes form one typing gesture.
        view.update((state, window, cx) -> {
            assertEquals(1, @:privateAccess state.undoManager.undoCount());
            state.undo(new Undo(), window, cx);
        });
        assertCursors(view, "|1\n|2\n|3");

        view.update((state, window, cx) -> state.redo(new Redo(), window, cx));
        assertCursors(view, "abc|1\nabc|2\nabc|3");
    }

    function testMultiCursorBackspaceRunIsOneUndo() {
        final view = multiLine();
        setupCursors(view, "abc|1\nabc|2\nabc|3");
        for (_ in 0...3) {
            view.update((state, window, cx) -> state.backspace(new Backspace(), window, cx));
        }
        assertCursors(view, "|1\n|2\n|3");

        view.update((state, window, cx) -> {
            assertEquals(1, @:privateAccess state.undoManager.undoCount());
            state.undo(new Undo(), window, cx);
        });
        assertCursors(view, "abc|1\nabc|2\nabc|3");
    }

    function testAddingACursorSplitsTheTypingGesture() {
        final view = multiLine();
        setupCursors(view, "|1\n2\n3");
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.addCursorBelow(new AddCursorBelow(), window, cx);
            state.replaceTextInRange(null, "b", window, cx);
        });
        assertCursors(view, "ab|1\n2b|\n3");

        // The keystroke after the cursor was added is its own undo entry.
        view.update((state, window, cx) -> state.undo(new Undo(), window, cx));
        assertCursors(view, "a|1\n2|\n3");
    }

    function testMultiCursorIndentIsOneUndo() {
        final view = multiLine();
        setupCursors(view, "|1\n|2\n|3");
        view.update((state, window, cx) -> {
            state.indentInline(new IndentInline(), window, cx);
            assertEquals(1, @:privateAccess state.undoManager.undoCount());
            state.undo(new Undo(), window, cx);
        });
        assertCursors(view, "|1\n|2\n|3");
    }

    function testMultiCursorIndentThenOutdentRoundtrips() {
        final view = multiLine();
        // Cursors at line starts.
        setupCursors(view, "|1\n|2\n|3");
        view.update((state, window, cx) -> state.indent(false, window, cx));
        assertCursors(view, "  |1\n  |2\n  |3");
        view.update((state, window, cx) -> state.outdent(false, window, cx));
        assertCursors(view, "|1\n|2\n|3");
    }

    function testInlineOutdentOnlyRemovesLineIndentation() {
        final view = multiLine();
        // A mid-line indent lands at the cursor, and the outdent does not
        // take it back: it only ever removes leading line indentation.
        setupCursors(view, "1|2\n1|2");
        view.update((state, window, cx) -> state.indent(false, window, cx));
        assertCursors(view, "1  |2\n1  |2");
        view.update((state, window, cx) -> state.outdent(false, window, cx));
        assertCursors(view, "1  |2\n1  |2");

        // A line with leading indentation loses that, wherever the cursor is.
        setupCursors(view, "  1|2\n  1|2");
        view.update((state, window, cx) -> state.outdent(false, window, cx));
        assertCursors(view, "1|2\n1|2");
    }

    function testReadonlyMultiCursorCommandsLeaveStateUnchanged() {
        final view = multiLine();
        setupCursors(view, "a|b\nc|d");
        view.update((state, window, cx) -> {
            final before = CursorSelection.copyAll(state.selections.iter());
            state.setReadonly(true, cx);
            state.backspace(new Backspace(), window, cx);
            state.indentInline(new IndentInline(), window, cx);

            assertEquals("ab\ncd\n", state.value());
            final after = state.selections.iter();
            assertEquals(before.length, after.length);
            for (i in 0...before.length) {
                assertTrue(before[i].equals(after[i]));
            }
        });
    }

    function testMultiCursorEditPreservesTheActiveCursor() {
        final view = multiLine();
        setupCursors(view, "x|\n|y");
        view.update((state, window, cx) -> {
            final selections = CursorSelection.copyAll(state.selections.iter());
            final first = selections[0];
            selections[0] = selections[1];
            selections[1] = first;
            state.selections.replaceAll(selections);
            final activeId = state.activeSelection().id;
            state.replaceTextInRange(null, "!", window, cx);
            assertTrue(state.activeSelection().id == activeId);
        });
    }

    function testBlockIndentOutdentWithSelection() {
        final view = multiLine();
        view.update((state, window, cx) -> {
            state.setValue("line1\nline2\nline3", window, cx);
            final id = state.selections.generateId();
            state.selections.replaceAll([new CursorSelection(id, 0, 17)]);
            cx.notify();
        });
        view.update((state, window, cx) -> state.indent(true, window, cx));
        assertEquals("  line1\n  line2\n  line3", view.state().text.toString());
        view.update((state, window, cx) -> state.outdent(true, window, cx));
        assertEquals("line1\nline2\nline3", view.state().text.toString());
    }

    function testMultiCursorWordMovement() {
        final view = multiLine();
        setupCursors(view, "on|e two three\none t|wo three\non|e two three");
        view.update((state, window, cx) -> state.moveToNextWord(new MoveToNextWord(), window, cx));
        assertCursors(view, "one| two three\none two| three\none| two three");

        view.update((state, window, cx) -> state.moveToPreviousWord(new MoveToPreviousWord(), window, cx));
        assertCursors(view, "|one two three\none |two three\n|one two three");

        // Move to end/start of document collapses to a single cursor.
        view.update((state, window, cx) -> state.moveToEnd(new MoveToEnd(), window, cx));
        assertEquals(Std.string(view.state().text.len()), [for (s in view.state().selections.iter()) s.cursorOffset()].join(","));

        view.update((state, window, cx) -> state.moveToStart(new MoveToStart(), window, cx));
        assertEquals("0", [for (s in view.state().selections.iter()) s.cursorOffset()].join(","));
    }

    function testMultiCursorSelectionCommands() {
        final view = multiLine();
        setupCursors(view, "on|e two three\none t|wo three\non|e two three");
        view.update((state, window, cx) -> state.selectToStartOfLine(new SelectToStartOfLine(), window, cx));
        assertCursors(view, "|one two three\n|one two three\n|one two three");

        // Select to document start collapses to the active cursor only.
        setupCursors(view, "on|e two three\none t|wo three\non|e two three");
        view.update((state, window, cx) -> state.selectToStart(new SelectToStart(), window, cx));
        assertEquals("0", [for (s in view.state().selections.iter()) s.cursorOffset()].join(","));
    }

    function testMultiCursorReplaceSelection() {
        final view = multiLine();
        setupCursors(view, "|a\n|b\n|c");
        view.update((state, window, cx) -> state.selectRight(new glaze.kit.base.Actions.SelectRight(), window, cx));
        assertEquals("0..1,2..3,4..5", rangesOf(view.state()));

        view.update((state, window, cx) -> state.replaceTextInRange(null, "x", window, cx));
        assertCursors(view, "x|\nx|\nx|");
    }

    function testMultiCursorEscapeCollapses() {
        final view = multiLine();
        setupCursors(view, "|a\n|b\n|c");
        view.update((state, window, cx) -> state.escape(new Escape(), window, cx));
        assertEquals(1, view.state().selections.len());
    }

    function testBuildColumnarSelection() {
        final view = multiLine();
        setupCursors(view, "abcd\nabcd\nabcd");
        view.update((state, _, cx) -> {
            // From row 0 col 1 to row 2 col 3.
            state.buildColumnarSelection(new ColumnarPoint(1, 0), new ColumnarPoint(13, 0), cx);
            assertEquals("1..3,6..8,11..13", rangesOf(state));
        });
    }

    function testColumnarSelectionKeepsWidthOverShortRows() {
        final view = multiLine();
        setupCursors(view, "abcdef\nab\nabcdef");
        view.update((state, _, cx) -> {
            // Ends on the short row, 3 columns past its end: the block still spans
            // columns 1..5, and only that row is clipped to what it has.
            state.buildColumnarSelection(new ColumnarPoint(1, 0), new ColumnarPoint(9, 3), cx);
            assertEquals("1..5,8..9", rangesOf(state));
        });
    }

    function testMultiCursorPasteDistributesLines() {
        final view = multiLine();
        setupCursors(view, "|1\n|2\n|3");
        view.cx.update((_, cx) -> cx.writeToClipboard(ClipboardItem.newString("x\ny\nz")));
        view.update((state, window, cx) -> state.pasteAction(new Paste(), window, cx));
        // One clipboard line per cursor.
        assertCursors(view, "x|1\ny|2\nz|3");
    }

    function testPasteWithoutTextLeavesTheSelectionAlone() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("hello world", window, cx);
            state.selectAll(window, cx);
            final bytes = haxe.io.Bytes.alloc(4);
            bytes.set(0, 0x89);
            bytes.set(1, 'P'.code);
            bytes.set(2, 'N'.code);
            bytes.set(3, 'G'.code);
            cx.writeToClipboard(ClipboardItem.newImage(glaze.Image.fromBytes(Png, bytes)));

            // An image-only clipboard must not replace the selection with nothing.
            state.pasteAction(new Paste(), window, cx);
            assertEquals("hello world", state.value());
            assertRange(0, 11, state.selectedRange());
        });
    }

    function testPasteTargetTracksEditsAndSelections() {
        final view = multiLine();
        setupCursors(view, "ab|c");
        final target = @:privateAccess view.state().pasteTarget();
        // Nothing happened: a paste asked for then still applies.
        assertTrue(@:privateAccess view.state().pasteTarget().equals(target));

        // Moving the caret changes where the paste would go.
        view.update((state, _, cx) -> {
            final id = state.selections.generateId();
            state.selections.replaceAll([new CursorSelection(id, 1, 1)]);
            cx.notify();
        });
        final moved = @:privateAccess view.state().pasteTarget();
        assertFalse(moved.equals(target));

        // Editing the text changes it too, even with the caret put back.
        view.update((state, window, cx) -> {
            state.replaceTextInRangeSilent(null, "x", window, cx);
            final id = state.selections.generateId();
            state.selections.replaceAll([new CursorSelection(id, 1, 1)]);
        });
        assertFalse(@:privateAccess view.state().pasteTarget().equals(moved));
    }

    function testImeCandidateBoundsFallbackBeforeRepaint() {
        final view = buildTextarea(state -> state.defaultValue("这是一段已经输入的中文文字"));
        view.cx.update((window, _) -> window.draw());

        view.update((state, window, cx) -> {
            state.focus(window, cx);
            final len = state.text.len();
            state.setCursorTo(len);
        });
        view.cx.update((window, _) -> window.draw());

        view.update((state, window, cx) -> {
            final bounds = state.textBounds() != null ? state.textBounds() : new glaze.Bounds();
            final before = state.selectedTextRange(false, window, cx).range;
            final previous = state.boundsForRange(range(before.end, before.end), bounds, window, cx);

            state.replaceAndMarkTextInRange(null, "n", null, window, cx);

            final after = state.selectedTextRange(false, window, cx).range;
            final pending = state.boundsForRange(range(after.end, after.end), bounds, window, cx);

            assertTrue(Math.abs(pending.origin.x - previous.origin.x) < 40.0,
                'pending origin.x ${pending.origin.x} must remain close to previous origin.x ${previous.origin.x}');

            final rangeBounds = state.boundsForRange(range(before.end, after.end), bounds, window, cx);
            assertTrue(Math.abs(rangeBounds.origin.x - previous.origin.x) < 40.0,
                'range_bounds origin.x ${rangeBounds.origin.x} must remain close to previous origin.x ${previous.origin.x}');
            assertTrue(rangeBounds.size.width >= 0.0);
        });
    }

}
