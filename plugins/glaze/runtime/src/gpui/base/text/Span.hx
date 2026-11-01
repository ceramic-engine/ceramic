// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

/**
 * A byte range in the source text (UTF-8 offsets).
 */
class Span {

    public var start:Int;

    public var end:Int;

    public inline function new(start:Int = 0, end:Int = 0) {
        this.start = start;
        this.end = end;
    }

    public inline function copy():Span {
        return new Span(start, end);
    }

    public function equals(other:Null<Span>):Bool {
        return other != null && other.start == start && other.end == end;
    }

    /** `Option<Span>` equality. */
    public static function eq(a:Null<Span>, b:Null<Span>):Bool {
        return a == null ? b == null : a.equals(b);
    }

    public function toString():String {
        return 'Span { start: $start, end: $end }';
    }

}
