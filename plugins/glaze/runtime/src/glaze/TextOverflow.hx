// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * How to truncate text that overflows the width of the element.
 */
enum TextOverflow {

    /** Truncate the text at the end when it doesn't fit, and represent this truncation by displaying the provided string. */
    Truncate(ellipsis:String);

    /** Truncate the text at the start when it doesn't fit, and represent this truncation by displaying the provided string at the beginning. */
    TruncateStart(ellipsis:String);

    /** Truncate the text in the middle when it doesn't fit, preserving both the start and end of the string. */
    TruncateMiddle(ellipsis:String);

}
