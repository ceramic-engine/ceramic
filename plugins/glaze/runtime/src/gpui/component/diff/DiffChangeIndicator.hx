// Ported from gpui-kit 0.8.1: crates/component/src/diff/mod.rs (`DiffChangeIndicator`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * How changed lines are marked beside the code.
 */
enum abstract DiffChangeIndicator(Int) {

    /** `+` and `−` signs (the default). */
    var Signs;

    /** A colored bar. */
    var Bars;

    /** No marker. */
    var None;

}
