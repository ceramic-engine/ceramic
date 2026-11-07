// Ported from gpui-pre 0.3.10: src/text_system.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * An identifier for a specific glyph, as returned by `WindowTextSystem.layoutLine()`.
 */
abstract GlyphId(Int) from Int to Int {

    public inline function new(id:Int) {
        this = id;
    }

}
