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

    /**
     * What the hitbox means for the drag regions published to the native
     * window (port addition, see `CeramicWindowOperations.hitRegions`):
     * `WINDOW_DRAG_NONE`, `WINDOW_DRAG_AREA` (a `WindowControlArea.Drag`
     * element) or `WINDOW_DRAG_HOLE` (an element that must keep receiving
     * the presses when it is drawn above a drag area). Set while the element
     * paints; it travels with the hitbox when a cached view is reused.
     */
    public var windowDragRole:Int = WINDOW_DRAG_NONE;

    public static inline final WINDOW_DRAG_NONE:Int = 0;

    public static inline final WINDOW_DRAG_AREA:Int = 1;

    public static inline final WINDOW_DRAG_HOLE:Int = 2;

    /**
     * The element transformation the hitbox was inserted in
     * (`Window.withElementTransform`, port addition), null for nearly every
     * hitbox. `bounds` and `contentMask` stay in the coordinates of the
     * element (its layout): the hit tests bring the mouse position back
     * into them, so the hitbox is hit where it is drawn.
     */
    public var transform:Null<TransformationMatrix> = null;

    /**
     * Whether the hitbox, as drawn, holds the window position `x, y` inside
     * its content mask (what the hit test of the window checks).
     */
    public function hitAtWindow(x:Float, y:Float):Bool {
        final t = transform;
        if (t != null) {
            if (t.m00 == 0 || t.m11 == 0)
                return false;
            x = (x - t.tx) / t.m00;
            y = (y - t.ty) / t.m11;
        }
        final b = bounds;
        final m = contentMask.bounds;
        return x >= b.origin.x && x < b.origin.x + b.size.width && y >= b.origin.y && y < b.origin.y + b.size.height
            && x >= m.origin.x && x < m.origin.x + m.size.width && y >= m.origin.y && y < m.origin.y + m.size.height;
    }

    /**
     * A window position in the coordinates of the hitbox (`position` itself
     * without a transformation).
     */
    public function toLocal(position:Point):Point {
        final t = transform;
        if (t == null || t.m00 == 0 || t.m11 == 0)
            return position;
        return new Point((position.x - t.tx) / t.m00, (position.y - t.ty) / t.m11);
    }

    /** Whether the bounds, as drawn, hold the window position (the content mask is not checked). */
    public function boundsContainWindowPoint(position:Point):Bool {
        return transform == null ? bounds.contains(position) : bounds.contains(toLocal(position));
    }

    /** The bounds as drawn, in window coordinates (`bounds` without a transformation). */
    public function windowBounds():Bounds {
        final t = transform;
        return t == null ? bounds : t.mapBounds(bounds);
    }

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
