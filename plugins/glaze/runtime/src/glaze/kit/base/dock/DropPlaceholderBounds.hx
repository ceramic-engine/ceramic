// Ported from gpui-kit 0.8.1: crates/base/src/dock/drag.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Bounds;
import glaze.Point;
import glaze.Size;
import glaze.SpringMath;
import glaze.kit.base.Geometry.Placement;

/**
 * The bounds a drop placeholder should occupy within a tab group, given
 * where the drop would land.
 */
class DropPlaceholderBounds {

    final originValue:Point;

    final sizeValue:Size;

    @:allow(glaze.kit.base.dock, tests)
    function new(origin:Point, size:Size) {
        this.originValue = origin;
        this.sizeValue = size;
    }

    public static function forPlacement(bounds:Bounds, placement:Null<Placement>):DropPlaceholderBounds {
        final halfWidth = SpringMath.f32(bounds.size.width * 0.5);
        final halfHeight = SpringMath.f32(bounds.size.height * 0.5);

        return switch placement {
            case Left: new DropPlaceholderBounds(new Point(0, 0), new Size(halfWidth, bounds.size.height));
            case Right: new DropPlaceholderBounds(new Point(halfWidth, 0), new Size(halfWidth, bounds.size.height));
            case Top: new DropPlaceholderBounds(new Point(0, 0), new Size(bounds.size.width, halfHeight));
            case Bottom: new DropPlaceholderBounds(new Point(0, halfHeight), new Size(bounds.size.width, halfHeight));
            case null: new DropPlaceholderBounds(new Point(0, 0), bounds.size);
        }
    }

    public inline function origin():Point {
        return originValue;
    }

    public inline function size():Size {
        return sizeValue;
    }

    public function equals(other:DropPlaceholderBounds):Bool {
        return originValue.equals(other.originValue) && sizeValue.equals(other.sizeValue);
    }

    public function toString():String {
        return 'DropPlaceholderBounds { origin: $originValue, size: $sizeValue }';
    }

}
