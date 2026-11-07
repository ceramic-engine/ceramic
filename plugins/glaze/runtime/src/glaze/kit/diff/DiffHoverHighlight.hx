// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`DiffHoverHighlight`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.diff;

/**
 * Which part of a row is emphasized while the pointer is over it.
 */
enum abstract DiffHoverHighlight(Int) {

    /** The default. */
    var None;

    /** The whole line. */
    var Line;

    /** The line-number gutter. */
    var LineNumber;

    /** The line and its line number. */
    var Both;

}
