// Ported from gpui-kit 0.8.1: crates/base/src/input/base/mask_pattern.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.base.input.MaskPattern;
import testing.TestCase;

/**
 * Tests of `gpui.base.input.MaskPattern` (Rust `mask_pattern.rs`).
 */
class InputMaskPatternTest extends TestCase {

    static function tokensEqual(expected:Array<MaskToken>, actual:Null<Array<MaskToken>>):Bool {
        if (actual == null || actual.length != expected.length) return false;
        for (i in 0...expected.length) {
            if (!expected[i].equals(actual[i])) return false;
        }
        return true;
    }

    function testIsMatch() {
        assertEquals(true, MaskToken.Sep('('.code).isMatch('('.code));
        assertEquals(false, MaskToken.Sep('-'.code).isMatch('('.code));
        assertEquals(false, MaskToken.Sep('-'.code).isMatch('3'.code));

        assertEquals(true, MaskToken.Digit.isMatch('0'.code));
        assertEquals(true, MaskToken.Digit.isMatch('9'.code));
        assertEquals(false, MaskToken.Digit.isMatch('a'.code));
        assertEquals(false, MaskToken.Digit.isMatch('C'.code));

        assertEquals(true, MaskToken.Letter.isMatch('a'.code));
        assertEquals(true, MaskToken.Letter.isMatch('Z'.code));
        assertEquals(false, MaskToken.Letter.isMatch('3'.code));
        assertEquals(false, MaskToken.Letter.isMatch('-'.code));

        assertEquals(true, MaskToken.LetterOrDigit.isMatch('0'.code));
        assertEquals(true, MaskToken.LetterOrDigit.isMatch('9'.code));
        assertEquals(true, MaskToken.LetterOrDigit.isMatch('a'.code));
        assertEquals(true, MaskToken.LetterOrDigit.isMatch('Z'.code));
        assertEquals(true, MaskToken.LetterOrDigit.isMatch('3'.code));

        assertEquals(true, MaskToken.Any.isMatch('a'.code));
        assertEquals(true, MaskToken.Any.isMatch('3'.code));
        assertEquals(true, MaskToken.Any.isMatch('-'.code));
        assertEquals(true, MaskToken.Any.isMatch(' '.code));
    }

    function testMaskNone() {
        final mask = MaskPattern.None;
        assertEquals(true, mask.isNone());
        assertEquals(true, mask.isValid("1124124ASLDJKljk"));
        assertEquals("hello-world", mask.mask("hello-world"));
        assertEquals("hello-world", mask.unmask("hello-world"));
    }

    function testMaskPattern1() {
        final mask = MaskPatternTools.create("(AA)999-999");
        assertTrue(tokensEqual([
            Sep('('.code), Letter, Letter, Sep(')'.code), Digit, Digit, Digit, Sep('-'.code), Digit, Digit, Digit,
        ], mask.tokens()));

        assertEquals(true, mask.isValidAt('('.code, 0));
        assertEquals(true, mask.isValidAt('H'.code, 0));
        assertEquals(false, mask.isValidAt('3'.code, 0));
        assertEquals(false, mask.isValidAt('-'.code, 0));
        assertEquals(false, mask.isValidAt(')'.code, 1));
        assertEquals(true, mask.isValidAt('H'.code, 1));
        assertEquals(false, mask.isValidAt('1'.code, 1));
        assertEquals(true, mask.isValidAt('e'.code, 2));
        assertEquals(true, mask.isValidAt(')'.code, 3));
        assertEquals(true, mask.isValidAt('1'.code, 3));
        assertEquals(true, mask.isValidAt('2'.code, 4));

        assertEquals(true, mask.isValid("(AB)123-456"));

        assertEquals("(AB)123-456", mask.mask("AB123456"));
        assertEquals("(AB)123-456", mask.mask("(AB)123-456"));
        assertEquals("(AB)123-456", mask.mask("(AB123456"));
        assertEquals("(AB)123-456", mask.mask("AB123-456"));
        assertEquals("(AB)123-", mask.mask("AB123-"));
        assertEquals("(AB)123-", mask.mask("AB123--"));
        assertEquals("(AB)123-4", mask.mask("AB123-4"));

        assertEquals("AB123456", mask.unmask("(AB)123-456"));

        assertEquals(false, mask.isValid("12AB345"));
        assertEquals(false, mask.isValid("(11)123-456"));
        assertEquals(false, mask.isValid("##"));
        assertEquals(true, mask.isValid("(AB)123456"));
    }

    function testMaskPattern2() {
        final mask = MaskPatternTools.create("999-999-******");
        assertTrue(tokensEqual([
            Digit, Digit, Digit, Sep('-'.code), Digit, Digit, Digit, Sep('-'.code), Any, Any, Any, Any, Any, Any,
        ], mask.tokens()));

        final text = "123456A(111)";
        final maskedText = mask.mask(text);
        assertEquals("123-456-A(111)", maskedText);
        assertEquals("123456A(111)", mask.unmask(maskedText));
        assertEquals(true, mask.isValid(maskedText));
    }

    function testIsValidWithNonAsciiText() {
        var mask = MaskPatternTools.create("9999年99月");
        assertEquals(true, mask.isValid("2024年"));
        assertEquals(true, mask.isValid("2024年12月"));
        assertEquals(false, mask.isValid("2024年1x"));

        mask = MaskPatternTools.create("*999");
        assertEquals(true, mask.isValid("€"));
        assertEquals(true, mask.isValid("€123"));
    }

