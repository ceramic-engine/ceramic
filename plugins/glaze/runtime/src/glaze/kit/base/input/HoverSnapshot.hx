// Ported from gpui-kit 0.8.1: crates/base/src/input/base/token_presentation.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Bounds;
import gpui.Range;

/**
 * The retained hover presence: the entered span, its placed bounds, and its
 * UTF-16 range as of entry. JavaScript string offsets shift with later
 * edits, so an exit delivered after a change cannot recompute them from the
 * current text and reuses these instead.
 */
class HoverSnapshot {

    public final span:InlineTokenSpan;

    public final bounds:Bounds;

    public final rangeUtf16:Range;

    public function new(span:InlineTokenSpan, bounds:Bounds, rangeUtf16:Range) {
        this.span = span;
        this.bounds = bounds;
        this.rangeUtf16 = rangeUtf16;
    }

}
