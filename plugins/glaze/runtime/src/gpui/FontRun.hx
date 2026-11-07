// Ported from gpui-pre 0.3.10: src/text_system/line_layout.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A run of text with a single font.
 */
class FontRun {

    /** Length in UTF-8 bytes */
    public var len:Int;

    public var fontId:FontId;

    public inline function new(len:Int, fontId:FontId) {
        this.len = len;
        this.fontId = fontId;
    }

    public inline function equals(other:FontRun):Bool {
        return other != null && len == other.len && (fontId:Int) == (other.fontId:Int);
    }

    public function toString():String {
        return 'FontRun($len, $fontId)';
    }

}
