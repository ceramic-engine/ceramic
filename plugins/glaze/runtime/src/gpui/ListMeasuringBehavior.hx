// Ported from gpui-pre 0.3.10: src/elements/list.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The measuring behavior to apply during layout.
 */
enum ListMeasuringBehavior {

    /**
     * Measure all items in the list (`hasMeasured` tells whether it was done).
     * Note: This can be expensive for the first frame in a large list.
     */
    Measure(hasMeasured:Bool);

    /** Only measure visible items (default). */
    Visible;

}
