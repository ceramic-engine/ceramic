// Ported from gpui-pre 0.3.10: src/platform/keyboard.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A dummy implementation of the platform keyboard mapper.
 */
class DummyKeyboardMapper implements PlatformKeyboardMapper {

    public static final instance:DummyKeyboardMapper = new DummyKeyboardMapper();

    public function new() {}

    public function mapKeyEquivalent(keystroke:Keystroke, useKeyEquivalents:Bool):KeybindingKeystroke {
        return KeybindingKeystroke.fromKeystroke(keystroke);
    }

    public function getKeyEquivalents():Null<Map<Int, Int>> {
        return null;
    }

}
