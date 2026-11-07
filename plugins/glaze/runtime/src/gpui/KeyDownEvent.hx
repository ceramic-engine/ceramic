// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The key down event equivalent for the platform.
 */
class KeyDownEvent extends PlatformInput {

    /** The keystroke that was generated. */
    public var keystroke:Keystroke;

    /** Whether the key is currently held down. */
    public var isHeld:Bool;

    /** Whether to prefer character input over keybindings for this keystroke. */
    public var preferCharacterInput:Bool;

    public function new(keystroke:Keystroke, isHeld:Bool = false, preferCharacterInput:Bool = false) {
        super(KeyDown);
        this.keystroke = keystroke;
        this.isHeld = isHeld;
        this.preferCharacterInput = preferCharacterInput;
    }

}
