// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs (`PrepaintCaretGeometry`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.Bounds;
import glaze.Pixels;
import glaze.Point;

/**
 * Caret positioning geometry from the input's latest prepaint.
 *
 * Unlike `lastLayout` (published at paint time), this is stashed during
 * prepaint so caret-anchored popups can position themselves from the
 * current frame's geometry in their deferred prepaint, instead of the
 * previous frame's paint.
 */
class PrepaintCaretGeometry {

    final _cursorBounds:Bounds;

    final _lineHeight:Pixels;

    final _inputBounds:Bounds;

    final _scrollOffset:Point;

    /** A resize owns visibility while its requested repaint settles. */
    public var resizeRevealOwned:Bool = false;

    public function new(cursorBounds:Bounds, lineHeight:Pixels, inputBounds:Bounds, scrollOffset:Point) {
        this._cursorBounds = cursorBounds;
        this._lineHeight = lineHeight;
        this._inputBounds = inputBounds;
        this._scrollOffset = scrollOffset;
    }

    /** The active caret's bounds from the fresh prepaint layout. */
    public inline function cursorBounds():Bounds {
        return _cursorBounds;
    }

    /** Line height from the fresh prepaint layout. */
    public inline function lineHeight():Pixels {
        return _lineHeight;
    }

    /** The input container bounds from the fresh prepaint. */
    public inline function inputBounds():Bounds {
        return _inputBounds;
    }

    /**
     * The scroll offset that will be in effect after paint, clamped like
     * `InputBaseState.updateScrollOffset` clamps it.
     */
    public inline function scrollOffset():Point {
        return _scrollOffset;
    }

    /** Rust `Copy`. */
    public function copy():PrepaintCaretGeometry {
        final geometry = new PrepaintCaretGeometry(_cursorBounds, _lineHeight, _inputBounds, _scrollOffset);
        geometry.resizeRevealOwned = resizeRevealOwned;
        return geometry;
    }

}
