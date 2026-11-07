// Ported from gpui-pre 0.3.10: src/key_dispatch.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.keymap;

import glaze.KeyBinding;
import glaze.Keystroke;

/**
 * A keystroke to replay, with the bindings it matches (empty: replay it as a
 * plain key event).
 */
class Replay {

    public var keystroke:Keystroke;

    public var bindings:Array<KeyBinding>;

    public function new(keystroke:Keystroke, ?bindings:Array<KeyBinding>) {
        this.keystroke = keystroke;
        this.bindings = bindings != null ? bindings : [];
    }

}
