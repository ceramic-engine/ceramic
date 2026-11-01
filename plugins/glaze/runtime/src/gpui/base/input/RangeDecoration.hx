// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Hsla;
import gpui.Range;

/**
 * A geometric decoration over a UTF-8 byte range.
 */
class RangeDecoration implements TrackedDecoration {

    var _range:Range;

    var _style:RangeDecorationStyle;

    var _color:Null<Hsla>;

    /** Create a frame using the editor foreground color. */
    public function new(range:Range) {
        _range = range;
        _style = RangeDecorationStyle.defaultValue();
        _color = null;
    }

    /** The half-open UTF-8 byte range supplied to this decoration. */
    public inline function range():Range {
        return _range;
    }

    /** The geometric paint style. */
    public inline function style():RangeDecorationStyle {
        return _style;
    }

    /** An application-owned color override, or null for the editor fallback. */
    public inline function color():Null<Hsla> {
        return _color;
    }

    /** Choose a fill or frame without changing text layout. */
    public function withStyle(style:RangeDecorationStyle):RangeDecoration {
        _style = style;
        return this;
    }

    /** Override the editor foreground fallback with an application-owned color. */
    public function withColor(color:Hsla):RangeDecoration {
        _color = color;
        return this;
    }

    public function getRange():Range {
        return _range;
    }

    public function setRange(range:Range):Void {
        _range = range;
    }

    public function equals(other:RangeDecoration):Bool {
        return other != null && _range.equals(other._range) && _style == other._style
            && (_color == null ? other._color == null : _color.equals(other._color));
    }

}
