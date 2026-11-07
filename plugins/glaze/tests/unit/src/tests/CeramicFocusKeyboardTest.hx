package tests;

import ceramic.VirtualKeyboardText;
import ceramic.VirtualKeyboardType;
import ceramic.WindowFocusTracker;
import testing.TestCase;

/**
 * Tests of the backend independent helpers of Ceramic behind the window
 * focus and the virtual keyboard of the Unity backend (STATUS item 11,
 * docs/UNITY.md "Focus and virtual keyboard"): `WindowFocusTracker` (focus,
 * pause, Android's keyboard taking the focus), `VirtualKeyboardType` (the
 * keyboard for `setTextEditingConfiguration`) and `VirtualKeyboardText`
 * (edits of the hidden field of the keyboard turned into caret moves,
 * deletions and text).
 */
class CeramicFocusKeyboardTest extends TestCase {

    static final PAD = [for (_ in 0...VirtualKeyboardText.PADDING_LENGTH) ' '].join('');

    static final GRIN = String.fromCharCode(0x1F600);

    static final BEAM = String.fromCharCode(0x1F601);

    // WindowFocusTracker

    function testFocusFollowsTheSystem() {

        final t = new WindowFocusTracker(true);
        assertTrue(t.focused);
        assertTrue(t.setSystemFocused(false));
        assertFalse(t.focused);
        assertFalse(t.setSystemFocused(false), 'same value: no change');
        assertTrue(t.setSystemFocused(true));
        assertTrue(t.focused);

        final unfocused = new WindowFocusTracker(false);
        assertFalse(unfocused.focused);

    }

    function testPausedIsNeverFocused() {

        final t = new WindowFocusTracker(true);
        assertTrue(t.setPaused(true));
        assertFalse(t.focused);
        assertFalse(t.setSystemFocused(true), 'focus while paused: still not focused');
        assertTrue(t.setPaused(false));
        assertTrue(t.focused);

        // Paused, the focus went away in the meantime
        t.setPaused(true);
        t.setSystemFocused(false);
        assertFalse(t.setPaused(false));
        assertFalse(t.focused);

    }

    function testKeyboardKeepsTheFocus() {

        final t = new WindowFocusTracker(true);
        assertFalse(t.setKeyboardVisible(true));
        // Android: the keyboard takes the focus of the app
        assertFalse(t.setSystemFocused(false));
        assertTrue(t.focused);
        // Hidden while the system still says unfocused: focus lost
        assertTrue(t.setKeyboardVisible(false));
        assertFalse(t.focused);

        // Keyboard hidden after the focus came back
        t.setSystemFocused(true);
        t.setKeyboardVisible(true);
        t.setSystemFocused(false);
        t.setSystemFocused(true);
        assertFalse(t.setKeyboardVisible(false));
        assertTrue(t.focused);

        // Background with the keyboard visible
        t.setKeyboardVisible(true);
        assertTrue(t.setPaused(true));
        assertFalse(t.focused);

    }

    // VirtualKeyboardType

    function testKeyboardTypeFromConfiguration() {

        assertEquals(VirtualKeyboardType.DEFAULT, VirtualKeyboardType.fromConfiguration('text', null));
        assertEquals(VirtualKeyboardType.NUMBER_PAD, VirtualKeyboardType.fromConfiguration('numeric', 'done'));
        assertEquals(VirtualKeyboardType.DECIMAL_PAD, VirtualKeyboardType.fromConfiguration('decimal', null));
        assertEquals(VirtualKeyboardType.PHONE_PAD, VirtualKeyboardType.fromConfiguration('tel', null));
        assertEquals(VirtualKeyboardType.EMAIL, VirtualKeyboardType.fromConfiguration('email', 'next'));
        assertEquals(VirtualKeyboardType.URL, VirtualKeyboardType.fromConfiguration('url', 'go'));
        assertEquals(VirtualKeyboardType.SEARCH, VirtualKeyboardType.fromConfiguration('search', null));
        assertEquals(VirtualKeyboardType.SEARCH, VirtualKeyboardType.fromConfiguration('text', 'search'));
        assertEquals(VirtualKeyboardType.NONE, VirtualKeyboardType.fromConfiguration('none', null));
        assertEquals(VirtualKeyboardType.DEFAULT, VirtualKeyboardType.fromConfiguration('unknown', 'send'));

        assertTrue(VirtualKeyboardType.multilineFromConfiguration(null));
        assertTrue(VirtualKeyboardType.multilineFromConfiguration('enter'));
        for (hint in ['done', 'go', 'next', 'previous', 'search', 'send']) {
            assertFalse(VirtualKeyboardType.multilineFromConfiguration(hint), hint);
        }

    }

    // VirtualKeyboardText

    function recorder(ops:Array<String>):VirtualKeyboardText {

        final k = new VirtualKeyboardText();
        k.onMove = n -> ops.push('move $n');
        k.onDelete = n -> ops.push('delete $n');
        k.onInsert = text -> ops.push('insert $text');
        k.onLineBreak = () -> ops.push('break');
        return k;

    }

    function testKeyboardTextStartsWithPadding() {

        final k = new VirtualKeyboardText();
        assertEquals(PAD, k.text);
        assertEquals(PAD.length, k.caret);
        assertTrue(k.text.length > k.minPadding);

    }

    function testKeyboardTextTyping() {

        final ops = [];
        final k = recorder(ops);
        assertFalse(k.update(PAD + 'h', PAD.length + 1, 0));
        assertFalse(k.update(PAD + 'hi', PAD.length + 2, 0));
        // Without selection from the platform
        assertFalse(k.update(PAD + 'hi!', -1, 0));
        assertFalse(k.update(PAD + 'hi! ', -1, 0));
        assertEquals('insert h|insert i|insert !|insert  ', ops.join('|'));
        assertEquals(PAD.length + 4, k.caret);
        // Nothing changed
        ops.resize(0);
        assertFalse(k.update(PAD + 'hi! ', PAD.length + 4, 0));
        assertEquals('', ops.join('|'));

    }

