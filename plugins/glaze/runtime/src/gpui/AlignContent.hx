// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Sets the distribution of space between and around content items (copy of taffy's `AlignContent`).
 * `JustifyContent` is the same type.
 */
enum abstract AlignContent(Int) {

    /** Items are packed toward the start of the axis */
    var Start = 0;

    /** Items are packed toward the end of the axis */
    var End = 1;

    /** Items are packed towards the flex-relative start of the axis */
    var FlexStart = 2;

    /** Items are packed towards the flex-relative end of the axis */
    var FlexEnd = 3;

    /** Items are centered around the middle of the axis */
    var Center = 4;

    /** Items are stretched to fill the container */
    var Stretch = 5;

    /** The first and last items are aligned flush with the edges of the container (no gap), the gap between items is distributed evenly */
    var SpaceBetween = 6;

    /** The gap between the first and last items is exactly the same as the gap between items, distributed evenly */
    var SpaceEvenly = 7;

    /** The gap between the first and last items is exactly half the gap between items */
    var SpaceAround = 8;

}
