// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Point;

/**
 * Window-coordinate anchor and cursor points for painting a selection.
 */
class TextSelectionWindowPoints {

    final _anchor:Point;

    final _cursor:Point;

    @:allow(glaze.kit.base, tests)
    function new(anchor:Point, cursor:Point) {
        _anchor = anchor;
        _cursor = cursor;
    }

    /** Returns the stable anchor in window coordinates. */
    public inline function anchor():Point {
        return _anchor;
    }

    /** Returns the moving cursor in window coordinates. */
    public inline function cursor():Point {
        return _cursor;
    }

    public function equals(other:Null<TextSelectionWindowPoints>):Bool {
        return other != null && _anchor.equals(other._anchor) && _cursor.equals(other._cursor);
    }

    public static function eq(a:Null<TextSelectionWindowPoints>, b:Null<TextSelectionWindowPoints>):Bool {
        return a == null ? b == null : a.equals(b);
    }

}
