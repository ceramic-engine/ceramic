// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The direction of the flexbox layout main axis (copy of taffy's `FlexDirection`).
 */
enum abstract FlexDirection(Int) {

    /** Defines +x as the main axis */
    var Row = 0;

    /** Defines +y as the main axis */
    var Column = 1;

    /** Defines -x as the main axis */
    var RowReverse = 2;

    /** Defines -y as the main axis */
    var ColumnReverse = 3;

}
