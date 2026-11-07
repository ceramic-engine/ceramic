package tests;

import gpui.InvalidKeystrokeError;
import gpui.KeyBinding;
import gpui.KeybindingKeystroke;
import gpui.Keystroke;
import gpui.Modifiers;
import gpui.NoAction;
import gpui.OperatingSystem;
import testing.TestCase;

/**
 * Behaviour of gpui-pre 0.3.10: src/platform/keystroke.rs. That file has no
 * `#[cfg(test)]` module: these checks follow the Rust code path by path
 * (parse, unparse, display, matching, IME helpers).
 */
class KeystrokeTest extends TestCase {

    var previousOs:OperatingSystem;

    override function setup() {
        previousOs = OperatingSystem.current;
        OperatingSystem.current = Mac;
    }

    override function teardown() {
        OperatingSystem.current = previousOs;
    }

    function testParseModifiers() {
        final k = Keystroke.parse('ctrl-alt-shift-cmd-fn-a');
        assertTrue(k.modifiers.control);
        assertTrue(k.modifiers.alt);
        assertTrue(k.modifiers.shift);
        assertTrue(k.modifiers.platform);
        assertTrue(k.modifiers.function_);
        assertEquals('a', k.key);
        assertEquals(null, k.keyChar);
        assertEquals(5, k.modifiers.numberOfModifiers());

        // Case insensitive modifiers and keys, super / win are platform
        final k2 = Keystroke.parse('CTRL-Super-Tab');
        assertTrue(k2.modifiers == Modifiers.of(true, false, false, true));
        assertEquals('tab', k2.key);
        assertTrue(Keystroke.parse('win-x').modifiers == Modifiers.command());

        // A single upper case letter is shift + lower case
        final upper = Keystroke.parse('A');
        assertTrue(upper.modifiers == Modifiers.shiftKey());
        assertEquals('a', upper.key);

        // Non ASCII keys are kept as is
        assertEquals('ß', Keystroke.parse('alt-ß').key);
        assertEquals('Ä', Keystroke.parse('Ä').key);
    }

    function testParseDashAndModifierKeys() {
        final minus = Keystroke.parse('-');
        assertEquals('-', minus.key);
        assertTrue(minus.modifiers == Modifiers.none());

        final ctrlMinus = Keystroke.parse('ctrl--');
        assertEquals('-', ctrlMinus.key);
        assertTrue(ctrlMinus.modifiers == Modifiers.controlKey());

        // A modifier alone is the key, and the modifier is cleared
        final shift = Keystroke.parse('shift');
        assertEquals('shift', shift.key);
        assertTrue(shift.modifiers == Modifiers.none());

        final ctrl = Keystroke.parse('ctrl');
        assertEquals('control', ctrl.key);

        final cmd = Keystroke.parse('cmd');
        assertEquals('platform', cmd.key);

        final fn = Keystroke.parse('fn');
        assertEquals('function', fn.key);

        // Only the first modifier in shift, control, alt, platform, function order becomes the key
        final ctrlShift = Keystroke.parse('ctrl-shift');
        assertEquals('shift', ctrlShift.key);
        assertTrue(ctrlShift.modifiers == Modifiers.controlKey());
    }

    function testParseKeyChar() {
        final k = Keystroke.parse('alt-s->ß');
        assertEquals('s', k.key);
        assertEquals('ß', k.keyChar);
        assertTrue(k.modifiers == Modifiers.altKey());

        // `->` needs a character after it
        assertRaises(() -> Keystroke.parse('a->'));
    }

    function testParseErrors() {
        assertRaises(() -> Keystroke.parse('a-b'));
        // An empty source is an empty key, not an error (like Rust)
        assertEquals('', Keystroke.parse('').key);
        var error:InvalidKeystrokeError = null;
        try {
            Keystroke.parse('a-b');
        }
        catch (e:InvalidKeystrokeError) {
            error = e;
        }
        assertNotNull(error);
        assertEquals('a-b', error.keystroke);
        assertEquals('Invalid keystroke "a-b". ' + InvalidKeystrokeError.KEYSTROKE_PARSE_EXPECTED_MESSAGE, error.message);
        // `secondary` needs an operating system
        assertRaises(() -> Keystroke.parse('secondary-s'));
        assertEquals(null, Keystroke.tryParse('secondary-s'));
    }

    function testSecondary() {
        assertTrue(Keystroke.parseWithOs('secondary-s', Mac).modifiers == Modifiers.command());
        assertTrue(Keystroke.parseWithOs('secondary-s', Linux).modifiers == Modifiers.controlKey());
        assertTrue(Keystroke.parseWithOs('secondary-s', Windows).modifiers == Modifiers.controlKey());

        assertTrue(Modifiers.command().secondary(Mac));
        assertFalse(Modifiers.command().secondary(Linux));
        assertTrue(Modifiers.controlKey().secondary(Windows));
        assertTrue(Modifiers.secondaryKey(Mac) == Modifiers.command());
        assertTrue(Modifiers.secondaryKey(Linux) == Modifiers.controlKey());

        // KeyBinding.load resolves `secondary` with the given OS
        final binding = KeyBinding.load('secondary-s', new NoAction(), null, false, null, null, Linux);
        assertTrue(binding.keystrokes[0].inner().modifiers == Modifiers.controlKey());
        // KeyBinding.new does not accept it, like GPUI
        assertRaises(() -> new KeyBinding('secondary-s', new NoAction()));
    }

