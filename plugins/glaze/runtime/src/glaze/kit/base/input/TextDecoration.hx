// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/decorations.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.HighlightStyle;
import glaze.Range;

/**
 * A presentation style applied to a UTF-8 byte range in an input.
 *
 * This is the GPUI `HighlightStyle` counterpart of Monaco's `IModelDeltaDecoration`.
 */
class TextDecoration implements TrackedDecoration {

    public var range:Range;

    public var style:HighlightStyle;

    /** Create a text decoration from a UTF-8 byte range and a GPUI style. */
    public function new(range:Range, style:HighlightStyle) {
        this.range = range;
        this.style = style;
    }

    public function getRange():Range {
        return range;
    }

    public function setRange(range:Range):Void {
        this.range = range;
    }

    public function equals(other:TextDecoration):Bool {
        return other != null && range.equals(other.range) && style.equals(other.style);
    }

}
