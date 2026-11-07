// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A single glyph, ready to paint.
 */
class ShapedGlyph {

    /** The ID for this glyph, as determined by the text system. */
    public var id:GlyphId;

    /** The position of this glyph in its containing line. */
    public var position:Point;

    /** The index of this glyph in the original text. */
    public var index:Int;

    /** Whether this glyph is an emoji */
    public var isEmoji:Bool;

    public inline function new(id:GlyphId, position:Point, index:Int, isEmoji:Bool = false) {
        this.id = id;
        this.position = position;
        this.index = index;
        this.isEmoji = isEmoji;
    }

    public function toString():String {
        return 'ShapedGlyph($id, ${position.x}, ${position.y}, $index${isEmoji ? ', emoji' : ''})';
    }

}
