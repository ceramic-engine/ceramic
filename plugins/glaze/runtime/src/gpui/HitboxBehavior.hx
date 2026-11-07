// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * How the hitbox affects mouse behavior.
 */
enum abstract HitboxBehavior(Int) {

    /**
     * Normal hitbox mouse behavior, doesn't affect mouse handling for other hitboxes.
     */
    var Normal = 0;

    /**
     * All hitboxes behind this hitbox will be ignored and so will have `hitbox.isHovered() ==
     * false` and `hitbox.shouldHandleScroll() == false`. Typically for elements this causes
     * skipping of all mouse events, hover styles, and tooltips. This flag is set by `occlude()`.
     */
    var BlockMouse = 1;

    /**
     * All hitboxes behind this hitbox will have `hitbox.isHovered() == false`, even when
     * `hitbox.shouldHandleScroll() == true`. Typically for elements this causes all mouse
     * interaction except scroll events to be ignored. This flag is set by `blockMouseExceptScroll()`.
     */
    var BlockMouseExceptScroll = 2;

}
