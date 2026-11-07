// Ported from gpui-pre 0.3.10: src/window.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A rectangular region that potentially blocks hitboxes inserted prior.
 * See `Window.insertHitbox` for more details. Rust derefs to its bounds.
 * `HitboxId` is an `Int` (`id`): its methods are on `Window`
 * (`isHitboxIdHovered`...).
 */
class Hitbox {

    /** A unique identifier for the hitbox. */
    public final id:Int;

    /** The bounds of the hitbox. */
    public final bounds:Bounds;

    /** The content mask when the hitbox was inserted. */
    public final contentMask:ContentMask;

    /** Flags that specify hitbox behavior. */
    public final behavior:HitboxBehavior;

    public function new(id:Int, bounds:Bounds, contentMask:ContentMask, behavior:HitboxBehavior) {
        this.id = id;
        this.bounds = bounds;
        this.contentMask = contentMask;
        this.behavior = behavior;
    }

    /**
     * Checks if the hitbox is currently hovered. Returns `false` during keyboard input modality
     * so that keyboard navigation suppresses hover highlights. This can return `false` even when
     * the hitbox contains the mouse, if a hitbox in front of this one blocks the mouse.
     * Handling of `ScrollEvent` should typically use `shouldHandleScroll` instead.
     */
    public inline function isHovered(window:Window):Bool {
        return window.isHitboxIdHovered(id);
    }

    /**
     * Checks whether this hitbox would be hovered at `position`, regardless of the current input
     * modality or mouse position.
     */
    public function isHoveredAt(position:Point, window:Window):Bool {
        return window.isHitboxIdHoveredAt(id, position);
    }

    /**
     * Checks if the hitbox contains the mouse and should handle scroll events.
     */
    public inline function shouldHandleScroll(window:Window):Bool {
        return window.shouldHitboxIdHandleScroll(id);
    }

    /**
     * Rust derefs a hitbox to its bounds: `hitbox.contains(point)`.
     */
    public inline function contains(point:Point):Bool {
        return bounds.contains(point);
    }

    /** The origin of the bounds. */
    public var origin(get, never):Point;
    inline function get_origin():Point {
        return bounds.origin;
    }

}
