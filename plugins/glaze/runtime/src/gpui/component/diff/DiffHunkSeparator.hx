// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`DiffHunkSeparator`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * How the start of each hunk is marked.
 */
enum abstract DiffHunkSeparator(Int) {

    /** The `@@` header, including the enclosing scope Git reports (the default). */
    var Metadata;

    /** The count of lines the patch does not supply before the hunk. */
    var LineInfo;

    /** A thin divider. */
    var Simple;

}
