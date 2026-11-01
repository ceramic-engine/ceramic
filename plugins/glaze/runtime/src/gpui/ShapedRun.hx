// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A run of text that has been shaped.
 */
class ShapedRun {

    /** The font id for this run */
    public var fontId:FontId;

    /** The glyphs that make up this run */
    public var glyphs:Array<ShapedGlyph>;

    public function new(fontId:FontId, ?glyphs:Array<ShapedGlyph>) {
        this.fontId = fontId;
        this.glyphs = glyphs != null ? glyphs : [];
    }

    public function clone():ShapedRun {
        return new ShapedRun(fontId, glyphs.copy());
    }

    public function toString():String {
        return 'ShapedRun($fontId, $glyphs)';
    }

}