    function testKeyboardTextBackspace() {

        final ops = [];
        final k = recorder(ops);
        k.update(PAD + 'ab', PAD.length + 2, 0);
        k.update(PAD + 'a', PAD.length + 1, 0);
        k.update(PAD, PAD.length, 0);
        // Backspace in the empty app field still deletes a padding space
        k.update(PAD.substr(1), PAD.length - 1, 0);
        k.update(PAD.substr(3), -1, 0);
        assertEquals('insert ab|delete 1|delete 1|delete 1|delete 2', ops.join('|'));

    }

    function testKeyboardTextEmoji() {

        final ops = [];
        final k = recorder(ops);
        k.update(PAD + GRIN, PAD.length + 2, 0);
        // Same high surrogate: the pair is replaced as a whole
        k.update(PAD + BEAM, PAD.length + 2, 0);
        k.update(PAD, PAD.length, 0);
        assertEquals('insert $GRIN|delete 1|insert $BEAM|delete 1', ops.join('|'));

    }

    function testKeyboardTextAutocorrection() {

        final ops = [];
        final k = recorder(ops);
        k.update(PAD + 'teh', PAD.length + 3, 0);
        ops.resize(0);
        // The space ends the word and the keyboard replaces it
        k.update(PAD + 'the ', PAD.length + 4, 0);
        assertEquals('delete 2|insert he ', ops.join('|'));
        assertEquals(PAD.length + 4, k.caret);

    }

    function testKeyboardTextCaretMoves() {

        final ops = [];
        final k = recorder(ops);
        k.update(PAD + 'abc', PAD.length + 3, 0);
        ops.resize(0);
        k.update(PAD + 'abc', PAD.length + 1, 0);
        assertEquals('move -2', ops.join('|'));
        ops.resize(0);
        // Typed at the caret
        k.update(PAD + 'aXbc', PAD.length + 2, 0);
        assertEquals('insert X', ops.join('|'));
        ops.resize(0);
        // Deleted forward of the old caret: move then delete
        k.update(PAD + 'aXc', PAD.length + 2, 0);
        assertEquals('move 1|delete 1', ops.join('|'));
        ops.resize(0);
        // Back to the end
        k.update(PAD + 'aXc', PAD.length + 3, 0);
        assertEquals('move 1', ops.join('|'));
        ops.resize(0);
        // A non empty selection is not reported
        k.update(PAD + 'aXc', PAD.length, 3);
        assertEquals('', ops.join('|'));
        assertEquals(PAD.length + 3, k.caret);

    }

    function testKeyboardTextRepeatedCharacters() {

        final ops = [];
        final k = recorder(ops);
        k.update(PAD + 'aa', PAD.length + 2, 0);
        k.update(PAD + 'aa', PAD.length + 1, 0);
        ops.resize(0);
        // An 'a' typed between the two: placed at the caret, no extra moves
        k.update(PAD + 'aaa', PAD.length + 2, 0);
        assertEquals('insert a', ops.join('|'));
        assertEquals(PAD.length + 2, k.caret);

    }

    function testKeyboardTextLineBreaks() {

        final ops = [];
        final k = recorder(ops);
        k.update(PAD + 'a\nb', -1, 0);
        k.update(PAD + 'a\nb\r\n', -1, 0);
        k.update(PAD + 'a\nb\r\n\n', -1, 0);
        assertEquals('insert a|break|insert b|break|break', ops.join('|'));

    }

    function testKeyboardTextAsksForReset() {

        final ops = [];
        final k = recorder(ops);
        // Close to the start of the field
        assertFalse(k.update(PAD.substr(PAD.length - k.minPadding), k.minPadding, 0));
        assertTrue(k.update(PAD.substr(PAD.length - k.minPadding + 1), k.minPadding - 1, 0));
        k.reset();
        assertEquals(PAD, k.text);
        // Too long
        final long = [for (_ in 0...k.maxLength) 'x'].join('');
        assertTrue(k.update(PAD + long, -1, 0));
        k.reset();
        assertFalse(k.update(PAD + 'y', -1, 0));

    }

    function testGraphemeCount() {

        final count = VirtualKeyboardText.graphemeCount;
        assertEquals(3, count('abc', 0, 3));
        assertEquals(1, count('abc', 1, 2));
        assertEquals(1, count(GRIN, 0, 2));
        assertEquals(1, count('e' + String.fromCharCode(0x301), 0, 2));
        // Family: man ZWJ woman ZWJ girl
        final family = String.fromCharCode(0x1F468) + String.fromCharCode(0x200D) + String.fromCharCode(0x1F469) + String.fromCharCode(0x200D) + String.fromCharCode(0x1F467);
        assertEquals(1, count(family, 0, family.length));
        // Thumbs up with a skin tone, heart with a variation selector
        assertEquals(1, count(String.fromCharCode(0x1F44D) + String.fromCharCode(0x1F3FD), 0, 4));
        assertEquals(1, count(String.fromCharCode(0x2764) + String.fromCharCode(0xFE0F), 0, 2));
        // Two flags (four regional indicators)
        final fr = String.fromCharCode(0x1F1EB) + String.fromCharCode(0x1F1F7);
        assertEquals(1, count(fr, 0, fr.length));
        assertEquals(2, count(fr + fr, 0, fr.length * 2));
        assertEquals(1, count('\r\n', 0, 2));
        assertEquals(2, count('\n\r', 0, 2));

    }

}
