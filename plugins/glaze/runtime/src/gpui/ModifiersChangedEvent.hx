// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The modifiers changed event equivalent for the platform.
 * Rust's `Capslock { on }` is the boolean `capslock`.
 */
class ModifiersChangedEvent extends PlatformInput {

    /** The new state of the modifier keys */
    public var modifiers:Modifiers;

    /** The new state of the capslock key */
    public var capslock:Bool;

    public function new(modifiers:Modifiers, capslock:Bool = false) {
        super(ModifiersChanged);
        this.modifiers = modifiers;
        this.capslock = capslock;
    }

}
