// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A position in the layout cache of a frame, used to reuse or truncate the
 * layouts of a range of elements (view caching).
 */
class LineLayoutIndex {

    public var fontGeneration:Int;
    public var linesIndex:Int;
    public var wrappedLinesIndex:Int;
    public var linesByHashIndex:Int;
    public var wrappedLinesByHashIndex:Int;

    public function new(fontGeneration:Int = 0, linesIndex:Int = 0, wrappedLinesIndex:Int = 0, linesByHashIndex:Int = 0, wrappedLinesByHashIndex:Int = 0) {
        this.fontGeneration = fontGeneration;
        this.linesIndex = linesIndex;
        this.wrappedLinesIndex = wrappedLinesIndex;
        this.linesByHashIndex = linesByHashIndex;
        this.wrappedLinesByHashIndex = wrappedLinesByHashIndex;
    }

    public inline function copyFrom(other:LineLayoutIndex):Void {
        fontGeneration = other.fontGeneration;
        linesIndex = other.linesIndex;
        wrappedLinesIndex = other.wrappedLinesIndex;
        linesByHashIndex = other.linesByHashIndex;
        wrappedLinesByHashIndex = other.wrappedLinesByHashIndex;
    }

}