    function testNumberWithGroupSeparator() {
        // Use comma as group separator
        var mask = MaskPatternTools.number(','.code);
        assertEquals("1,234,567", mask.mask("1234567"));
        assertEquals("1,234,567", mask.mask("1,234,567"));
        assertEquals("1234567", mask.unmask("1,234,567"));
        mask = MaskPatternTools.number(','.code);
        assertEquals("1,234,567.89", mask.mask("1234567.89"));
        assertEquals("1234567.89", mask.unmask("1,234,567.89"));

        // Use space as group separator
        mask = MaskPatternTools.number(' '.code);
        assertEquals("1 234 567", mask.mask("1234567"));
        assertEquals("1234567", mask.unmask("1 234 567"));
        mask = MaskPatternTools.number(' '.code);
        assertEquals("1 234 567.89", mask.mask("1234567.89"));
        assertEquals("1234567.89", mask.unmask("1 234 567.89"));

        // No group separator
        mask = MaskPatternTools.number(null);
        assertEquals("1234567", mask.mask("1234567"));
        assertEquals("1234567", mask.unmask("1234567"));
        mask = MaskPatternTools.number(null);
        assertEquals("1234567.89", mask.mask("1234567.89"));
        assertEquals("1234567.89", mask.unmask("1234567.89"));
    }

    function testNumberWithFractionDigits() {
        var mask = MaskPattern.Number(','.code, 4);

        assertEquals("1,234,567", mask.mask("1234567"));
        assertEquals("1234567", mask.unmask("1,234,567"));
        assertEquals("1,234,567.", mask.mask("1234567."));
        assertEquals("1,234,567.89", mask.mask("1234567.89"));
        assertEquals("1234567.89", mask.unmask("1,234,567.890"));
        assertEquals("1,234,567.891", mask.mask("1234567.891"));
        assertEquals("1,234,567.8912", mask.mask("1234567.891234"));

        mask = MaskPattern.Number(','.code, null);
        assertEquals("1,234,567.1234567", mask.mask("1234567.1234567"));

        mask = MaskPattern.Number(','.code, 0);
        assertEquals("1,234,567", mask.mask("1234567.1234567"));
    }

    function testSignedNumberNumbers() {
        final mask = MaskPattern.Number(','.code, 2);

        assertEquals(true, mask.isValid("-"));
        assertEquals(true, mask.isValid("-1234567"));
        assertEquals(true, mask.isValid("-1,234,567"));
        assertEquals(true, mask.isValid("-1234567."));
        assertEquals(true, mask.isValid("-1234567.89"));

        assertEquals(true, mask.isValid("+"));
        assertEquals(true, mask.isValid("+1234567"));
        assertEquals(true, mask.isValid("+1,234,567"));
        assertEquals(true, mask.isValid("+1234567."));
        assertEquals(true, mask.isValid("+1234567.89"));

        // Only one sign is valid
        assertEquals(false, mask.isValid("+-"));
        assertEquals(false, mask.isValid("-+"));
        assertEquals(false, mask.isValid("+-1234567"));

        // No sign is valid in the middle of the number
        assertEquals(false, mask.isValid("1,-234,567"));
        assertEquals(false, mask.isValid("12-34567.89"));

        // Signs in fractions are invalid
        assertEquals(false, mask.isValid("+1234567.-"));

        // The separator does not show up before the sign i.e. -,123
        assertEquals("-123", mask.mask("-123"));

        assertEquals("-1,234,567", mask.mask("-1234567"));
        assertEquals("+1,234,567", mask.mask("+1234567"));
        assertEquals("-1234567", mask.unmask("-1,234,567"));
        assertEquals("-1,234,567.", mask.mask("-1234567."));
        assertEquals("-1,234,567.89", mask.mask("-1234567.89"));
    }

    function testNumberLeadingDot() {
        var mask = MaskPatternTools.number(null);
        assertEquals(true, mask.isValid("."));
        assertEquals(true, mask.isValid(".5"));
        assertEquals(true, mask.isValid("-."));
        assertEquals(true, mask.isValid("-.5"));
        assertEquals(false, mask.isValid("1.2.3"));
        assertEquals(false, mask.isValid("1.."));

        // A bare leading dot is kept as-is (not completed to "0."), so that
        // deleting the integer part of "1.2" keeps ".2" and stays editable.
        assertEquals(".", mask.mask("."));
        assertEquals(".5", mask.mask(".5"));
        assertEquals("-.5", mask.mask("-.5"));
        assertEquals("+.5", mask.mask("+.5"));

        mask = MaskPatternTools.number(','.code);
        assertEquals(".5", mask.mask(".5"));
        assertEquals("-.5", mask.mask("-.5"));
    }

    function testNormalizeNumberInput() {
        // Fast path: the same string when nothing to normalize
        final text = "-1,234.5";
        assertTrue(MaskPatternTools.normalizeNumberInput(text) == text);

        // Full-width digits (the upstream test passes ASCII digits here)
        assertEquals("0123456789", MaskPatternTools.normalizeNumberInput("0123456789"));
        // Full-width signs, dot and comma
        assertEquals("+1.5", MaskPatternTools.normalizeNumberInput("\u{FF0B}1\u{FF0E}5"));
        assertEquals("-1,234", MaskPatternTools.normalizeNumberInput("\u{FF0D}1\u{FF0C}234"));
        // Minus sign (U+2212)
        assertEquals("-1.5", MaskPatternTools.normalizeNumberInput("\u{2212}1.5"));
        // Ideographic full stop
        assertEquals("12.5", MaskPatternTools.normalizeNumberInput("12\u{3002}5"));
        // Other characters are kept as-is
        assertEquals("ab 中 1", MaskPatternTools.normalizeNumberInput("ab 中 1"));
    }

}
