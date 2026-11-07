// Ported from gpui-kit 0.8.1: crates/base/src/scrollbar.rs (ScrollbarMode)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.theme;

/**
 * Scrollbar show mode.
 *
 * Defined in `scrollbar.rs` in Rust; it lives with the theme here, and
 * `glaze.kit.base.Scrollbar` names it as a typedef.
 */
enum abstract ScrollbarMode(Int) {

    /**
     * Show scrollbar when scrolling, will fade out after idle (the default).
     */
    var Scrolling = 0;

    /**
     * Show scrollbar on hover.
     */
    var Hover = 1;

    /**
     * Always show scrollbar.
     */
    var Always = 2;

    public inline function isHover():Bool {

        return abstract == Hover;

    }

    public inline function isAlways():Bool {

        return abstract == Always;

    }

    /**
     * The variant name, as Rust's `Debug` writes it.
     */
    public function toString():String {

        return switch abstract {
            case Scrolling: 'Scrolling';
            case Hover: 'Hover';
            case Always: 'Always';
        }

    }

}
