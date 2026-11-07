// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.Range;

/**
 * Selection projected onto a participant's laid-out text runs.
 */
class TextSelectionProjection {

    /** Selected UTF-8 byte ranges paired with the input runs. */
    final _ranges:Array<Null<Range>>;

    /** Whether the participant participates in the current selection. */
    final _isActive:Bool;

    @:allow(glaze.kit.base, tests)
    function new(ranges:Array<Null<Range>>, isActive:Bool) {
        _ranges = ranges;
        _isActive = isActive;
    }

    /** Returns selected UTF-8 byte ranges paired with the input runs. */
    public inline function ranges():Array<Null<Range>> {
        return _ranges;
    }

    /** Returns whether the participant participates in the selection. */
    public inline function isActive():Bool {
        return _isActive;
    }

    public function equals(other:Null<TextSelectionProjection>):Bool {
        if (other == null || _isActive != other._isActive || _ranges.length != other._ranges.length) return false;
        for (i in 0..._ranges.length) {
            final a = _ranges[i];
            final b = other._ranges[i];
            if (a == null ? b != null : !a.equals(b)) return false;
        }
        return true;
    }

}
