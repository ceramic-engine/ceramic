// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Range;

/**
 * Hover snapshot for one atomic inline token. Hover never selects or edits;
 * it reports pointer presence so the application can show a tooltip or run
 * custom logic.
 */
class InlineTokenHoverEvent {

    final span:InlineTokenSpan;
    final _bounds:Bounds;
    final hovered:Bool;
    final _rangeUtf16:Range;

    @:allow(glaze.kit.base.input)
    function new(span:InlineTokenSpan, bounds:Bounds, hovered:Bool, rangeUtf16:Range) {
        this.span = span;
        this._bounds = bounds;
        this.hovered = hovered;
        this._rangeUtf16 = rangeUtf16;
    }

    public inline function token():InlineToken {
        return span.token();
    }

    public inline function range():Range {
        return span.range();
    }

    public inline function bounds():Bounds {
        return _bounds;
    }

    /** Whether the pointer entered (`true`) or left (`false`) the token. */
    public inline function isHovered():Bool {
        return hovered;
    }

    /**
     * The token range in UTF-16 code units, captured when the event was
     * built (Rust `(usize, usize)`). Exits delivered after the text changed
     * report these entry coordinates, since the byte range can no longer be
     * converted against the current text.
     */
    public inline function rangeUtf16():Range {
        return _rangeUtf16;
    }

}
