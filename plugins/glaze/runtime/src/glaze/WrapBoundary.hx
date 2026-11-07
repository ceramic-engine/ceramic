// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A boundary at which a line was wrapped
 */
class WrapBoundary {

    /** The index in the run just before the line was wrapped */
    public var runIx:Int;

    /** The index of the glyph just before the line was wrapped */
    public var glyphIx:Int;

    public inline function new(runIx:Int, glyphIx:Int) {
        this.runIx = runIx;
        this.glyphIx = glyphIx;
    }

    /** Lexicographic comparison (Rust derives `Ord`) */
    public inline function compare(other:WrapBoundary):Int {
        return runIx != other.runIx ? (runIx < other.runIx ? -1 : 1) : (glyphIx < other.glyphIx ? -1 : (glyphIx > other.glyphIx ? 1 : 0));
    }

    public inline function equals(other:WrapBoundary):Bool {
        return other != null && runIx == other.runIx && glyphIx == other.glyphIx;
    }

    public function toString():String {
        return 'WrapBoundary($runIx, $glyphIx)';
    }

}
