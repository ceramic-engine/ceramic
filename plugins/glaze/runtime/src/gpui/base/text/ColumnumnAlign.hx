// Ported from gpui-kit 0.8.1: crates/base/src/text/node.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.text;

import markdown.mdast.AlignKind;

/** The alignment of a table column. */
enum abstract ColumnumnAlign(Int) {

    /** No alignment in the delimiter row (`---`); renders like `Left`. */
    var None = 0;

    var Left = 1;

    var Center = 2;

    var Right = 3;

    /** `From<mdast::AlignKind>`. */
    public static function fromAlignKind(value:AlignKind):ColumnumnAlign {
        return switch value {
            case AlignKind.Left: Left;
            case AlignKind.Center: Center;
            case AlignKind.Right: Right;
            case _: None;
        }
    }

}
