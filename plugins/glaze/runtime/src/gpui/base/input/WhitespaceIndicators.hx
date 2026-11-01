// Ported from gpui-kit 0.8.1: crates/base/src/input/base/layout.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.LineLayout;
import gpui.ShapedLine;

/**
 * The shaped glyphs drawn for visible whitespace.
 */
class WhitespaceIndicators {

    public var space:ShapedLine;

    public var tab:ShapedLine;

    /** Both default to an empty shaped line, like Rust's `Default`. */
    public function new(?space:ShapedLine, ?tab:ShapedLine) {
        this.space = space != null ? space : new ShapedLine(new LineLayout(), '');
        this.tab = tab != null ? tab : new ShapedLine(new LineLayout(), '');
    }

    public inline function clone():WhitespaceIndicators {
        return new WhitespaceIndicators(space, tab);
    }

}
