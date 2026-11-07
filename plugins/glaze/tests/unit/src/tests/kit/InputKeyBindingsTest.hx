// New test for the Haxe port of gpui-kit 0.8.1: the input key bindings of crates/base/src/input/base/state.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.KeyBinding;
import glaze.OperatingSystem;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputKeyBindings;
import testing.TestCase;

/**
 * Checks the platform selection of `InputKeyBindings` against the Rust
 * `cfg` lists (not an upstream test: Rust picks them at compile time).
 */
class InputKeyBindingsTest extends TestCase {

    static function describe(bindings:Array<KeyBinding>):Array<String> {
        return [for (binding in bindings) [for (k in binding.keystrokes) k.unparse(Mac)].join(' ') + '=' + binding.action.name()];
    }

    /** A binding as `describe` prints it, keystrokes normalized like the bindings. */
    static function b(keystrokes:String, action:String):String {
        return glaze.Keystroke.parse(keystrokes).unparse(Mac) + '=' + action;
    }

    function testMacosBindings() {
        final list = describe(InputKeyBindings.bindings(Mac));
        // The Rust list has 59 bindings compiled for macOS.
        assertEquals(59, list.length);
        assertTrue(list.indexOf(b('ctrl-backspace', 'input::Backspace')) != -1);
        assertTrue(list.indexOf(b('cmd-a', 'input::SelectAll')) != -1);
        assertTrue(list.indexOf(b('ctrl-a', 'input::MoveHome')) != -1);
        assertTrue(list.indexOf(b('ctrl-e', 'input::MoveEnd')) != -1);
        assertTrue(list.indexOf(b('cmd-enter', 'input::Enter')) != -1);
        assertTrue(list.indexOf(b('alt-shift-left', 'input::SelectToPreviousWordStart')) != -1);
        assertTrue(list.indexOf(b('shift-left', 'ui::SelectLeft')) != -1);
        assertEquals(-1, list.indexOf(b('ctrl-z', 'input::Undo')));
        assertEquals(-1, list.indexOf(b('shift-alt-left', 'ui::SelectLeft')));
    }

    function testOtherPlatformBindings() {
        final windows = describe(InputKeyBindings.bindings(Windows));
        // 49 for Windows, 49 for Linux.
        assertEquals(49, windows.length);
        assertTrue(windows.indexOf(b('ctrl-backspace', 'input::DeleteToPreviousWordStart')) != -1);
        assertTrue(windows.indexOf(b('ctrl-enter', 'input::Enter')) != -1);
        assertTrue(windows.indexOf(b('ctrl-alt-up', 'input::AddCursorAbove')) != -1);
        assertTrue(windows.indexOf(b('shift-alt-left', 'ui::SelectLeft')) != -1);
        assertEquals(-1, windows.indexOf(b('alt-shift-left', 'input::SelectToPreviousWordStart')));

        final linux = describe(InputKeyBindings.bindings(Linux));
        assertEquals(49, linux.length);
        assertTrue(linux.indexOf(b('shift-alt-up', 'input::AddCursorAbove')) != -1);
        assertTrue(linux.indexOf(b('alt-shift-left', 'input::SelectToPreviousWordStart')) != -1);
        assertEquals(-1, linux.indexOf(b('shift-alt-left', 'ui::SelectLeft')));
    }

    function testEnterIsPrimary() {
        assertTrue(Enter.isPrimary(new Enter(false, false)));
        assertTrue(Enter.isPrimary(new Enter(false, true)));
        assertFalse(Enter.isPrimary(new Enter(true, false)));
        assertFalse(Enter.isPrimary(new Escape()));
    }

}
