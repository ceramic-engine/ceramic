// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.Range;

/**
 * Where a selection maps to in the source (Rust `SourceRangeSelection`).
 * A mutable holder, since Rust merges into it in place.
 */
class SourceRangeSelection {

    /** 0: unselected, 1: mapped (`range`), 2: unmapped. */
    @:allow(glaze.kit.base.text)
    var kind:Int;

    @:allow(glaze.kit.base.text)
    var range:Null<Range>;

    function new(kind:Int, ?range:Range) {
        this.kind = kind;
        this.range = range;
    }

    public static inline function unselected():SourceRangeSelection {
        return new SourceRangeSelection(0);
    }

    public static inline function mapped(range:Range):SourceRangeSelection {
        return new SourceRangeSelection(1, range);
    }

    public static inline function unmapped():SourceRangeSelection {
        return new SourceRangeSelection(2);
    }

    public inline function isUnselected():Bool {
        return kind == 0;
    }

    public inline function isMapped():Bool {
        return kind == 1;
    }

    public inline function isUnmapped():Bool {
        return kind == 2;
    }

    public function merge(other:SourceRangeSelection):Void {
        switch other.kind {
            case 0:
            case 2:
                kind = 2;
                range = null;
            case _:
                switch kind {
                    case 0:
                        kind = 1;
                        range = other.range;
                    case 1:
                        range = new Range(range.start < other.range.start ? range.start : other.range.start,
                            range.end > other.range.end ? range.end : other.range.end);
                    case _:
                }
        }
    }

    public function intoRange():Null<Range> {
        return kind == 1 ? range : null;
    }

}
