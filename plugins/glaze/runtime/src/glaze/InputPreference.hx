// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Whether a keystroke should prefer character input or key bindings.
 */
enum abstract InputPreference(Int) {

    /** Prefer typing text over triggering key bindings. */
    var CharacterInput = 0;

    /** Dispatch key bindings normally, if any match. */
    var KeyBindings = 1;

    public function toString():String {
        return switch (cast this : InputPreference) {
            case CharacterInput: 'CharacterInput';
            case KeyBindings: 'KeyBindings';
        }
    }

}
