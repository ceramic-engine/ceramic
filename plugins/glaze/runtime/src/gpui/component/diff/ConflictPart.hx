// Ported from gpui-kit 0.8.1: crates/component/src/diff/conflict.rs (`ConflictPart`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * Which part of a conflict a row introduces.
 */
enum abstract ConflictPart(Int) {

    var Current;

    var Base;

    var Incoming;

}
