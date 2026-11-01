// Ported from gpui-kit 0.8.1: crates/component/src/diff/conflict.rs (`DiffConflictResolution`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * How the user resolved a conflict.
 */
enum abstract DiffConflictResolution(Int) {

    /** Keep the current change, between `<<<<<<<` and `=======`. */
    var Current;

    /** Keep the incoming change, between `=======` and `>>>>>>>`. */
    var Incoming;

    /** Keep the current change followed by the incoming one. */
    var Both;

}
