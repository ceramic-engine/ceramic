// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

/**
 * Stable participant-defined identity for virtualized participant content.
 */
abstract TextSelectionContentKey(Int) {

    /** Creates a key from a participant-defined stable content identity. */
    public inline function new(value:Int) {
        this = value;
    }

    /** Returns the participant-defined value. */
    public inline function value():Int {
        return this;
    }

    @:op(A == B) static function eq(a:TextSelectionContentKey, b:TextSelectionContentKey):Bool;

    @:op(A != B) static function neq(a:TextSelectionContentKey, b:TextSelectionContentKey):Bool;

}
