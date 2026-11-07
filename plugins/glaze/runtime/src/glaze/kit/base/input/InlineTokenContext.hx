// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Pixels;
import gpui.Range;

/**
 * Read-only context for a single inline renderer. Width is the full
 * available row. Presentation callbacks and measured geometry never enter
 * document history.
 */
class InlineTokenContext {

    final span:InlineTokenSpan;
    final selected:Bool;
    final disabled:Bool;
    final readonly:Bool;
    final _lineHeight:Pixels;
    final _availableWidth:Pixels;

    @:allow(gpui.base.input)
    function new(span:InlineTokenSpan, selected:Bool, disabled:Bool, readonly:Bool, lineHeight:Pixels, availableWidth:Pixels) {
        this.span = span;
        this.selected = selected;
        this.disabled = disabled;
        this.readonly = readonly;
        this._lineHeight = lineHeight;
        this._availableWidth = availableWidth;
    }

    public inline function token():InlineToken {
        return span.token();
    }

    public inline function range():Range {
        return span.range();
    }

    public inline function isSelected():Bool {
        return selected;
    }

    public inline function isDisabled():Bool {
        return disabled;
    }

    public inline function isReadonly():Bool {
        return readonly;
    }

    public inline function lineHeight():Pixels {
        return _lineHeight;
    }

    public inline function availableWidth():Pixels {
        return _availableWidth;
    }

}
