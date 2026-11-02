// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.ClipboardItem;
import gpui.Context;
import gpui.Entity;
import gpui.Range;
import gpui.Window;
import gpui.base.NumberStep;
import gpui.base.StepAction;
import gpui.base.input.EditorState;
import gpui.base.input.EditedText;
import gpui.base.input.FoldRange;
import gpui.base.input.HighlightStyleResolver;
import gpui.base.input.InputEdit;
import gpui.base.input.InputHighlighter.InputHighlighterBase;
import gpui.base.input.InputBaseState.TextEdit;
import gpui.base.input.LspHover;
import gpui.base.input.LspPosition;
import gpui.base.input.StyledRange;
import gpui.base.input.TabSize;
import gpui.base.input.TextDecoration;
import gpui.base.input.TextElement;
import gpui.base.input.WrappingIndent;
import ropey.Rope;
import gpui.base.input.InputActions;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEvent;
import gpui.base.input.InputKeyBindings;
import gpui.base.input.InputState;
import gpui.base.input.MaskPattern;
import gpui.base.input.TextareaState;
import testing.InteractionScript.ScriptView;
import testing.VisualTestContext;
import tests.kit.InputStateTestCase.InputView;

import gpui.Prelude.*;

using gpui.base.input.InputMovement;
using gpui.base.input.InputDecorationsExt;
using gpui.base.input.InputLspExt;
using gpui.base.input.MaskPattern.MaskPatternTools;
using gpui.base.NumberStep.NumberStepTools;

/**
 * Tests of the input state (Rust `state.rs`).
 */
class InputStateTest extends InputStateTestCase {

    // Number steps and masks

    function testNumberStep() {
        final view = build();
        view.update((_, _, cx) -> {
            assertEquals(5., (Fixed(5.) : NumberStep).value(123., Increment, cx.app));

            // The step can differ by direction at a boundary: at 1.0 it
            // is 0.1 going down and 0.5 going up.
            final step = NumberStepTools.byValue((value, action, _) -> {
                final below = switch action {
                    case Increment: value < 1.0;
                    case Decrement: value <= 1.0;
                };
                return below ? 0.1 : 0.5;
            });
            assertEquals(0.1, step.value(0.5, Increment, cx.app));
            assertEquals(0.5, step.value(1.0, Increment, cx.app));
            assertEquals(0.1, step.value(1.0, Decrement, cx.app));
            assertEquals(0.5, step.value(2.0, Decrement, cx.app));
        });
    }

    function testNumberInputNormalization() {
        final view = build(state -> state.withMaskPattern(Number(null, null)));

        // Full-width digits and the ideographic full stop are normalized,
        // and the cursor is at the end (in normalized bytes, not the
        // original 12 bytes).
        view.update((state, window, cx) -> state.replaceTextInRange(null, "12。5", window, cx));
        view.cx.runUntilParked();
        assertEquals("12.5", view.state().value());
        assertRange(4, 4, view.state().selectedRange());

        // Non-numeric input is rejected.
        view.update((state, window, cx) -> state.replaceTextInRange(null, "abc", window, cx));
        view.cx.runUntilParked();
        assertEquals("12.5", view.state().value());

        // A bare leading dot is kept as-is (normalized from the ideographic
        // full stop), not completed to "0.", so it stays editable.
        view.update((state, window, cx) -> {
            final range = state.rangeToUtf16(range(0, state.text.len()));
            state.replaceTextInRange(range, "。", window, cx);
        });
        view.cx.runUntilParked();
        assertEquals(".", view.state().value());
        assertRange(1, 1, view.state().selectedRange());
    }

    function testMaskPatternAcceptsNonAsciiText() {
        final view = build(state -> state.withMaskPattern("9999年99月"));
        view.update((state, window, cx) -> state.replaceTextInRange(null, "2024年12月", window, cx));
        view.cx.runUntilParked();
        assertEquals("2024年12月", view.state().value());
    }

    function testNumberInputNormalizationWithSeparator() {
        final view = build(state -> state.withMaskPattern(Number(','.code, 2)));
        view.update((state, window, cx) -> state.replaceTextInRange(null, "1234", window, cx));
        view.cx.runUntilParked();
        assertEquals("1,234", view.state().value());
        assertEquals("1234", view.state().unmaskValue());
    }

    function testNumberInputClampOnBlur() {
        final view = build(state -> state.withMaskPattern(Number(null, null)).min(10.).max(100.));

        // Out-of-range values are allowed while typing, and clamped on blur.
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "1000", window, cx);
            assertEquals("1000", state.value());
            @:privateAccess state.clampNumberValue(window, cx);
            assertEquals("100", state.value());

