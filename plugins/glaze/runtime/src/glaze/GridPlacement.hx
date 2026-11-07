// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The placement of an item within a grid layout's column or row.
 */
enum GridPlacement {

    /** The grid line index to place this item. */
    Line(index:Int);

    /** The number of grid lines to span. */
    Span(span:Int);

    /** Automatically determine the placement, equivalent to Span(1) */
    Auto;

}
