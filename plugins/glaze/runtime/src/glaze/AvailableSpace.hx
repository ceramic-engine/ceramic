// Ported from gpui-pre 0.3.10: src/taffy.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The space available for an element to be laid out in.
 */
enum AvailableSpace {

    /** The amount of space available is the specified number of pixels */
    Definite(pixels:Pixels);

    /** The amount of space available is indefinite and the node should be laid out under a min-content constraint */
    MinContent;

    /** The amount of space available is indefinite and the node should be laid out under a max-content constraint */
    MaxContent;

}
