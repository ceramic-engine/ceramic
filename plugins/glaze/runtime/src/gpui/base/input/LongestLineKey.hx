// Ported from gpui-kit 0.8.1: crates/base/src/input/base/element.rs (`LongestLineKey`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Font;
import gpui.Pixels;

/**
 * What the unwrapped width of the longest line depends on. While it holds,
 * prepaint reuses the stored width instead of copying the line and asking
 * the text system for it again on every frame.
 */
class LongestLineKey {

    public final documentRevision:Int;

    public final row:Int;

    public final len:Int;

    public final font:Font;

    public final textSize:Pixels;

    public final wrapWidth:Null<Pixels>;

    public final tabSize:Int;

    public function new(documentRevision:Int, row:Int, len:Int, font:Font, textSize:Pixels, wrapWidth:Null<Pixels>, tabSize:Int) {
        this.documentRevision = documentRevision;
        this.row = row;
        this.len = len;
        this.font = font;
        this.textSize = textSize;
        this.wrapWidth = wrapWidth;
        this.tabSize = tabSize;
    }

    /** Rust `PartialEq` */
    public function equals(other:Null<LongestLineKey>):Bool {
        if (other == null)
            return false;
        final sameWrap = wrapWidth == null ? other.wrapWidth == null : (other.wrapWidth != null && (other.wrapWidth : Float) == (wrapWidth : Float));
        return other.documentRevision == documentRevision && other.row == row && other.len == len && other.font.equals(font)
            && (other.textSize : Float) == (textSize : Float) && sameWrap && other.tabSize == tabSize;
    }

}

/**
 * The cached unwrapped width of the longest line, with what it depends on
 * (Rust tuple `(LongestLineKey, Pixels)`).
 */
class LongestLineWidth {

    public final key:LongestLineKey;

    public final width:Pixels;

    public inline function new(key:LongestLineKey, width:Pixels) {
        this.key = key;
        this.width = width;
    }

}
