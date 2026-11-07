// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A simplified representation of the grid-template-* value.
 */
class GridTemplate {

    /** How this template directive should be repeated */
    public final repeat:Int;

    /** The minimum size in the repeat(<>, minmax(_, 1fr)) equation */
    public final minSize:GridTemplateMinSize;

    public inline function new(repeat:Int, minSize:GridTemplateMinSize = Zero) {
        this.repeat = repeat;
        this.minSize = minSize;
    }

    public function equals(other:GridTemplate):Bool {
        return other != null && repeat == other.repeat && minSize == other.minSize;
    }

}