    function testUnparse() {
        final k = Keystroke.parse('shift-cmd-alt-ctrl-fn-k');
        assertEquals('fn-ctrl-alt-cmd-shift-k', k.unparse(Mac));
        assertEquals('fn-ctrl-alt-cmd-shift-k', k.unparse(Ios));
        assertEquals('fn-ctrl-alt-win-shift-k', k.unparse(Windows));
        assertEquals('fn-ctrl-alt-super-shift-k', k.unparse(Linux));
        assertEquals('fn-ctrl-alt-super-shift-k', k.unparse(Unknown));
    }

    function testDisplay() {
        assertEquals('^⌥⌘⇧K', Keystroke.parse('ctrl-alt-cmd-shift-k').display(Mac));
        assertEquals('ctrl-alt-⊞shift-K', Keystroke.parse('ctrl-alt-cmd-shift-k').display(Windows));
        assertEquals('❖K', Keystroke.parse('cmd-k').display(Linux));
        assertEquals('cmd-K', Keystroke.parse('cmd-k').display(Unknown));
        assertEquals('⌘⌫', Keystroke.parse('cmd-backspace').display(Mac));
        assertEquals('backspace', Keystroke.parse('backspace').display(Linux));
        assertEquals('⇥', Keystroke.parse('tab').display(Mac));
        assertEquals('⌘', Keystroke.parse('cmd').display(Mac));
        assertEquals('f12', Keystroke.parse('f12').display(Mac));
        assertEquals('ß', Keystroke.parse('ß').display(Mac));
        assertEquals('⌘K', KeybindingKeystroke.fromKeystroke(Keystroke.parse('cmd-k')).display(Mac));
    }

    function testShouldMatch() {
        final target = (s:String) -> KeybindingKeystroke.fromKeystroke(Keystroke.parse(s));

        // Plain match
        assertTrue(Keystroke.parse('ctrl-a').shouldMatch(target('ctrl-a')));
        assertFalse(Keystroke.parse('ctrl-a').shouldMatch(target('a')));

        // The typed character matches when only ctrl / cmd are kept
        final altS = Keystroke.parse('alt-s->ß');
        assertTrue(altS.shouldMatch(target('ß')));
        assertTrue(altS.shouldMatch(target('alt-s')));
        assertFalse(altS.shouldMatch(target('alt-ß')));

        final cmdAltS = Keystroke.parse('cmd-alt-s->ß');
        assertTrue(cmdAltS.shouldMatch(target('cmd-ß')));

        // A keyChar equal to the key is ignored
        assertFalse(Keystroke.parse('shift-a->a').shouldMatch(target('a')));

        // Windows: the keyChar matches a target without modifiers only
        OperatingSystem.current = Windows;
        assertFalse(cmdAltS.shouldMatch(target('cmd-ß')));
        assertTrue(cmdAltS.shouldMatch(target('ß')));
        OperatingSystem.current = Mac;
    }

    function testImeHelpers() {
        assertTrue(Keystroke.parse('a').isImeInProgress());
        assertTrue(Keystroke.parse('shift-a').isImeInProgress());
        assertFalse(Keystroke.parse('a->a').isImeInProgress());
        assertFalse(Keystroke.parse('ctrl-a').isImeInProgress());
        assertFalse(Keystroke.parse('left').isImeInProgress());

        assertEquals(' ', Keystroke.parse('space').withSimulatedIme().keyChar);
        assertEquals('\t', Keystroke.parse('tab').withSimulatedIme().keyChar);
        assertEquals('\n', Keystroke.parse('enter').withSimulatedIme().keyChar);
        assertEquals('A', Keystroke.parse('shift-a').withSimulatedIme().keyChar);
        assertEquals('a', Keystroke.parse('a').withSimulatedIme().keyChar);
        assertEquals(null, Keystroke.parse('escape').withSimulatedIme().keyChar);
        assertEquals(null, Keystroke.parse('cmd-a').withSimulatedIme().keyChar);
        assertEquals('ß', Keystroke.parse('alt-s->ß').withSimulatedIme().keyChar);
    }

    function testModifiers() {
        final m = Modifiers.controlKey() | Modifiers.shiftKey();
        assertTrue(m == Modifiers.controlShift());
        assertTrue(Modifiers.controlKey().isSubsetOf(m));
        assertFalse(m.isSubsetOf(Modifiers.controlKey()));
        assertTrue((m & Modifiers.shiftKey()) == Modifiers.shiftKey());
        assertTrue((m ^ Modifiers.shiftKey()) == Modifiers.controlKey());
        assertTrue(m.modified());
        assertFalse(Modifiers.none().modified());
        assertEquals(2, m.numberOfModifiers());
        assertTrue(Modifiers.commandShift() == Modifiers.of(false, false, true, true));
        assertTrue(Modifiers.functionKey().function_);
        assertTrue(Modifiers.superKey() == Modifiers.windows());
    }

}
