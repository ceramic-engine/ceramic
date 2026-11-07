// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Used to control how child nodes are aligned (copy of taffy's `AlignItems`).
 * For Flexbox it controls alignment in the cross axis, for Grid in the block axis.
 * `AlignSelf`, `JustifyItems` and `JustifySelf` are the same type.
 */
enum abstract AlignItems(Int) {

    /** Items are packed toward the start of the axis */
    var Start = 0;

    /** Items are packed toward the end of the axis */
    var End = 1;

    /** Items are packed towards the flex-relative start of the axis */
    var FlexStart = 2;

    /** Items are packed towards the flex-relative end of the axis */
    var FlexEnd = 3;

    /** Items are packed along the center of the cross axis */
    var Center = 4;

    /** Items are aligned such as their baselines align */
    var Baseline = 5;

    /** Stretch to fill the container */
    var Stretch = 6;

}
