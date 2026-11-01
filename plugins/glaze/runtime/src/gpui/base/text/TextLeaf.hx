// Ported from gpui-kit 0.8.1: crates/base/src/text/stream_fade.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.util.Utf8;

/** A block's rendered text, in the byte space its highlights use (Rust `TextLeaf`). */
enum TextLeaf {
    Paragraph(paragraph:gpui.base.text.Paragraph);
    Code(code:String);
}

class TextLeafTools {

    /** Rust `TextLeaf::chunks`. */
    public static function chunks(leaf:TextLeaf):Array<String> {
        return switch leaf {
            case Paragraph(paragraph): [for (node in paragraph.children_) node.text_];
            case Code(code): [code];
        }
    }

    public static function len(leaf:TextLeaf):Int {
        var len = 0;
        for (chunk in chunks(leaf)) len += Utf8.byteLength(chunk);
        return len;
    }

    /** The length of the rendered text `leaf` shares with `old`, on a char boundary of `leaf`. */
    public static function commonPrefixLen(leaf:TextLeaf, old:TextLeaf):Int {
        final own = chunks(leaf);
        final prefix = StreamFade.commonPrefixLenOfChunks(own, chunks(old));
        return StreamFade.floorCharBoundary(own, prefix);
    }

}

/** Rust `(TextLeafKey, TextLeaf<'a>)`. */
class KeyedTextLeaf {
    public final key:TextLeafKey;
    public final leaf:TextLeaf;

    public inline function new(key:TextLeafKey, leaf:TextLeaf) {
        this.key = key;
        this.leaf = leaf;
    }
}
