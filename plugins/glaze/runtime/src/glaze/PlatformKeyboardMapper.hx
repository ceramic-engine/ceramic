// Ported from gpui-pre 0.3.10: src/platform/keyboard.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Platform-specific keyboard mappings.
 */
interface PlatformKeyboardMapper {

    /**
     * Map a key equivalent to its platform-specific representation.
     */
    function mapKeyEquivalent(keystroke:Keystroke, useKeyEquivalents:Bool):KeybindingKeystroke;

    /**
     * Get the key equivalents for the current keyboard layout (character code
     * to character code), only used on macOS.
     */
    function getKeyEquivalents():Null<Map<Int, Int>>;

}
