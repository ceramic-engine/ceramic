// Ported from gpui-pre 0.3.10: src/style.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * The minimum size of a column or row in a grid layout.
 */
enum abstract GridTemplateMinSize(Int) {

    /** The column or row size may be 0 */
    var Zero = 0;

    /** The column or row size can be determined by the min content */
    var MinContent = 1;

    /** The column or row size can be determined by the max content */
    var MaxContent = 2;

}
