// Ported from gpui-kit 0.8.1: crates/component/src/diff/document.rs (`DiffSide`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.diff;

/**
 * Which source version a position belongs to.
 */
enum abstract DiffSide(Int) {

    var Original = 0;

    var Modified = 1;

    @:allow(gpui.component.diff)
    function other():DiffSide {
        return (cast this : DiffSide) == Original ? Modified : Original;
    }

    /** The index of the side (Rust `side as usize`). */
    public inline function index():Int {
        return this;
    }

    public function toString():String {
        return (cast this : DiffSide) == Original ? 'Original' : 'Modified';
    }

}
