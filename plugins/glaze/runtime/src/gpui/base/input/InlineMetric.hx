// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/text_wrapper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.Range;

/**
 * The width of an inline element over a UTF-8 byte range of the text, an
 * entry of Rust's `Rc<[(Range<usize>, Pixels)]>` inline metrics.
 */
class InlineMetric {

    public final range:Range;

    public final width:Float;

    public inline function new(range:Range, width:Float) {
        this.range = range;
        this.width = width;
    }

    public inline function equals(other:InlineMetric):Bool {
        return other != null && range.equals(other.range) && width == other.width;
    }

    /** Rust `==` on two slices of metrics */
    public static function arrayEquals(a:Array<InlineMetric>, b:Array<InlineMetric>):Bool {
        if (a == b)
            return true;
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (!a[i].equals(b[i]))
                return false;
        }
        return true;
    }

}
