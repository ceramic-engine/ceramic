// Ported from gpui-kit 0.8.1: crates/base/src/input/base/inline_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * The tokens of a document, sorted by start.
 */
class InlineTokenStore {

    @:allow(gpui.base.input)
    var spans:Array<InlineTokenSpan>;

    public function new(?spans:Array<InlineTokenSpan>) {
        this.spans = spans != null ? spans : [];
    }

    /**
     * Drops the tokens overlapping `range`, shifts the ones after it by the
     * edit, and adds `inserted` (relative to the edit start). Returns the
     * delta, or null when no token was touched.
     */
    @:allow(gpui.base.input)
    function replace(range:Range, newLen:Int, inserted:Array<InlineTokenSpan>):Null<TokenDelta> {
        final removed:Array<InlineTokenSpan> = [];
        final shift = newLen - range.len();
        final kept:Array<InlineTokenSpan> = [];
        for (span in spans) {
            if (span._range.start < range.end && range.start < span._range.end) {
                removed.push(span.shifted(-range.start));
            }
            else {
                kept.push(span._range.start >= range.end ? span.shifted(shift) : span);
            }
        }
        spans = kept;
        for (s in inserted) spans.push(s.shifted(range.start));
        if (inserted.length > 0) {
            // Rust `sort_by_key` is stable.
            final sorted = spans.copy();
            haxe.ds.ArraySort.sort(sorted, (a, b) -> a._range.start - b._range.start);
            spans = sorted;
        }
        return (removed.length > 0 || inserted.length > 0) ? new TokenDelta(removed, inserted.copy()) : null;
    }

}
