package tests.kit;

import glaze.ClipboardItem;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.MaskPattern;
import tests.kit.InputStateTestCase.InputView;

using glaze.kit.base.input.MaskPattern.MaskPatternTools;

/**
 * Deliberate deviation DEV-018 (see DEVIATIONS.md): a number mask also takes
 * the comma as the decimal separator and turns it into a dot, so that the
 * decimal keypad of regions writing decimals with a comma can enter decimals.
 * Not when the mask groups digits with a comma: there the comma keeps its
 * meaning of group separator, as in gpui-kit. Typing and pasting go through
 * the same mask, and a second decimal separator is refused.
 */
class NumberDecimalCommaTest extends InputStateTestCase {

    function typeText(view:InputView, text:String):Void {
        view.update((state, window, cx) -> state.replaceTextInRange(null, text, window, cx));
        view.cx.runUntilParked();
    }

    function paste(view:InputView, text:String):Void {
        view.update((state, window, cx) -> {
            cx.writeToClipboard(ClipboardItem.newString(text));
            state.pasteAction(new Paste(), window, cx);
        });
        view.cx.runUntilParked();
    }

    function testTypingACommaGivesADecimalPoint() {
        final view = build(state -> state.withMaskPattern(Number(null, null)));
        typeText(view, "1");
        typeText(view, ",");
        typeText(view, "5");
        assertEquals("1.5", view.state().value());
        assertEquals(1.5, Std.parseFloat(view.state().unmaskValue()));
        assertRange(3, 3, view.state().selectedRange());

        final view = build(state -> state.withMaskPattern(Number(null, null)));
        typeText(view, "1,5");
        assertEquals("1.5", view.state().value());
        assertRange(3, 3, view.state().selectedRange());
    }

    function testCommaIsTheDecimalSeparatorWithASpaceGroupSeparator() {
        final view = build(state -> state.withMaskPattern(Number(' '.code, null)));
        typeText(view, "1234,5");
        assertEquals("1 234.5", view.state().value());
        assertEquals("1234.5", view.state().unmaskValue());
    }

    function testCommaGroupSeparatorKeepsItsMeaning() {
        // As in gpui-kit: the comma is the group separator, removed and regrouped.
        final view = build(state -> state.withMaskPattern(Number(','.code, null)));
        typeText(view, "1234,5");
        assertEquals("12,345", view.state().value());
        assertEquals("12345", view.state().unmaskValue());

        final view = build(state -> state.withMaskPattern(Number(','.code, null)));
        typeText(view, "1234.5");
        assertEquals("1,234.5", view.state().value());
    }

    function testPasteTakesTheCommaLikeTyping() {
        final view = build(state -> state.withMaskPattern(Number(null, null)));
        paste(view, "3,25");
        assertEquals("3.25", view.state().value());

        final view = build(state -> state.withMaskPattern(Number(','.code, null)));
        paste(view, "1,234");
        assertEquals("1,234", view.state().value());
        assertEquals("1234", view.state().unmaskValue());
    }

    function testASecondDecimalSeparatorIsRefused() {
        final view = build(state -> state.withMaskPattern(Number(null, null)));
        typeText(view, "1,5");
        typeText(view, ",");
        assertEquals("1.5", view.state().value());
        typeText(view, ".");
        assertEquals("1.5", view.state().value());

        final view = build(state -> state.withMaskPattern(Number(null, null)));
        typeText(view, "1.5");
        typeText(view, ",");
        assertEquals("1.5", view.state().value());

        final view = build(state -> state.withMaskPattern(Number(null, null)));
        paste(view, "1,2,3");
        assertEquals("", view.state().value());
        paste(view, "1,2.3");
        assertEquals("", view.state().value());
    }

    function testIntegerFieldIsUnchanged() {
        // A comma group separator with fraction 0 (the integer field of
        // DEV-017): the comma stays a group separator and no decimal appears.
        final view = build(state -> state.withMaskPattern(Number(','.code, 0)));
        typeText(view, "12,5");
        assertEquals("125", view.state().value());
        typeText(view, "0");
        assertEquals("1,250", view.state().value());
        typeText(view, ".5");
        assertEquals("1,250", view.state().value());
    }

    function testInputsWithoutANumberMaskKeepTheComma() {
        final view = build();
        typeText(view, "1,5");
        assertEquals("1,5", view.state().value());
    }

    function testMaskRules() {
        final number:MaskPattern = Number(null, null);
        assertTrue(number.isValid("1,5"));
        assertTrue(number.isValid("-,5"));
        assertFalse(number.isValid("1,5,3"));
        assertFalse(number.isValid("1,5.3"));
        assertEquals("1.5", number.mask("1,5"));
        assertEquals("1.5", number.mask("1.5"));

        final grouped:MaskPattern = Number(','.code, null);
        assertTrue(grouped.isValid("1,234"));
        assertEquals("1,234", grouped.mask("1234"));
        assertEquals("1,234.5", grouped.mask("1,234.5"));

        assertTrue(MaskPatternTools.commaIsDecimal(null));
        assertTrue(MaskPatternTools.commaIsDecimal(' '.code));
        assertFalse(MaskPatternTools.commaIsDecimal(','.code));
        assertFalse(MaskPatternTools.commaIsDecimal('.'.code));
    }

}
