// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_element.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Pixels;
import glaze.TextStyle;

/**
 * Inherited typography for a format-independent inline renderer.
 *
 * TextView builds this while laying a line out; renderers only read it.
 */
class InlineRenderContext {

    final textStyle_:TextStyle;
    final fontSize_:Pixels;
    final lineHeight_:Pixels;
    final remSize_:Pixels;

    @:allow(glaze.kit.base.text)
    function new(textStyle:TextStyle, fontSize:Pixels, lineHeight:Pixels, remSize:Pixels) {
        this.textStyle_ = textStyle;
        this.fontSize_ = fontSize;
        this.lineHeight_ = lineHeight;
        this.remSize_ = remSize;
    }

    /** Effective text style at the object's position, marks already applied. */
    public inline function textStyle():TextStyle {
        return textStyle_;
    }

    /** Font size of the surrounding text, in logical pixels. */
    public inline function fontSize():Pixels {
        return fontSize_;
    }

    /** Line height of the surrounding text, in logical pixels. */
    public inline function lineHeight():Pixels {
        return lineHeight_;
    }

    /** Root font size, for resolving rem-relative lengths. */
    public inline function remSize():Pixels {
        return remSize_;
    }

}
