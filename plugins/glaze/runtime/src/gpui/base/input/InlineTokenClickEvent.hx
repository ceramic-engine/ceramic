// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Bounds;
import gpui.ClickEvent;
import gpui.Range;

/**
 * Current token snapshot delivered after releasing the editor's update
 * borrow.
 */
class InlineTokenClickEvent {

    final span:InlineTokenSpan;
    final _bounds:Bounds;
    final event:ClickEvent;

    @:allow(gpui.base.input)
    function new(span:InlineTokenSpan, bounds:Bounds, event:ClickEvent) {
        this.span = span;
        this._bounds = bounds;
        this.event = event;
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

    /** The click that opened the token; keyboard activation reports a keyboard click. */
    public inline function click():ClickEvent {
        return event;
    }

}
