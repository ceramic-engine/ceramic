// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

/**
 * An opaque selection layer identifier. The default scope is `DEFAULT` (0).
 */
abstract TextSelectionScopeId(Int) {

    public static inline final DEFAULT:TextSelectionScopeId = cast 0;

    static var nextScopeId:Int = 1;

    inline function new(value:Int) {
        this = value;
    }

    /**
     * Allocates a process-unique scope identifier (Rust `TextSelectionScopeId::new`).
     *
     * Keep the returned identifier for the semantic lifetime of the scope; do
     * not allocate a new identifier on every frame.
     */
    public static function allocate():TextSelectionScopeId {
        final value = nextScopeId;
        if (value == 0x7fffffff) {
            throw 'text selection scope identifiers exhausted';
        }
        nextScopeId = value + 1;
        return new TextSelectionScopeId(value);
    }

    @:allow(tests)
    static inline function fromRaw(value:Int):TextSelectionScopeId {
        return new TextSelectionScopeId(value);
    }

    public inline function toInt():Int {
        return this;
    }

    @:op(A == B) static function eq(a:TextSelectionScopeId, b:TextSelectionScopeId):Bool;

    @:op(A != B) static function neq(a:TextSelectionScopeId, b:TextSelectionScopeId):Bool;

}
