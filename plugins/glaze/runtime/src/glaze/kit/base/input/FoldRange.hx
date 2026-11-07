// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/folding.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * A foldable line range supplied by an editor highlighter or another source.
 *
 * Rust's `FoldRange` is `Copy` and the fold map shifts its lines in place:
 * the fields are mutable here, and `copy()` stands for the implicit copy.
 */
class FoldRange {

    public var startLine:Int;

    public var endLine:Int;

    public function new(startLine:Int, endLine:Int) {
        if (startLine > endLine)
            throw 'fold start_line must be <= end_line';
        this.startLine = startLine;
        this.endLine = endLine;
    }

    public inline function copy():FoldRange {
        return new FoldRange(startLine, endLine);
    }

    public inline function equals(other:FoldRange):Bool {
        return other != null && startLine == other.startLine && endLine == other.endLine;
    }

    public function toString():String {
        return 'FoldRange { start_line: $startLine, end_line: $endLine }';
    }

}
