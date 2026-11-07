// Ported from gpui-kit 0.8.1: crates/base/src/text/document.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

/**
 * The kind of block before the one being rendered, as far as the gaps of
 * headings and rules care.
 */
enum PrevBlock {
    Other;

    /** A heading of the given level. */
    Heading(level:Int);

    Rule;
}