            final range = state.rangeToUtf16(range(0, state.text.len()));
            state.replaceTextInRange(range, "1", window, cx);
            assertEquals("1", state.value());
            @:privateAccess state.clampNumberValue(window, cx);
            assertEquals("10", state.value());
        });
    }

    function testNumberInputUndoWithMask() {
        final view = build(state -> state.withMaskPattern(Number(','.code, null)));

        // When the mask changes the text (regrouping separators), a
        // whole-document change is recorded, so undo/redo can restore it.
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "1234", window, cx);
            assertEquals("1,234", state.value());
            state.replaceTextInRange(null, "5", window, cx);
            assertEquals("12,345", state.value());

            // Each whole-document mask rewrite is an atomic undo step.
            state.undo(new Undo(), window, cx);
            assertEquals("1,234", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
            state.redo(new Redo(), window, cx);
            assertEquals("1,234", state.value());
            state.redo(new Redo(), window, cx);
            assertEquals("12,345", state.value());
        });
    }

    // Undo manager

    function testUndoManagerCoalescesAdjacentTypingTransactions() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.replaceTextInRange(null, "b", window, cx);
            assertEquals("ab", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerCursorMovementSplitsTyping() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.replaceTextInRange(null, "b", window, cx);
            state.left(new MoveLeft(), window, cx);
            state.replaceTextInRange(null, "x", window, cx);
            assertEquals("axb", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("ab", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerSplitsBackwardAndForwardDelete() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("abcd", window, cx);
            state.setSelectedRange(range(2, 2), cx);
            state.backspace(new Backspace(), window, cx);
            state.delete(new Delete(), window, cx);
            assertEquals("ad", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("acd", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("abcd", state.value());
        });
    }

    function testUndoManagerCoalescesDirectionalCharacterDeletes() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("abcd", window, cx);
            state.backspace(new Backspace(), window, cx);
            state.backspace(new Backspace(), window, cx);
            assertEquals("ab", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("abcd", state.value());
            assertRange(4, 4, state.selectedRange());

            state.setValue("abcd", window, cx);
            state.setSelectedRange(range(1, 1), cx);
            state.delete(new Delete(), window, cx);
            state.delete(new Delete(), window, cx);
            assertEquals("ad", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("abcd", state.value());
            assertRange(1, 1, state.selectedRange());
        });
    }

    function testUndoManagerAtomicPasteIsolatedFromTyping() {
        final view = build();
        view.update((state, window, cx) -> {
            cx.writeToClipboard(ClipboardItem.newString("P"));
            state.replaceTextInRange(null, "a", window, cx);
            state.pasteAction(new Paste(), window, cx);
            state.replaceTextInRange(null, "b", window, cx);
            assertEquals("aPb", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("aP", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("a", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerProgrammaticInsertIsAtomic() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.insert("P", window, cx);
            state.replaceTextInRange(null, "b", window, cx);
            assertEquals("aPb", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("aP", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("a", state.value());
        });
    }

    function testUndoManagerSelectionRoundTripSplitsTyping() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.replaceTextInRange(null, "b", window, cx);
            state.selectAll(window, cx);
            state.unselect(window, cx);
            state.replaceTextInRange(null, "c", window, cx);

            state.undo(new Undo(), window, cx);
            assertEquals("ab", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerEnterIsAtomic() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.enter(ENTER, window, cx);
            state.replaceTextInRange(null, "b", window, cx);

            state.undo(new Undo(), window, cx);
            assertEquals("a\n", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("a", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerSingleLineReturnCommitsTheTypingSession() {
        final view = build();
        view.update((state, window, cx) -> {
            for (part in ["a", "b", "c"]) {
                state.replaceTextInRange(null, part, window, cx);
            }
            state.enter(ENTER, window, cx);
            for (part in ["d", "e", "f"]) {
                state.replaceTextInRange(null, part, window, cx);
            }
            assertEquals("abcdef", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("abc", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerSubmitOnEnterCommitsTheTextareaSession() {
        final view = buildTextarea(state -> state.withSubmitOnEnter(true));
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "before submit", window, cx);
            state.enter(ENTER, window, cx);
            state.replaceTextInRange(null, " after submit", window, cx);
            assertEquals("before submit after submit", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("before submit", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerBlurCommitsTheTypingSession() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "before blur", window, cx);
            @:privateAccess state.onBlur(window, cx);
            @:privateAccess state.onFocus(window, cx);
            state.replaceTextInRange(null, " after focus", window, cx);
            assertEquals("before blur after focus", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("before blur", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerKeepsRapidLinesInDistinctTransactions() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.enter(ENTER, window, cx);
            state.replaceTextInRange(null, "b", window, cx);
            state.enter(ENTER, window, cx);
            state.replaceTextInRange(null, "c", window, cx);
            assertEquals("a\nb\nc", state.value());

            for (expected in ["a\nb\n", "a\nb", "a\n", "a", ""]) {
                state.undo(new Undo(), window, cx);
                assertEquals(expected, state.value());
            }
        });
    }

    function testUndoManagerCoalescesLongUnicodeTypingWithoutATimer() {
        final view = buildTextarea();
        final parts = ["The ", "quick ", "brown fox, ", "你好，世界 ", "🦀 jumps over 13 lazy dogs."];
        final expected = parts.join("");
        view.update((state, window, cx) -> {
            for (part in parts) {
                state.replaceTextInRange(null, part, window, cx);
            }
            assertEquals(expected, state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
            state.redo(new Redo(), window, cx);
            assertEquals(expected, state.value());
        });
    }


    function testUndoManagerLongMultilineSequenceHasStructuralBoundaries() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            final lines = ["first line with punctuation!", "第二行包含 Unicode 🦀", "third line has several words"];
            for (index in 0...lines.length) {
                for (chunk in splitInclusive(lines[index])) {
                    state.replaceTextInRange(null, chunk, window, cx);
                }
                if (index < 2) {
                    state.enter(ENTER, window, cx);
                }
            }

            assertEquals("first line with punctuation!\n第二行包含 Unicode 🦀\nthird line has several words", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("first line with punctuation!\n第二行包含 Unicode 🦀\n", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("first line with punctuation!\n第二行包含 Unicode 🦀", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("first line with punctuation!\n", state.value());
        });
    }


    function testMaskedInputKeepsItsValueOutOfTheClipboard() {
        final view = build();
        view.update((state, window, cx) -> {
            final input:InputState = cast state;
            state.setValue("hunter2", window, cx);
            input.setMasked(true, window, cx);
            state.selectAll(window, cx);
            cx.writeToClipboard(ClipboardItem.newString("sentinel"));

            state.copy(new Copy(), window, cx);
            assertEquals("sentinel", cx.readFromClipboard().text());

            // Cut neither copies nor deletes.
            state.cut(new Cut(), window, cx);
            assertEquals("hunter2", state.value());
            assertEquals("sentinel", cx.readFromClipboard().text());

            // Revealing the value restores both.
            input.setMasked(false, window, cx);
            state.copy(new Copy(), window, cx);
            assertEquals("hunter2", cx.readFromClipboard().text());
        });
    }

    function testMaskedInputCollapsesWordBoundaries() {
        final view = build();
        view.update((state, window, cx) -> {
            final input:InputState = cast state;
            state.setValue("aaa bbb ccc", window, cx);
            input.setMasked(true, window, cx);
            state.setSelectedRange(range(7, 7), cx);

            // The mask hides word boundaries, so a word delete takes
            // everything before the caret and leaves the rest.
            state.deletePreviousWord(new DeleteToPreviousWordStart(), window, cx);
            assertEquals(" ccc", state.value());
            assertRange(0, 0, state.selectedRange());

            state.deleteNextWord(new DeleteToNextWordEnd(), window, cx);
            assertEquals("", state.value());

            // A double click takes the whole value, not one word.
            state.setValue("aaa bbb ccc", window, cx);
            gpui.base.input.InputWordSelection.selectWord(state, 9, window, cx);
            assertRange(0, 11, state.selectedRange());

            // Unmasked, the same delete only takes one word.
            input.setMasked(false, window, cx);
            state.setValue("aaa bbb ccc", window, cx);
            state.setSelectedRange(range(11, 11), cx);
            state.deletePreviousWord(new DeleteToPreviousWordStart(), window, cx);
            assertEquals("aaa bbb ", state.value());

            state.setValue("aaa bbb ccc", window, cx);
            gpui.base.input.InputWordSelection.selectWord(state, 9, window, cx);
            assertRange(8, 11, state.selectedRange());
        });
    }

    function testMaskedInputDisablesTheCopyContextMenuItems() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("hunter2", window, cx);
            state.selectAll(window, cx);
            assertTrue(state.contextMenuCapabilities().isCopyable());

            (cast state : InputState).setMasked(true, window, cx);
            final capabilities = state.contextMenuCapabilities();
            assertTrue(capabilities.isMasked());
            assertTrue(capabilities.hasSelection());
            assertFalse(capabilities.isCopyable());
        });
    }

    function testUndoManagerCutAndRepeatedPastesAreDistinctTransactions() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "alpha beta gamma", window, cx);
            state.setSelectedRange(range(6, 10), cx);
            state.cut(new Cut(), window, cx);
            assertEquals("alpha  gamma", state.value());

            state.pasteAction(new Paste(), window, cx);
            state.pasteAction(new Paste(), window, cx);
            assertEquals("alpha betabeta gamma", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("alpha beta gamma", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("alpha  gamma", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("alpha beta gamma", state.value());
        });
    }

    function testUndoManagerWordAndLineDeletesDoNotCoalesce() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.setValue("one two three\nfour five", window, cx);
            state.setSelectedRange(range(13, 13), cx);
            state.deletePreviousWord(new DeleteToPreviousWordStart(), window, cx);
            assertEquals("one two \nfour five", state.value());
            state.deleteToEndOfLine(new DeleteToEndOfLine(), window, cx);
            assertEquals("one two four five", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("one two \nfour five", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("one two three\nfour five", state.value());
        });
    }

    function testUndoManagerMultilineReplacementIsOneAtomicTransaction() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "before", window, cx);
            state.setSelectedRange(range(0, 6), cx);
            state.replaceTextInRange(null, "line one\nline two\n第三行", window, cx);
            assertEquals("line one\nline two\n第三行", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("before", state.value());
            assertRange(0, 6, state.selectedRange());
            state.redo(new Redo(), window, cx);
            assertEquals("line one\nline two\n第三行", state.value());
        });
    }

    function testUndoManagerCompositionIsolatedFromLongTyping() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "prefix ", window, cx);
            state.replaceAndMarkTextInRange(null, "n", null, window, cx);
            state.replaceAndMarkTextInRange(null, "ni", null, window, cx);
            state.replaceAndMarkTextInRange(null, "你", null, window, cx);
            state.unmarkText(window, cx);
            state.replaceTextInRange(null, " suffix", window, cx);
            assertEquals("prefix 你 suffix", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("prefix 你", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("prefix ", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerSelectedReplacementIsAtomic() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "abc", window, cx);
            state.setSelectedRange(range(1, 2), cx);
            state.replaceTextInRange(null, "X", window, cx);
            state.replaceTextInRange(null, "z", window, cx);
            assertEquals("aXzc", state.value());

            // Deviation DEV-015: the character typed over the selection starts
            // a typing run, so "Xz" undoes in one step (the original undid "z",
            // then "X"). Declared in reference/deviations/DEV-015.json.
            state.undo(new Undo(), window, cx);
            assertEquals("abc", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testNumberInputLeadingDotEditable() {
        final view = build(state -> state.withMaskPattern(Number(null, null)));
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "1.2", window, cx);

            // Delete the integer part "1": the value keeps the leading dot
            // (".2"), not completed to "0.2", so the digits before the dot
            // stay editable.
            final r = state.rangeToUtf16(range(0, 1));
            state.replaceTextInRange(r, "", window, cx);
            assertEquals(".2", state.value());
            assertRange(0, 0, state.selectedRange());

            // The user can type a new integer part.
            state.replaceTextInRange(range(0, 0), "3", window, cx);
            assertEquals("3.2", state.value());
        });
    }

    function testNumberInputEscapeInvalidText() {
        // A pre-existing invalid text (e.g. a `default_value` that does not
        // conform) must not trap the user, the edit is allowed to fix it.
        //
        // Deliberate deviation DEV-018: the comma is a decimal separator in
        // this mask, so gpui-kit's "1,234" (invalid there) is the valid 1.234
        // here, and the edit gives "1.23" where gpui-kit keeps "1,23". The
        // escape itself is covered with a text invalid on both sides below.
        final view = build(state -> state.withMaskPattern(Number(null, null)).defaultValue("1,234"));
        view.update((state, window, cx) -> {
            state.replaceTextInRange(state.rangeToUtf16(range(4, 5)), "", window, cx);
            assertEquals("1.23", state.value());

            state.replaceTextInRange(state.rangeToUtf16(range(1, 2)), "", window, cx);
            assertEquals("123", state.value());
            state.replaceTextInRange(null, "a", window, cx);
            assertEquals("123", state.value());
        });

        final view = build(state -> state.withMaskPattern(Number(null, null)).defaultValue("1,2,34"));
        view.update((state, window, cx) -> {
            // Delete the last char, the pending text "1,2,3" is still
            // invalid (two decimal separators), but the edit is allowed since
            // the old text was already invalid.
            state.replaceTextInRange(state.rangeToUtf16(range(5, 6)), "", window, cx);
            assertEquals("1.2.3", state.value());

            // Once the text becomes valid, the validation works as usual.
            state.replaceTextInRange(state.rangeToUtf16(range(1, 2)), "", window, cx);
            assertEquals("12.3", state.value());
            state.replaceTextInRange(null, "a", window, cx);
            assertEquals("12.3", state.value());
        });
    }


    /**
     * After `setValue` on a single-line input the caret sits at the end (like
     * HTML `<input>`), yet the view is scrolled back to the start so a long
     * value shows its beginning instead of its tail.
     */
    function testSetValueSingleLineCaretAtEndViewAtStart() {
        final view = build();
        final value = longUrl();
        final len = value.length;

        // Right after `setValue`, before the next paint consumes the deferred
        // offset: caret is at the end, and the view is forced back to the start.
        view.update((state, window, cx) -> {
            state.setValue(value, window, cx);
            assertRange(len, len, state.selectedRange());
            assertTrue(state.deferredScrollOffset != null && state.deferredScrollOffset.x == 0 && state.deferredScrollOffset.y == 0);
        });

        // After a paint, the steady-state view stays at the start (x == 0) even
        // though the caret is at the far end.
        view.cx.runUntilParked();
        final state = view.state();
        assertTrue(state.scrollSize.width > state.inputBounds.size.width, "value must overflow the input width or this test is vacuous");
        assertEquals(0., (state.scrollHandle.offset().x : Float));
    }

    /**
     * `replaceAll` on a single-line input replaces the text, puts the caret
     * at the end, and (like `setValue`) snaps the view back to the start.
     */
    function testReplaceAllSingleLine() {
        final view = build();
        final value = longUrl();
        final len = value.length;

        view.update((state, window, cx) -> {
            state.setValue("hello", window, cx);
            state.replaceAll(value, window, cx);
            assertEquals(value, state.value());
            assertRange(len, len, state.selectedRange());
            assertTrue(state.scrollHandle.offset().equals(new gpui.Point(0, 0)));
            assertTrue(state.deferredScrollOffset != null && state.deferredScrollOffset.equals(new gpui.Point(0, 0)));
        });

        view.cx.runUntilParked();
        final state = view.state();
        assertTrue(state.scrollSize.width > state.inputBounds.size.width, "value must overflow the input width or this test is vacuous");
        assertEquals(0., (state.scrollHandle.offset().x : Float));
    }

    function testSingleLineRemovesNewlines() {
        final view = build(state -> state.defaultValue("default\nvalue"));
        view.update((state, window, cx) -> {
            assertEquals("defaultvalue", state.value());

            state.setValue("first\nsecond\r\nthird\rfourth", window, cx);
            assertEquals("firstsecondthirdfourth", state.value());

            state.setValue("", window, cx);
            state.insert("a\nb", window, cx);
            assertEquals("ab", state.value());

            cx.writeToClipboard(ClipboardItem.newString("a\r\nb\nc\rd"));
            state.setValue("", window, cx);
            state.pasteAction(new Paste(), window, cx);
            assertEquals("abcd", state.value());
        });
        view.cx.runUntilParked();
    }

    /**
     * `replaceAll` on a multi-line (non-code-editor) input clears the
     * selection to `0..0` and resets the scroll offset, but does not set a
     * deferred scroll offset (single-line only).
     */
    function testReplaceAllMultiLine() {
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            state.setValue("foo\nbar", window, cx);
            state.replaceAll("baz\nqux", window, cx);
            assertEquals("baz\nqux", state.value());
            assertRange(0, 0, state.selectedRange());
            assertTrue(state.scrollHandle.offset().equals(new gpui.Point(0, 0)));
            assertNull(state.deferredScrollOffset);
        });
    }

    /**
     * Unlike `setValue`, `replaceAll` records the change so the user can
     * undo it back to the previous text and redo to the new text.
     */
    function testReplaceAllPreservesUndoHistory() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("first", window, cx);
            assertFalse(@:privateAccess state.undoManager.hasUndos(), "history should be empty after set_value");

            state.replaceAll("second", window, cx);
            assertEquals("second", state.value());
            assertTrue(@:privateAccess state.undoManager.hasUndos(), "replace_all should record an undo step");

            state.undo(new Undo(), window, cx);
            assertEquals("first", state.value());

            state.redo(new Redo(), window, cx);
            assertEquals("second", state.value());
        });
    }

    /**
     * `replaceAll` on a code editor marks a pending update and resets LSP
     * state, so diagnostics/completions refresh against the new text.
     */
    function testReplaceAllCodeEditor() {
        final view = buildEditor();
        view.update((state, window, cx) -> {
            state.setValue("select 1", window, cx);
            state._pendingUpdate = false;

            state.replaceAll("select 2", window, cx);
            assertEquals("select 2", state.value());
            assertTrue(state._pendingUpdate, "replace_all on a code editor should request a pending update");
        });
    }

    function testSetSelectedRange() {
        final view = build(state -> state.defaultValue("hello world"));
        view.update((s, _, cx) -> {
            s.setSelectedRange(range(0, 5), cx);
            assertRange(0, 5, s.selectedRange());
            assertEquals("hello", s.selectedText().toString());

            s.setSelectedRange(range(6, 11), cx);
            assertEquals("world", s.selectedText().toString());

            // clamped + collapsed
            s.setSelectedRange(range(100, 100), cx);
            assertRange(11, 11, s.selectedRange());
        });
    }

    /** A single-edit batch round-trips through undo/redo. */
    function testReplaceTextInRangesSingleEdit() {
        final view = buildTextarea(state -> state.defaultValue("hello world"));
        view.update((s, window, cx) -> {
            s.replaceTextInRanges([new TextEdit(range(0, 5), "HELLO")], window, cx);
            assertEquals("HELLO world", s.value());

            s.undo(new Undo(), window, cx);
            assertEquals("hello world", s.value());

            s.redo(new Redo(), window, cx);
            assertEquals("HELLO world", s.value());
        });
    }

    /**
     * A single undo restores the exact original text and a single redo
     * re-applies all edits, verifying the back-to-front application ordering.
     */
    function testReplaceTextInRangesMultiEditTransaction() {
        final view = buildTextarea(state -> state.defaultValue("aaa bbb ccc"));
        view.update((s, window, cx) -> {
            // Two edits at different positions, given in pre-edit
            // coordinates and in arbitrary (non-sorted) order.
            s.replaceTextInRanges([new TextEdit(range(0, 3), "X"), new TextEdit(range(8, 11), "Y")], window, cx);
            assertEquals("X bbb Y", s.value());

            // One collapsed cursor per edit, at the end of each inserted text.
            final cursors = [for (sel in s.selections.iter()) sel.cursorOffset()];
            assertEquals("1,7", cursors.join(","));

            // The whole batch is a single undo transaction.
            assertEquals(1, @:privateAccess s.undoManager.undoCount());

            s.undo(new Undo(), window, cx);
            assertEquals("aaa bbb ccc", s.value());

            s.redo(new Redo(), window, cx);
            assertEquals("X bbb Y", s.value());
        });
    }

    /**
     * A multi-edit change reaches the highlighter once, with every edit in
     * application order and the text right after each.
     */
    function testReplaceTextInRangesDrivesTheHighlighterOnce() {
        final updates:Array<Array<String>> = [];
        final view = buildEditor();
        view.update((s, window, cx) -> {
            s.setValue("aaa bbb ccc", window, cx);
            s.setHighlighterFactory(_ -> new RecordingHighlighter(updates), cx);
            s.replaceTextInRanges([new TextEdit(range(0, 3), "X"), new TextEdit(range(8, 11), "Y")], window, cx);
        });

        assertEquals(1, updates.length);
        assertEquals("aaa bbb Y|X bbb Y", updates[0].join("|"));
    }

    /** An IME composition (marking then commit) undoes as a single unit. */
    function testImeCompositionUndoesAsOneUnit() {
        final view = buildTextarea(state -> state.defaultValue(""));
        view.update((s, window, cx) -> {
            // Simulate an IME composition: mark, refine, then commit.
            s.replaceAndMarkTextInRange(null, "n", range(1, 1), window, cx);
            s.replaceAndMarkTextInRange(null, "ni", range(2, 2), window, cx);
            s.replaceTextInRange(null, "你", window, cx);
            assertEquals("你", s.value());

            // The entire composition is one undo transaction.
            assertEquals(1, @:privateAccess s.undoManager.undoCount());

            s.undo(new Undo(), window, cx);
            assertEquals("", s.value());

            s.redo(new Redo(), window, cx);
            assertEquals("你", s.value());
        });
    }

    /**
     * A keystroke right after a committed composition must be its own undo
     * entry, not merged into the (finalized) composition transaction.
     */
    function testEditAfterCompositionIsSeparateUndo() {
        final view = buildTextarea(state -> state.defaultValue(""));
        view.update((s, window, cx) -> {
            s.replaceAndMarkTextInRange(null, "n", range(1, 1), window, cx);
            s.replaceTextInRange(null, "你", window, cx);
            assertEquals("你", s.value());
            assertEquals(1, @:privateAccess s.undoManager.undoCount());

            // Typing after the commit is a distinct transaction.
            s.replaceTextInRange(null, "x", window, cx);
            assertEquals("你x", s.value());
            assertEquals(2, @:privateAccess s.undoManager.undoCount());

            s.undo(new Undo(), window, cx);
            assertEquals("你", s.value());
            s.undo(new Undo(), window, cx);
            assertEquals("", s.value());
        });
    }

    /**
     * Canceling a composition via `unmarkText` closes its transaction so it
     * does not leak and swallow a later edit.
     */
    function testCompositionCancelViaUnmarkDoesNotLeak() {
        final view = buildTextarea(state -> state.defaultValue(""));
        view.update((s, window, cx) -> {
            s.replaceAndMarkTextInRange(null, "n", range(1, 1), window, cx);
            s.unmarkText(window, cx);
            final afterCancel = @:privateAccess s.undoManager.undoCount();

            // A later edit is recorded independently.
            s.replaceTextInRange(null, "x", window, cx);
            assertEquals(afterCancel + 1, @:privateAccess s.undoManager.undoCount());
        });
    }

    function testSetSelectedRangeClipsToUtf8Boundaries() {
        final view = build(state -> state.defaultValue("éx"));
        view.update((state, window, cx) -> {
            state.setSelectedRange(range(0, 1), cx);
            assertRange(0, 2, state.selectedRange());
            state.copy(new Copy(), window, cx);

            state.setSelectedRange(range(1, 1), cx);
            assertRange(0, 0, state.selectedRange());
        });
    }

    function testImeSelectionIsRelativeToReplacementStart() {
        final view = build(state -> state.defaultValue("你好 "));
        view.update((state, window, cx) -> {
            state.setSelectedRange(range(7, 7), cx);
            state.replaceAndMarkTextInRange(null, "s", range(1, 1), window, cx);
            state.replaceAndMarkTextInRange(null, "sh", range(2, 2), window, cx);

            assertEquals("你好 sh", state.value());
            assertRange(9, 9, state.selectedRange());
            assertRange(7, 9, state.imeMarkedRange.toRange());
        });
    }

    function testUndoManagerCompositionIsOneUndoGroup() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("a", window, cx);
            state.replaceAndMarkTextInRange(null, "s", null, window, cx);
            state.replaceAndMarkTextInRange(null, "sh", null, window, cx);
            state.replaceTextInRange(null, "是", window, cx);
            assertEquals("a是", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("a", state.value());
            state.redo(new Redo(), window, cx);
            assertEquals("a是", state.value());
        });
    }

    function testUndoManagerConsecutiveCompositionsAreSeparateGroups() {
        final view = build();
        view.update((state, window, cx) -> {
            // First composition: "jin" -> "今天"
            state.replaceAndMarkTextInRange(null, "j", null, window, cx);
            state.replaceAndMarkTextInRange(null, "jin", null, window, cx);
            state.replaceTextInRange(null, "今天", window, cx);
            // Second composition: "wo" -> "我们"
            state.replaceAndMarkTextInRange(null, "w", null, window, cx);
            state.replaceAndMarkTextInRange(null, "wo", null, window, cx);
            state.replaceTextInRange(null, "我们", window, cx);
            assertEquals("今天我们", state.value());
            assertRange(12, 12, state.selectedRange());

            state.undo(new Undo(), window, cx);
            assertEquals("今天", state.value());
            assertRange(6, 6, state.selectedRange());

            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
            assertRange(0, 0, state.selectedRange());

            state.redo(new Redo(), window, cx);
            assertEquals("今天", state.value());
            assertRange(6, 6, state.selectedRange());

            state.redo(new Redo(), window, cx);
            assertEquals("今天我们", state.value());
            assertRange(12, 12, state.selectedRange());
        });
    }

    function testUndoManagerTypingAfterCompositionIsASeparateGroup() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceAndMarkTextInRange(null, "n", null, window, cx);
            state.replaceTextInRange(null, "你", window, cx);
            state.undoManager.setPendingIntent(Typing);
            state.replaceTextInRange(null, "a", window, cx);
            state.undoManager.setPendingIntent(Typing);
            state.replaceTextInRange(null, "b", window, cx);
            assertEquals("你ab", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("你", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerCompositionCancelLeavesNoEntry() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("a", window, cx);
            state.replaceAndMarkTextInRange(null, "s", null, window, cx);
            state.replaceAndMarkTextInRange(null, "", null, window, cx);

            assertEquals("a", state.value());
            assertFalse(@:privateAccess state.undoManager.hasUndos());
        });
    }

    /** The macOS Korean IME rewrites the character it just inserted. */
    function testUndoManagerImeRewritesOfTypedCharAreOneGroup() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("é ", window, cx);
            state.setSelectedRange(range(3, 3), cx);
            // g k s r m f: "ㅎ" -> "하" -> "한", then "ㄱ" -> "그" -> "글"
            state.replaceTextInRange(null, "ㅎ", window, cx);
            state.replaceTextInRange(range(2, 3), "하", window, cx);
            state.replaceTextInRange(range(2, 3), "한", window, cx);
            state.replaceTextInRange(null, "ㄱ", window, cx);
            state.replaceTextInRange(range(3, 4), "그", window, cx);
            state.replaceTextInRange(range(3, 4), "글", window, cx);
            assertEquals("é 한글", state.value());
            assertEquals(1, @:privateAccess state.undoManager.undoCount());

            state.undo(new Undo(), window, cx);
            assertEquals("é ", state.value());
            assertRange(3, 3, state.selectedRange());

            state.redo(new Redo(), window, cx);
            assertEquals("é 한글", state.value());
            assertRange(9, 9, state.selectedRange());
        });
    }

    function testUndoManagerRewriteAfterCursorMovementIsSeparate() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "c", window, cx);
            state.replaceTextInRange(null, "e", window, cx);
            state.left(new MoveLeft(), window, cx);
            state.right(new MoveRight(), window, cx);
            state.replaceTextInRange(range(1, 2), "é", window, cx);
            assertEquals("cé", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("ce", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerSelectionRestoredByUndoAndRedo() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("abc", window, cx);
            state.setSelectedRange(range(1, 2), cx);
            state.replaceTextInRange(null, "X", window, cx);

            state.undo(new Undo(), window, cx);
            assertEquals("abc", state.value());
            assertRange(1, 2, state.selectedRange());

            state.redo(new Redo(), window, cx);
            assertEquals("aXc", state.value());
            assertRange(2, 2, state.selectedRange());
        });
    }

    function testUndoManagerForwardDeleteRestoresCursor() {
        final view = build();
        view.update((state, window, cx) -> {
            state.setValue("abc", window, cx);
            state.setSelectedRange(range(1, 1), cx);
            state.delete(new Delete(), window, cx);

            state.undo(new Undo(), window, cx);
            assertEquals("abc", state.value());
            assertRange(1, 1, state.selectedRange());
        });
    }

    function testUndoManagerSelectionMovementPreservesRedo() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "ab", window, cx);
            state.undo(new Undo(), window, cx);
            state.setSelectedRange(range(0, 0), cx);
            state.redo(new Redo(), window, cx);
            assertEquals("ab", state.value());

            state.undo(new Undo(), window, cx);
            state.replaceTextInRange(null, "x", window, cx);
            state.redo(new Redo(), window, cx);
            assertEquals("x", state.value());
        });
    }

    function testUndoManagerNoopEditPreservesRedo() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.moveTo(0, null, cx);
            state.replaceTextInRange(null, "", window, cx);
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
            state.redo(new Redo(), window, cx);
            assertEquals("a", state.value());
            assertEquals(1, state.cursor());
        });
    }

    function testCursorRoundTripStopsTypingCoalescing() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "a", window, cx);
            state.left(new MoveLeft(), window, cx);
            state.right(new MoveRight(), window, cx);
            state.replaceTextInRange(null, "b", window, cx);

            state.undo(new Undo(), window, cx);
            assertEquals("a", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerNoopEditBreaksCoalescingWithoutClearingHistory() {
        final view = build();
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, "alpha", window, cx);
            state.replaceTextInRange(null, "", window, cx);
            state.replaceTextInRange(null, "beta", window, cx);
            assertEquals("alphabeta", state.value());

            state.undo(new Undo(), window, cx);
            assertEquals("alpha", state.value());
            state.undo(new Undo(), window, cx);
            assertEquals("", state.value());
        });
    }

    function testUndoManagerMaskedRedoRestoresActualCursor() {
        final view = build(state -> state.withMaskPattern(Number(','.code, null)));
        view.update((state, window, cx) -> {
            state.setValue("12345", window, cx);
            state.setSelectedRange(range(2, 2), cx);
            state.replaceTextInRange(null, "9", window, cx);
            final selectionAfterEdit = state.selectedRange();
            assertTrue(selectionAfterEdit.end != state.value().length);

            state.undo(new Undo(), window, cx);
            state.redo(new Redo(), window, cx);
            assertTrue(state.selectedRange().equals(selectionAfterEdit));
        });
    }

    /**
     * Unfolding at a position opens exactly the folds hiding it.
     *
     * A fold keeps its own first and last line visible, so a position on
     * either of them opens nothing. Nested folds all open at once, sibling
     * folds stay closed, and the opened ranges stay fold candidates.
     */
    function testUnfoldAt() {
        final view = buildEditor();
        view.update((state, window, cx) -> {
            state.setValue("a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl", window, cx);
            state.applyHighlighterFoldCandidates([new FoldRange(0, 5), new FoldRange(2, 4), new FoldRange(7, 10)], cx);
            state.displayMap.setFolded(0, true);
            state.displayMap.setFolded(2, true);
            state.displayMap.setFolded(7, true);
        });

        // The outer fold's own first and last line stay visible, so neither
        // position opens anything.
        for (line in [0, 5]) {
            view.update((state, _, cx) -> {
                assertFalse(state.displayMap.isBufferLineHidden(line));
                assertFalse((cast state : EditorState).unfoldAt(new LspPosition(line, 0), cx));
                assertTrue(state.displayMap.isFoldedAt(0));
                assertTrue(state.displayMap.isFoldedAt(2));
                assertTrue(state.displayMap.isFoldedAt(7));
            });
        }

        // Line 3 is hidden by both the outer and the nested fold, so both
        // open; the sibling fold does not.
        view.update((state, _, cx) -> {
            assertTrue((cast state : EditorState).unfoldAt(new LspPosition(3, 0), cx));
            assertFalse(state.displayMap.isBufferLineHidden(3));
            assertFalse(state.displayMap.isFoldedAt(0));
            assertFalse(state.displayMap.isFoldedAt(2));
            assertTrue(state.displayMap.isFoldedAt(7));
            // The opened ranges are still candidates for refolding.
            assertTrue(state.displayMap.isFoldCandidate(0));
            assertTrue(state.displayMap.isFoldCandidate(2));
        });

        // Nothing is hidden there any more, so a second call is a no-op.
        view.update((state, _, cx) -> {
            assertFalse((cast state : EditorState).unfoldAt(new LspPosition(3, 0), cx));
        });
    }

    /** Losing focus hides the hover popover but keeps the decorations. */
    function testBlurKeepsDecorations() {
        final view = buildEditor();
        view.update((state, window, cx) -> {
            state.setValue("select 1", window, cx);
            final collection = state.createDecorationsCollection([new TextDecoration(range(0, 6), new gpui.HighlightStyle(null, gpui.FontWeight.BOLD))], cx);
            state.presentHover(range(0, 6), new LspHover("docs"), cx);
            assertNotNull(state.hoverPopover());

            @:privateAccess state.onBlur(window, cx);

            assertNull(state.hoverPopover(), "blur should hide the hover popover");
            var any = false;
            for (layer in state.extras.decorationLayers()) {
                if (layer.length > 0)
                    any = true;
            }
            assertTrue(any, "blur must not discard decorations");
            assertNotNull(collection);
        });
    }

    /** The mode marker is the only source of truth for the kind of input. */
    function testKindDoesNotFollowTheRowCount() {
        final view = buildTextarea(state -> state.autoGrow(1, 1));
        final state = view.state();
        assertTrue(state.isMultiLine());
        assertFalse(state.isSingleLine());
        assertFalse(state.isCodeEditor());
    }


    function testTextareaPrewrapPreparesContentRowsBeforeLayout() {
        app.update(cx -> gpui.base.Base.init(cx));
        for (pair in [{value: "", rows: 1}, {value: "one\ntwo", rows: 2}]) {
            openWithState((window, cx) -> {
                final font = window.textStyle().font();
                cx.app.newEntity((cx:Context<InputBaseState>) -> {
                    final state = new TextareaState(window, cx).rows(12).defaultValue(pair.value);
                    assertEquals(0, state.displayMap.wrapRowCount());
                    state.prewrap(font, 14., 120., cx);
                    assertEquals(pair.rows, state.displayMap.wrapRowCount());
                    assertEquals(pair.value, state.value());
                    return (state : InputBaseState);
                });
            });
        }
    }

    function testTextareaPrewrapRespectsSoftWrapBeforeLayout() {
        app.update(cx -> gpui.base.Base.init(cx));
        final value = "select id, name, email, phone from users where active\nlimit 10";
        for (softWrap in [true, false]) {
            openWithState((window, cx) -> {
                final font = window.textStyle().font();
                cx.app.newEntity((cx:Context<InputBaseState>) -> {
                    final state = new TextareaState(window, cx).rows(1).withSoftWrap(softWrap).defaultValue(value);
                    state.prewrap(font, 14., 120., cx);
                    final rows = state.displayMap.wrapRowCount();
                    if (softWrap) {
                        assertTrue(rows > 2, "the first logical line must wrap");
                    }
                    else {
                        assertEquals(2, rows);
                    }
                    assertEquals(value, state.value());
                    return (state : InputBaseState);
                });
            });
        }
    }

    function testPrewrapCountsWrappedRowsBeforeTheFirstPaint() {
        app.update(cx -> gpui.base.Base.init(cx));
        final text = "select id, name, email, phone from users where active\nlimit 10";
        for (pair in [{softWrap: true, wraps: true}, {softWrap: false, wraps: false}]) {
            var input:Entity<InputBaseState> = null;
            openWithState((window, cx) -> {
                final font = window.textStyle().font();
                input = cx.app.newEntity((cx:Context<InputBaseState>) -> {
                    final state = new EditorState(window, cx).withSoftWrap(pair.softWrap).defaultValue(text);
                    state.prewrap(font, 14., 120., cx);
                    return (state : InputBaseState);
                });
            });
            final rows = input.read(app).displayMap.wrapRowCount();
            // Two lines; at 120px the first wraps unless soft wrap is off.
            assertEquals(pair.wraps, rows > 2, 'soft_wrap(${pair.softWrap}): $rows rows');
            if (!pair.wraps) {
                assertEquals(2, rows);
            }
        }
    }

    function testPrewrapUsesTheConfiguredTabStops() {
        app.update(cx -> gpui.base.Base.init(cx));
        openWithState((window, cx) -> {
            final font = window.textStyle().font();
            final fontSize = 14.;
            final fontId = window.textSystem().resolveFont(font);
            final spaceWidth:Float = window.textSystem().layoutWidth(fontId, fontSize, ' '.code);
            cx.app.newEntity((cx:Context<InputBaseState>) -> {
                final state = new EditorState(window, cx);
                gpui.base.input.InputIndentExt.tabSize(state, new TabSize(4, true));
                state.defaultValue("\t\t");
                for (pair in [{tab: 4, rows: 2}, {tab: 2, rows: 1}, {tab: 8, rows: 2}]) {
                    gpui.base.input.InputIndentExt.setTabSize(state, new TabSize(pair.tab, true), cx);
                    state.prewrap(font, fontSize, spaceWidth * 5. + TextElement.RIGHT_MARGIN, cx);
                    assertEquals(pair.rows, state.displayMap.wrapRowCount());
                }
                return (state : InputBaseState);
            });
        });
    }

    /**
     * Prewrap counts with the state's wrapping indent, as the first layout
     * does: continuation rows indented as deep as their line take more rows.
     */
    function testPrewrapWrapsWithTheWrappingIndent() {
        app.update(cx -> gpui.base.Base.init(cx));
        final text = "            select id, name, email, phone from users where active";
        final rows = [];
        for (indent in [WrappingIndent.Same, WrappingIndent.None]) {
            var input:Entity<InputBaseState> = null;
            openWithState((window, cx) -> {
                final font = window.textStyle().font();
                input = cx.app.newEntity((cx:Context<InputBaseState>) -> {
                    final state = new EditorState(window, cx).withWrappingIndent(indent).defaultValue(text);
                    // Rust wraps at 200 px with the test platform's text system;
                    // with the port's fonts both indents need 3 rows there, so
                    // the comparison is made at 150 px (5 rows against 4).
                    state.prewrap(font, 14., 150., cx);
                    return (state : InputBaseState);
                });
            });
            rows.push(input.read(app).displayMap.wrapRowCount());
        }
        assertTrue(rows[0] > rows[1], 'rows with Same, None: $rows');
    }

    /** Soft wrap is on by default, for every mode that can wrap. */
    function testSoftWrapIsEnabledByDefault() {
        final textarea = buildTextarea();
        assertTrue(textarea.state().softWrap);

        final editor = buildEditor();
        assertTrue(editor.state().softWrap);
    }


    // Accessibility and text input configuration

    function testAccessibilityActionsRecheckLiveEditability() {
        app.update(cx -> gpui.base.Base.init(cx));
        final view = build(state -> state.defaultValue("initial"));
        var changes = 0;
        final subscription = app.update(cx -> cx.subscribe(view.input, InputEvent, (_, event, _) -> {
            if (event == InputEvent.Change)
                changes++;
        }));
        view.update((state, window, cx) -> {
            @:privateAccess state.handleAccessibilitySetValue(null, window, cx);
            @:privateAccess state.handleAccessibilityFocus(window, cx);
            assertTrue(state.focusHandle.isFocused(window));
        });
        view.cx.update((window, _) -> window.draw());
        assertEquals("initial", view.state().value());
        assertEquals(0, changes);

        view.update((state, window, cx) -> @:privateAccess state.handleAccessibilitySetValue("updated🦀", window, cx));
        assertEquals("updated🦀", view.state().value());
        assertEquals(1, changes);
        for (disabled in [false, true]) {
            view.cx.update((window, cx) -> window.blur(cx));
            view.update((state, window, cx) -> {
                state.setDisabled(disabled, cx);
                state.setReadonly(!disabled, cx);
                @:privateAccess state.handleAccessibilityFocus(window, cx);
                assertEquals(!disabled, state.focusHandle.isFocused(window));
                @:privateAccess state.handleAccessibilitySetValue("rejected", window, cx);
            });
            assertEquals("updated🦀", view.state().value());
            assertEquals(1, changes);
        }
        view.update((state, window, cx) -> {
            state.setDisabled(false, cx);
            state.setReadonly(false, cx);
            @:privateAccess state.handleAccessibilityFocus(window, cx);
        });
        view.cx.update((window, cx) -> {
            window.draw();
            window.dispatchAction(new Undo(), cx);
        });
        assertEquals("initial", view.state().value());
        view.update((state, window, cx) -> {
            (cast state : InputState).setMasked(true, window, cx);
            @:privateAccess state.handleAccessibilitySetValue("updated🦀", window, cx);
        });
        assertEquals("updated🦀", view.state().value());
        subscription.dispose();
    }

    function testAccessibilitySetValuePreservesExactEditorText() {
        app.update(cx -> gpui.base.Base.init(cx));
        final view = buildEditor(state -> state.language("rust"));
        view.update((editor, window, cx) -> @:privateAccess editor.handleAccessibilitySetValue("(", window, cx));
        assertEquals("(", view.state().value());
    }

    function testRevealingAPasswordKeepsTextAssistanceDisabled() {
        app.update(cx -> gpui.base.Base.init(cx));
        openWithState((window, cx) -> {
            final state:Entity<InputBaseState> = cx.app.newEntity((cx:Context<InputBaseState>) -> (new InputState(window, cx).withMasked(true) : InputBaseState));
            final hidden = state.read(cx.app).textInputConfiguration(null, null);
            assertTrue(!hidden.autocorrect && !hidden.suggestions);
            assertEquals(gpui.TextInputConfiguration.Autocapitalize.None, hidden.autocapitalize);

            // The component's reveal button uses this same state transition.
            state.update(cx.app, (state, cx) -> state.toggleMasked(window, cx));
            assertTrue(state.read(cx.app).textInputConfiguration(null, null).equals(hidden));
            state.update(cx.app, (state, cx) -> state.toggleMasked(window, cx));
            assertTrue(state.read(cx.app).textInputConfiguration(null, null).equals(hidden));
        });
    }

    function testTextInputConfigurationFollowsTheInput() {
        app.update(cx -> gpui.base.Base.init(cx));
        var states:Array<InputBaseState> = null;
        openWithState((window, cx) -> {
            states = [
                cx.app.newEntity((cx:Context<InputBaseState>) -> (new InputState(window, cx) : InputBaseState)),
                cx.app.newEntity((cx:Context<InputBaseState>) -> (new InputState(window, cx).withMasked(true) : InputBaseState)),
                cx.app.newEntity((cx:Context<InputBaseState>) -> (new TextareaState(window, cx) : InputBaseState)),
                cx.app.newEntity((cx:Context<InputBaseState>) -> (new InputState(window, cx)
                    .withInputAction(gpui.TextInputConfiguration.TextInputAction.Search)
                    .withAutocorrect(true)
                    .withAutocapitalize(gpui.TextInputConfiguration.Autocapitalize.Words) : InputBaseState)),
            ];
        });
        final done = gpui.TextInputConfiguration.defaultValue().with(null, null, null, gpui.TextInputConfiguration.TextInputAction.Done);
        assertTrue(states[0].textInputConfiguration(null, null).equals(done));
        assertTrue(states[1].textInputConfiguration(null, null).equals(done));
        final enter = gpui.TextInputConfiguration.defaultValue().with(null, null, null, gpui.TextInputConfiguration.TextInputAction.Enter);
        assertTrue(states[2].textInputConfiguration(null, null).equals(enter));
        final search = states[3].textInputConfiguration(null, null);
        assertEquals(gpui.TextInputConfiguration.TextInputAction.Search, search.inputAction);
        assertEquals(gpui.TextInputConfiguration.Autocapitalize.Words, search.autocapitalize);
        assertTrue(search.autocorrect);
        assertTrue(search.suggestions);
    }

    // Scroll bounce





    function testScrollBounceStretchesPastTheEndAndSpringsBack() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        draw(view);
        final drawnAt = () -> (view.state().lastBounds.origin.y : Float);

        swipe(view, -20., Started);
        swipe(view, -100000., Moved);
        final end:Float = view.state().scrollHandle.offset().y;
        final stretch = view.state().overscroll.offset();
        assertTrue(end < 0., "the text scrolled to its end");
        assertTrue(stretch < 0., 'the rest stretched the edge: $stretch');
        draw(view);
        final stretchedAt = drawnAt();

        swipe(view, 0., Ended);
        for (_ in 0...120) {
            view.cx.advanceClock(0.016);
            draw(view);
        }
        assertEquals(0., view.state().overscroll.offset(), "the edge sprang back");
        assertEquals(end, (view.state().scrollHandle.offset().y : Float), "scrolling stayed exact");
        final moved = stretchedAt - drawnAt();
        assertTrue(Math.abs(moved - stretch) < 0.001, 'the stretch only moved where the text was drawn: $moved vs $stretch');
    }

    function testScrollBounceStaysPutUnderReducedMotion() {
        app.update(cx -> gpui.base.ReduceMotion.applyPreference(true, cx));
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        final result = swipePastTheEnd(view);
        assertTrue(result.end < 0., "the text still scrolls");
        assertEquals(0., result.stretch, "the edge does not stretch");
    }

    function testScrollBounceFollowsThePlatformByDefault() {
        final view = buildTextarea(state -> state.defaultValue(longText()));
        final result = swipePastTheEnd(view);
        assertTrue(result.end < 0., "the text scrolls");
        assertEquals(gpui.base.ScrollBounce.enabledByDefault(), result.stretch != 0., "the edge stretches where the platform's scroll views do");
    }

    function testScrollBounceLeavesTextThatFits() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue("one line"));
        final result = swipePastTheEnd(view);
        assertEquals(0., result.end);
        assertEquals(0., result.stretch);
    }

    function testScrollBounceResetsWhenReplacementTextFits() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        final result = swipePastTheEnd(view);
        assertTrue(result.stretch < 0.);
        view.update((state, window, cx) -> state.setValue("short", window, cx));
        draw(view);
        swipe(view, 0., Ended);
        assertEquals(0., view.state().overscroll.offset());
        assertEquals(0., (view.state().scrollHandle.offset().y : Float));
    }

    function testScrollBounceReleasesWhenTheEndPacketIsHorizontal() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        final result = swipePastTheEnd(view);
        assertTrue(result.stretch < 0.);
        view.update((state, window, cx) -> state.onScrollWheel(new gpui.ScrollEvent(new gpui.Point(0, 0), Pixels(new gpui.Point(1., 0.)), null, Ended), window, cx));
        for (_ in 0...120) {
            view.cx.advanceClock(0.016);
            draw(view);
        }
        assertEquals(0., view.state().overscroll.offset());
    }

    function testScrollBounceOrdinaryMouseWheelDoesNotStretch() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        draw(view);
        view.update((state, window, cx) -> {
            state.onScrollWheel(new gpui.ScrollEvent(new gpui.Point(0, 0), Lines(new gpui.Point(0., -100000.)), null, Moved), window, cx);
            assertTrue(state.scrollHandle.offset().y < 0.);
            assertEquals(0., state.overscroll.offset());
        });
    }

    function testScrollBounceNewWheelInputInterruptsTheReturn() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        final result = swipePastTheEnd(view);
        assertTrue(result.stretch < 0.);
        swipe(view, 0., Ended);
        view.cx.advanceClock(0.016);
        draw(view);
        view.update((state, window, cx) -> {
            state.onScrollWheel(new gpui.ScrollEvent(new gpui.Point(0, 0), Lines(new gpui.Point(0., 2.)), null, Moved), window, cx);
            assertTrue(state.scrollHandle.offset().y > result.end);
            assertEquals(0., state.overscroll.offset());
        });
    }

    function testTurningScrollBounceOffDropsTheStretch() {
        final view = buildTextarea(state -> state.withScrollBounce(true).defaultValue(longText()));
        final result = swipePastTheEnd(view);
        assertTrue(result.stretch < 0., 'the edge stretched: ${result.stretch}');
        view.update((state, _, cx) -> (cast state : TextareaState).setScrollBounce(false, cx));
        assertEquals(0., view.state().overscroll.offset());
    }

    /** The frame is laid out by the application, which should not have to center a single line inside it. */
    function testSingleLineIsCenteredInATallerFrame() {
        app.update(cx -> gpui.base.Base.init(cx));
        var input:Entity<InputState> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            input = cx.app.newEntity((cx:Context<InputState>) -> new InputState(window, cx).defaultValue("a"));
            final state = input;
            return new ScriptView((_, _) -> new gpui.base.input.InputBase("frame").h(px(60.)).child(new gpui.base.input.Input(state)));
        }, 400, 100);
        contexts.push(opened.cx);
        opened.cx.update((window, _) -> window.draw());
        final line = (input : InputState).inputBounds;
        assertEquals(30., (line.center().y : Float), 'line $line');
    }

    function testNoopScrollNotifiesDiagnosticDismissal() {
        app.update(cx -> gpui.base.Base.init(cx));
        var input:Entity<InputBaseState> = null;
        openWithState((window, cx) -> {
            input = cx.app.newEntity((cx:Context<InputBaseState>) -> (new EditorState(window, cx) : InputBaseState));
        });
        input.update(app, (state, cx) -> {
            state.inputBounds = new gpui.Bounds(new gpui.Point(0, 0), new gpui.Size(100., 20.));
            state.scrollSize = new gpui.Size(100., 20.);
            state.presentDiagnostic(new gpui.base.input.DiagnosticEntry(range(0, 0),
                new gpui.base.input.Diagnostic(new LspPosition(0, 0), new LspPosition(0, 0), "")), cx);
        });
        var notifications = 0;
        final subscription = app.update(cx -> cx.observe(input, (_, _) -> notifications++));

        final window = contexts[contexts.length - 1].window;
        app.update(cx -> input.update(cx, (state, cx) -> {
            state.onScrollWheel(new gpui.ScrollEvent(new gpui.Point(0, 0), Pixels(new gpui.Point(0., -40.))), window, cx);
            assertTrue(state.scrollHandle.offset().equals(new gpui.Point(0, 0)));
            assertNull(state.diagnosticPopover);
        }));
        assertEquals(1, notifications, "clearing a diagnostic must notify even when scrolling is clamped");
        app.update(cx -> input.update(cx, (state, cx) -> {
            state.onScrollWheel(new gpui.ScrollEvent(new gpui.Point(0, 0), Pixels(new gpui.Point(0., -40.))), window, cx);
        }));
        assertEquals(1, notifications, "an unchanged input must stay quiet");
        subscription.dispose();
    }

    function testInputScrollOffsetNotifiesOnlyOnChange() {
        app.update(cx -> gpui.base.Base.init(cx));
        var input:Entity<InputBaseState> = null;
        openWithState((window, cx) -> {
            input = cx.app.newEntity((cx:Context<InputBaseState>) -> (new InputState(window, cx) : InputBaseState));
        });
        var notifications = 0;
        final subscription = app.update(cx -> cx.observe(input, (_, _) -> notifications++));

        input.update(app, (state, _) -> {
            state.inputBounds = new gpui.Bounds(new gpui.Point(0, 0), new gpui.Size(100., 20.));
            state.scrollSize = new gpui.Size(300., 20.);
        });
        for (target in [null, new gpui.Point(0., 0.), new gpui.Point(20., 50.)]) {
            input.update(app, (state, cx) -> state.updateScrollOffset(target, cx));
            assertEquals(0, notifications, "an unchanged clamped offset must stay quiet");
        }
        input.update(app, (state, cx) -> {
            state.updateScrollOffset(new gpui.Point(-40., 0.), cx);
            assertTrue(state.scrollHandle.offset().equals(new gpui.Point(-40., 0.)));
        });
        assertEquals(1, notifications, "a scroll must notify");
        input.update(app, (state, cx) -> {
            state.updateScrollOffset(new gpui.Point(-400., 50.), cx);
            assertTrue(state.scrollHandle.offset().equals(new gpui.Point(-200., 0.)));
        });
        assertEquals(2, notifications);
        input.update(app, (state, cx) -> state.updateScrollOffset(new gpui.Point(-500., 0.), cx));
        assertEquals(2, notifications, "clamping to the current offset must stay quiet");
        input.update(app, (state, cx) -> {
            state.scrollSize = new gpui.Size(110., state.scrollSize.height);
            state.updateScrollOffset(null, cx);
            assertTrue(state.scrollHandle.offset().equals(new gpui.Point(-10., 0.)));
        });
        assertEquals(3, notifications, "a smaller scroll range must clamp and notify");
        subscription.dispose();
    }

    function testSetLineNumberNotifiesOnlyOnChange() {
        app.update(cx -> gpui.base.Base.init(cx));
        var input:Entity<InputBaseState> = null;
        openWithState((window, cx) -> {
            input = cx.app.newEntity((cx:Context<InputBaseState>) -> (new EditorState(window, cx) : InputBaseState));
        });
        final window = contexts[contexts.length - 1].window;
        final shown = input.read(app).mode.lineNumber();
        var notifications = 0;
        final subscription = app.update(cx -> cx.observe(input, (_, _) -> notifications++));

        app.update(cx -> input.update(cx, (state, cx) -> (cast state : EditorState).setLineNumber(shown, window, cx)));
        assertEquals(0, notifications);

        app.update(cx -> input.update(cx, (state, cx) -> (cast state : EditorState).setLineNumber(!shown, window, cx)));
        assertEquals(1, notifications);
        assertEquals(!shown, input.read(app).mode.lineNumber());
        subscription.dispose();
    }

    function testSetValueOnUnfocusedInputStaysQuiet() {
        app.update(cx -> gpui.base.Base.init(cx));
        var input:Entity<InputBaseState> = null;
        openWithState((window, cx) -> {
            input = cx.app.newEntity((cx:Context<InputBaseState>) -> (new InputState(window, cx) : InputBaseState));
        });
        final cx = contexts[contexts.length - 1];
        cx.runUntilParked();

        var notifications = 0;
        final subscription = app.update(app -> app.observe(input, (_, _) -> notifications++));
        cx.runUntilParked();

        // Seeding a form is a write, so it notifies once. The input is not
        // focused and draws no caret, so nothing may notify after that.
        cx.update((window, app) -> input.update(app, (state, cx) -> state.setValue("seeded", window, cx)));
        cx.runUntilParked();
        final settled = notifications;

        cx.advanceClock(3.);
        cx.runUntilParked();

        assertEquals(settled, notifications, "an unfocused input is blinking, and every blink repaints the view it is in");
        subscription.dispose();
    }

    function testTextareaCursorTreatsCrlfAsOneNewline() {
        app.update(cx -> gpui.base.Base.init(cx));
        final view = buildTextarea();
        view.update((state, window, cx) -> {
            for (original in ["\r\nlast", "\u{feff}first\r\nlast\n", "first\nlast\r\n"]) {
                state.setValue(original, window, cx);
                final bytes = haxe.io.Bytes.ofString(original);
                var newline = 0;
                while (bytes.get(newline) != '\n'.code)
                    newline++;
                final end = bytes.get(newline > 0 ? newline - 1 : 0) == '\r'.code ? newline - 1 : newline;
                state.end(new MoveEnd(), window, cx);
                assertEquals(end, state.cursor());
                state.right(new MoveRight(), window, cx);
                assertEquals(newline + 1, state.cursor());
                state.left(new MoveLeft(), window, cx);
                assertEquals(end, state.cursor());
                state.selectToEndOfLine(new SelectToEndOfLine(), window, cx);
                assertRange(end, end, state.selectedRange());
                state.moveToEnd(new MoveToEnd(), window, cx);
                assertEquals(bytes.length, state.cursor());
                state.moveToStart(new MoveToStart(), window, cx);
                assertEquals(0, state.cursor());
                assertEquals(original, state.value());
            }
            // A lone CR is an ordinary character; it must not skip its neighbour.
            state.setValue("a\rb", window, cx);
            state.right(new MoveRight(), window, cx);
            assertEquals(1, state.cursor());
            state.right(new MoveRight(), window, cx);
            assertEquals(2, state.cursor());
        });
    }

    function testOnlyAMultiLineInputPaintsScrollbars() {
        app.update(cx -> gpui.base.Base.init(cx));

        // A single-line input keeps its caret in view by moving its own offset;
        // it has no viewport to drag.
        final single = build();
        assertFalse(single.state().showsScrollbar());

        final multi = buildTextarea();
        assertTrue(multi.state().showsScrollbar());
    }

    function testContextMenuHandlerIsDeferredAndRespectsDisabled() {
        app.update(cx -> gpui.base.Base.init(cx));
        final view = buildEditor();
        var calls = 0;
        var items = 0;
        final menuFocus = view.cx.update((_, cx) -> cx.focusHandle());

        view.update((state, window, cx) -> {
            state.onContextMenu((menu, _, _, window, cx) -> {
                calls++;
                items = menu.items.length;
                menuFocus.focus(window, cx);
            });
            state.handleRightClickMenu(new gpui.Point(0., 0.), 0, window, cx);
        });
        assertEquals(1, calls);
        assertEquals(0, items);
        assertTrue(@:privateAccess view.state().selectionFocus == menuFocus,
            "the menu callback must retain selection without reborrowing its input");

        // A custom handler may keep using the same, already-focused menu.
        view.update((state, window, cx) -> state.handleRightClickMenu(new gpui.Point(0., 0.), 0, window, cx));
        assertEquals(2, calls);
        view.cx.update((window, cx) -> assertTrue(view.state().hasSelectionFocus(window, cx)));

        view.update((state, window, cx) -> {
            state.disabled = true;
            state.handleRightClickMenu(new gpui.Point(0., 0.), 0, window, cx);
        });
        assertEquals(2, calls);
    }

    function testContextMenuHandlerCanReadItsInput() {
        app.update(cx -> gpui.base.Base.init(cx));
        final view = buildEditor();
        var cursor:Null<Int> = null;

        view.update((state, window, cx) -> {
            state.setValue("hello", window, cx);
            final weak = cx.weakEntity();
            state.onContextMenu((_, _, _, _, cx) -> {
                final input = weak.upgrade();
                cursor = input != null ? input.read(cx).cursor() : null;
            });
            state.handleRightClickMenu(new gpui.Point(0., 0.), 2, window, cx);
        });
        assertEquals(2, cursor);
    }

    function testReadonlyRejectsUserEditsOnly() {
        final view = buildEditor();
        view.update((state, window, cx) -> {
            state.setValue("hello", window, cx);
            state.setReadonly(true, cx);
        });

        assertFalse(view.state().isEditable());
        assertFalse(gpui.base.input.InputSearchExt.isReplaceable(view.state()));

        // Typing (and IME) goes through the input handler, it must be rejected.
        view.update((state, window, cx) -> {
            state.replaceTextInRange(null, " world", window, cx);
            state.replaceAndMarkTextInRange(null, "あ", null, window, cx);
        });
        assertEquals("hello", view.state().value());

        // The programmatic APIs are not limited by the readonly mode.
        view.update((state, window, cx) -> {
            state.insert(" world", window, cx);
            state.setValue("changed", window, cx);
        });
        assertEquals("changed", view.state().value());

        // And the user can edit again after leaving the readonly mode.
        // The caret is at the start, because `setValue` has reset the selection.
        view.update((state, window, cx) -> {
            state.setReadonly(false, cx);
            state.replaceTextInRange(null, "!", window, cx);
        });
        assertTrue(view.state().isEditable());
        assertEquals("!changed", view.state().value());
    }


    /**
     * Regression test: editing at a caret that sits far outside the viewport
     * must reveal it in one frame.
     */
    function testEditRevealsFarOffscreenCaret() {
        final view = buildSized(720., 400., (window, cx) -> new TextareaState(window, cx).autoGrow(1, 6));
        final text = [for (i in 1...101) 'line $i'].join("\n");
        view.update((state, window, cx) -> {
            state.setValue(text, window, cx);
            final end = state.text.len();
            state.setSelection(end, end);
        });
        view.cx.runUntilParked();

        // The user scrolled back to the top to read the pasted text.
        view.update((state, _, cx) -> {
            state.scrollHandle.setOffset(new gpui.Point(0., 0.));
            cx.notify();
        });
        view.cx.runUntilParked();

        view.update((state, window, cx) -> state.replaceTextInRange(null, "X", window, cx));
        view.cx.runUntilParked();

        final state = view.state();
        assertTrue(StringTools.endsWith(state.value(), "line 100X"));
        final caret = state.cursorLayout();
        assertNotNull(caret, "caret painted");
        final viewport = state.inputBounds;
        final scrollY:Float = state.scrollHandle.offset().y;
        final top:Float = caret.bounds.origin.y - viewport.origin.y + scrollY;
        assertTrue(top >= 0. && top + caret.bounds.size.height <= viewport.size.height,
            'caret top $top outside viewport height ${viewport.size.height} (scroll $scrollY)');
    }

    /** Regression test: changing the auto-grow limits keeps the rows fitted to the text. */
    function testSetAutoGrowKeepsRowsFitted() {
        final view = buildSized(720., 400., (window, cx) -> new TextareaState(window, cx).autoGrow(1, 10));
        final text = [for (i in 1...9) 'line $i'].join("\n");
        view.update((state, window, cx) -> state.setValue(text, window, cx));
        view.cx.runUntilParked();
        assertEquals(8, view.state().mode.rows());

        // A larger maximum keeps all eight rows.
        view.update((state, _, cx) -> (cast state : TextareaState).setAutoGrow(1, 12, cx));
        view.cx.runUntilParked();
        assertEquals(8, view.state().mode.rows());

        // A smaller maximum caps them.
        view.update((state, _, cx) -> (cast state : TextareaState).setAutoGrow(1, 4, cx));
        view.cx.runUntilParked();
        assertEquals(4, view.state().mode.rows());
    }

    /**
     * Regression test: `scrollTo` at end-of-buffer must produce a deferred
     * scroll target within the safe scroll range.
     */
    function testScrollToEobDoesNotOvershootSafeRange() {
        final view = buildEditor();
        view.update((state, window, cx) -> {
            state.setScrollBeyondLastLine(1, window, cx);
            state.setCursorSurroundingLines(1, window, cx);
            state.setValue([for (i in 1...51) 'line $i'].join("\n"), window, cx);
        });
        view.cx.runUntilParked();

        assertTrue(view.state().scrollSize.height > 0., "scroll_size not populated by initial paint");
        assertTrue(view.state().inputBounds.size.height > 0., "input_bounds not populated by initial paint");

        view.update((state, _, cx) -> {
            final end = state.text.len();
            state.moveTo(end, gpui.base.input.MoveDirection.Down, cx);

            final deferred = state.deferredScrollOffset;
            assertNotNull(deferred, "scroll_to should populate deferred_scroll_offset");
            final safeYMin = Math.min(-state.scrollSize.height + state.inputBounds.size.height, 0.);
            assertTrue(deferred.y >= safeYMin, 'deferred_scroll_offset.y = ${deferred.y} below safe_y_min = $safeYMin');
        });
    }

    function assertSearchRevealsWithPaddingAfterManualScroll(previous:Bool):Void {
        final view = buildEditor();
        final text = [for (row in 0...160) (row == 20 || row == 60 || row == 100) ? 'match on row $row' : 'line $row'].join("\n");
        final first = text.indexOf("match");
        final start = text.indexOf("match", first + 1);
        view.update((state, window, cx) -> {
            state.setCursorSurroundingLines(3, window, cx);
            state.setValue(text, window, cx);
            gpui.base.input.InputSearchExt.setSearchQuery(state, "match", true, cx);
            if (previous) {
                state.searchSession.matcher.next();
                state.searchSession.matcher.next();
            }
        });
        view.cx.runUntilParked();
        view.update((state, _, cx) -> {
            final lineHeight:Float = state.lastLayout.lineHeight;
            final y = previous ? 0. : -lineHeight * 80.;
            state.setScrollOffset(new gpui.Point(0., y), cx);
        });
        view.cx.runUntilParked();
        final visible = view.state().visibleRowRange();
        if (previous) {
            assertTrue(visible.end <= 60, "target must be below the viewport");
        }
        else {
            assertTrue(visible.start > 60, "target must be above the viewport");
        }
        view.update((state, _, cx) -> {
            final range = previous ? gpui.base.input.InputSearchExt.previousSearchMatch(state, cx) : gpui.base.input.InputSearchExt.nextSearchMatch(state, cx);
            assertRange(start, start + 5, range);
            assertEquals("2/3", state.searchSession.matcher.label());
        });
        view.cx.runUntilParked();
        final state = view.state();
        final visible = state.visibleRowRange();
        assertTrue(visible.start <= 60 && 60 < visible.end);
        final lineHeight:Float = state.lastLayout.lineHeight;
        final targetY = lineHeight * 60. + state.scrollHandle.offset().y;
        // Three lines of edge clearance include the matched line itself.
        assertTrue(targetY >= lineHeight * 2. - 0.1);
        assertTrue(targetY + lineHeight * 3. <= state.lastBounds.size.height + 0.1, "search must preserve the configured surrounding-line padding");
    }

    function testNextSearchMatchRevealsWithPaddingAfterManualScroll() {
        assertSearchRevealsWithPaddingAfterManualScroll(false);
    }

    function testPreviousSearchMatchRevealsWithPaddingAfterManualScroll() {
        assertSearchRevealsWithPaddingAfterManualScroll(true);
    }

    /** Opens an editor inside a host listening for `Search`, focused, and presses the search shortcut once. */
    function pressSearchShortcut(searchable:Bool):{editor:Entity<InputBaseState>, searchRequests:Void->Int} {
        var searchRequests = 0;
        var editor:Entity<InputBaseState> = null;
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<ScriptView>) -> {
            gpui.base.theme.Theme.globalMut(cx.app);
            InputKeyBindings.init(cx.app);
            editor = cx.app.newEntity((cx:Context<InputBaseState>) -> (new EditorState(window, cx).withSearchable(searchable) : InputBaseState));
            final child = editor;
            return new ScriptView((_, _) -> div().sizeFull().onAction(Search, (_, _, _) -> searchRequests++).child(child));
        });
        contexts.push(opened.cx);
        opened.cx.update((window, app) -> editor.update(app, (state, cx) -> state.focus(window, cx)));
        opened.cx.runUntilParked();
        opened.cx.simulateKeystrokes("cmd-f");
        opened.cx.runUntilParked();
        return {editor: editor, searchRequests: () -> searchRequests};
    }

    function testSearchShortcutReachesTheHostWhenNotSearchable() {
        final pressed = pressSearchShortcut(false);
        assertEquals(1, pressed.searchRequests());
        final state = pressed.editor.read(app);
        assertFalse(state.searchSession.open);
        assertFalse(state.searchSession.isActive());
    }

    function testSearchShortcutOpensThePanelWhenSearchable() {
        final pressed = pressSearchShortcut(true);
        assertEquals(0, pressed.searchRequests());
        final state = pressed.editor.read(app);
        assertTrue(state.searchSession.open);
        assertTrue(state.searchSession.isActive());
    }

    function testSetSearchQueryHighlightsWithoutThePanel() {
        final view = buildEditor(state -> state.withSearchable(false));
        view.update((state, window, cx) -> {
            state.setValue("foo bar foo", window, cx);
            gpui.base.input.InputSearchExt.setSearchQuery(state, "foo", true, cx);
        });
        view.cx.runUntilParked();
        final session = view.state().searchSession;
        assertTrue(session.isActive());
        assertFalse(session.open);
        assertEquals(2, session.matcher.len());
        view.update((state, _, cx) -> gpui.base.input.InputSearchExt.closeSearch(state, cx));
        assertFalse(view.state().searchSession.isActive());
    }

    /**
     * A closed search skips rescanning on edits, so every path that reads
     * the matches again must see the edited text, not the text at close.
     */
    function testClosedSearchResyncsMatchesAfterEdits() {
        final view = buildEditor(state -> state.withSearchable(false));
        view.update((state, window, cx) -> {
            state.setValue("foo bar foo", window, cx);
            gpui.base.input.InputSearchExt.setSearchQuery(state, "foo", true, cx);
            gpui.base.input.InputSearchExt.closeSearch(state, cx);

            state.setValue("bar foo", window, cx);
            assertRange(4, 7, gpui.base.input.InputSearchExt.nextSearchMatch(state, cx));

            state.setValue("foo foo foo", window, cx);
            gpui.base.input.InputSearchExt.setSearchQuery(state, "foo", true, cx);
            assertEquals(3, state.searchSession.matcher.len());
        });
    }

    function testSearchRevealsOffscreenWrappedMatch() {
        final view = buildEditor();
        inline function repeat(s:String, n:Int):String {
            return [for (_ in 0...n) s].join("");
        }
        final text = 'match\n${repeat("line\n", 80)}\n${repeat("wrapped text ", 500)}match\n${repeat("line\n", 80)}';
        view.update((state, window, cx) -> {
            state.setCursorSurroundingLines(3, window, cx);
            state.setValue(text, window, cx);
            gpui.base.input.InputSearchExt.setSearchQuery(state, "match", true, cx);
        });
        view.cx.runUntilParked();
        view.update((state, _, cx) -> assertNotNull(gpui.base.input.InputSearchExt.nextSearchMatch(state, cx)));
        view.cx.runUntilParked();
        final state = view.state();
        final range = state.searchSession.matcher.matchedRanges()[1];
        final layout = state.lastLayout;
        final position = state.lineAndPositionForOffset(range.end).position;
        assertNotNull(position, "wrapped match must be laid out");
        final y:Float = position.y + state.scrollHandle.offset().y;
        final lineHeight:Float = layout.lineHeight;
        assertTrue(y >= lineHeight * 2. - 0.1);
        assertTrue(y + lineHeight * 3. <= state.lastBounds.size.height + 0.1, "wrapped match must retain surrounding display rows");
    }

}

/** A highlighter recording the texts it is driven with. */
private class RecordingHighlighter extends InputHighlighterBase {

    final updates:Array<Array<String>>;

    public function new(updates:Array<Array<String>>) {
        this.updates = updates;
    }

    public function language():String {
        return "recording";
    }

    public function update(edit:Null<InputEdit>, text:Rope, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        updates.push([text.toString()]);
    }

    override public function updateBatch(edits:Array<EditedText>, folding:Bool, window:Window, cx:Context<InputBaseState>):Void {
        updates.push([for (edit in edits) edit.text.toString()]);
    }

    public function styles(range:Range, resolver:HighlightStyleResolver):Array<StyledRange> {
        return [new StyledRange(range, new gpui.HighlightStyle())];
    }

    public function foldRanges(text:Rope):Array<FoldRange> {
        return [];
    }

}
