// Ported from gpui-kit 0.8.1: crates/base/src/text/range_highlight.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import gpui.Hsla;
import gpui.IntoHsla;
import gpui.Range;

/**
 * A background painted behind one range of a `RenderedText`.
 *
 * It is painted under the text and under the selection, and never changes
 * layout. Where highlights overlap, the later one paints over the earlier.
 *
 * Ranges address the rendered text, the string plain copy produces: an
 * application searches `TextViewState.renderedText` and hands the ranges it
 * found back. Each range is split into the text leaves it covers (a paragraph,
 * a heading, a code block, a table cell), which paint it as a background
 * behind their glyphs, so a highlight never changes layout. Text outside every
 * leaf (the separators between blocks and cells, custom blocks, HTML blocks,
 * inline objects) is left unpainted.
 */
class RangeHighlight {

    final _range:Range;

    final _background:Hsla;

    /** A highlight over `range`, in byte offsets of a `RenderedText`. */
    public function new(range:Range, background:IntoHsla) {
        _range = range;
        _background = background;
    }

    public inline function range():Range {
        return _range;
    }

    public inline function background():Hsla {
        return _background;
    }

    public function equals(other:Null<RangeHighlight>):Bool {
        return other != null && _range.equals(other._range) && _background.equals(other._background);
    }

}
