// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`DiffMode`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * How a `Diff` presents the two sides of each file.
 */
enum abstract DiffMode(Int) {

    /** The original and modified source side by side. */
    var Split;

    /** One column, with deleted lines before added lines (the default). */
    var Unified;

}
