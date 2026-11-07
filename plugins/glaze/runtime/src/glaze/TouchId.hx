// Ported from gpui-pre 0.3.10: src/interactive.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * Identifies one touch (finger or stylus contact) for its lifetime, from
 * `TouchPhase.Started` through `TouchPhase.Ended` or `TouchPhase.Cancelled`.
 *
 * The value is opaque and assigned by the platform. A platform window must
 * not reuse an identifier for a later touch.
 */
abstract TouchId(Int) from Int to Int {

    public inline function new(id:Int) {
        this = id;
    }

}
