// Ported from gpui-kit 0.8.1: crates/base/src/input/base/selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * Unique identifier for a cursor/selection (Rust `selection::CursorId`).
 */
abstract CursorId(Int) {

    public inline function new(id:Int) {
        this = id;
    }

    /** `CursorId::default()`. */
    public static inline function defaultValue():CursorId {
        return new CursorId(0);
    }

    public inline function toInt():Int {
        return this;
    }

    @:op(A == B) static function eq(a:CursorId, b:CursorId):Bool;

    @:op(A != B) static function neq(a:CursorId, b:CursorId):Bool;

}
