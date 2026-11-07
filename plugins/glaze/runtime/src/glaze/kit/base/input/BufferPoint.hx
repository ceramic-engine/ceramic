// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/display_map/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Position in the buffer (logical text).
 *
 * - `line`: 0-based logical line number (split by `\n`)
 * - `col`: 0-based column offset (byte offset)
 */
class BufferPoint {

    public final line:Int;

    public final col:Int;

    public inline function new(line:Int, col:Int) {
        this.line = line;
        this.col = col;
    }

    public inline function equals(other:BufferPoint):Bool {
        return other != null && line == other.line && col == other.col;
    }

    public function toString():String {
        return 'BufferPoint { line: $line, col: $col }';
    }

}
