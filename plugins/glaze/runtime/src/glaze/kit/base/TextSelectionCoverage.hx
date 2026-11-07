// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

/**
 * How much of one participant participates in a window selection.
 */
enum abstract TextSelectionCoverage(Int) {

    /** Only the interval between this participant's two endpoints is selected (the default). */
    var Bounded = 0;

    /** The participant is selected from its beginning through its endpoint. */
    var FromStart = 1;

    /** The participant is selected from its endpoint through its end. */
    var ToEnd = 2;

    /** The entire participant lies between endpoints in other participants. */
    var Full = 3;

}
