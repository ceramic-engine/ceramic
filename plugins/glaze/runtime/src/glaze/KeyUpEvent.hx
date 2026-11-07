// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The key up event equivalent for the platform.
 */
class KeyUpEvent extends PlatformInput {

    /** The keystroke that was released. */
    public var keystroke:Keystroke;

    public function new(keystroke:Keystroke) {
        super(KeyUp);
        this.keystroke = keystroke;
    }

}
