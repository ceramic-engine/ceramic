// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A run of text with a single font.
 */
class FontRun {

    /** Length in UTF-8 bytes */
    public var len:Int;

    public var fontId:FontId;

    /**
     * Space added after each character of the run, in pixels (port
     * addition without GPUI equivalent, see `TextStyle.letterSpacing`).
     * Zero by default: the run is shaped as GPUI shapes it.
     */
    public var letterSpacing:Float;

    public inline function new(len:Int, fontId:FontId, letterSpacing:Float = 0.0) {
        this.len = len;
        this.fontId = fontId;
        this.letterSpacing = letterSpacing;
    }

    public inline function equals(other:FontRun):Bool {
        return other != null && len == other.len && (fontId:Int) == (other.fontId:Int) && letterSpacing == other.letterSpacing;
    }

    public function toString():String {
        return 'FontRun($len, $fontId)';
    }

}
