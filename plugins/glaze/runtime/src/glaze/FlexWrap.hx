// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Controls whether flex items are forced onto one line or can wrap onto multiple lines (copy of taffy's `FlexWrap`).
 */
enum abstract FlexWrap(Int) {

    /** Items will not wrap and stay on a single line */
    var NoWrap = 0;

    /** Items will wrap according to this item's `FlexDirection` */
    var Wrap = 1;

    /** Items will wrap in the opposite direction to this item's `FlexDirection` */
    var WrapReverse = 2;

}
