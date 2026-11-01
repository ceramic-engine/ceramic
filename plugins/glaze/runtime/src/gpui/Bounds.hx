// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

import gpui.util.MathUtil;

/**
 * A rectangular area in a 2D space with an origin point (top left corner) and a size.
 *
 * Stands for Rust's `Bounds<Pixels>`, `Bounds<ScaledPixels>`, `Bounds<DevicePixels>`
 * and `Bounds<f32>`. Use `BoundsOf<T>` for non numeric values.
 *
 * Immutable: every operation returns a new instance.
 */
class Bounds {

    /**
     * The origin point of this area.
     */
    public final origin:Point;

    /**
     * The size of the rectangle.
     */
    public final size:Size;

    public inline function new(?origin:Point, ?size:Size) {

        this.origin = origin != null ? origin : new Point();
        this.size = size != null ? size : new Size();

    }

    /**
     * Constructs a `Bounds` from its top left and bottom right corners.
     */
    public static inline function fromCorners(topLeft:Point, bottomRight:Point):Bounds {

        return new Bounds(
            new Point(topLeft.x, topLeft.y),
            new Size(bottomRight.x - topLeft.x, bottomRight.y - topLeft.y)
        );

    }

    /**
     * Constructs a `Bounds` from an anchor and a size: the given anchor
     * of the result is placed at `origin`.
     */
    public static function fromAnchorAndSize(corner:Anchor, origin:Point, size:Size):Bounds {

        final origin = switch corner {
            case TopLeft: origin;
            case TopRight: new Point(origin.x - size.width, origin.y);
            case BottomLeft: new Point(origin.x, origin.y - size.height);
            case BottomRight: new Point(origin.x - size.width, origin.y - size.height);
            case TopCenter: new Point(origin.x - size.width / 2.0, origin.y);
            case BottomCenter: new Point(origin.x - size.width / 2.0, origin.y - size.height);
            case LeftCenter: new Point(origin.x, origin.y - size.height / 2.0);
            case RightCenter: new Point(origin.x - size.width, origin.y - size.height / 2.0);
        }

        return new Bounds(origin, size);

    }

    /**
     * Creates new bounds centered at the given point.
     */
    public static inline function centeredAt(center:Point, size:Size):Bounds {

        return new Bounds(
            new Point(center.x - size.width / 2.0, center.y - size.height / 2.0),
            size
        );

    }

    /**
     * The top center point of the bounds.
     */
    public inline function topCenter():Point {

        return new Point(origin.x + size.width / 2.0, origin.y);

    }

    /**
     * The bottom center point of the bounds.
     */
    public inline function bottomCenter():Point {

        return new Point(origin.x + size.width / 2.0, origin.y + size.height);

    }

    /**
     * The left center point of the bounds.
     */
    public inline function leftCenter():Point {

        return new Point(origin.x, origin.y + size.height / 2.0);

    }

    /**
     * The right center point of the bounds.
     */
    public inline function rightCenter():Point {

        return new Point(origin.x + size.width, origin.y + size.height / 2.0);

    }

    /**
     * Checks if this `Bounds` overlaps with another `Bounds`
     * (touching edges do not count as an intersection).
     */
    public inline function intersects(other:Bounds):Bool {

        return origin.x < other.origin.x + other.size.width
            && origin.x + size.width > other.origin.x
            && origin.y < other.origin.y + other.size.height
            && origin.y + size.height > other.origin.y;

    }

    /**
     * The center point of the bounds.
     */
    public inline function center():Point {

        return new Point(origin.x + size.width / 2.0, origin.y + size.height / 2.0);

    }

    /**
     * The sum of the width and the height.
     */
    public inline function halfPerimeter():Float {

        return size.width + size.height;

    }

    /**
     * Grows the bounds by `amount` in all directions.
     */
    public inline function dilate(amount:Float):Bounds {

        final doubleAmount = amount + amount;
        return new Bounds(
            new Point(origin.x - amount, origin.y - amount),
            new Size(size.width + doubleAmount, size.height + doubleAmount)
        );

    }

    /**
     * Extends the bounds by a different amount in each direction.
     */
    public inline function extend(amount:Edges):Bounds {

        return new Bounds(
            new Point(origin.x - amount.left, origin.y - amount.top),
            new Size(size.width + amount.left + amount.right, size.height + amount.top + amount.bottom)
        );

    }

    /**
     * Shrinks the bounds by `amount` in all directions (`dilate` with the amount negated).
     */
    public inline function inset(amount:Float):Bounds {

        return dilate(-amount);

    }

    /**
     * The overlapping region of two bounds. If they do not intersect,
     * the result has a zero width and/or height.
     */
    public function intersect(other:Bounds):Bounds {

        final upperLeft = origin.max(other.origin);
        final bottomRight = this.bottomRight().min(other.bottomRight()).max(upperLeft);
        return fromCorners(upperLeft, bottomRight);

    }

    /**
     * `intersect(other).contains(point)` without allocating (the same
     * operations in the same order: `Point.max`, `Point.min`, `fromCorners`,
     * `contains`).
     */
    public inline function intersectContains(other:Bounds, point:Point):Bool {

        final right = origin.x + size.width;
        final bottom = origin.y + size.height;
        final otherRight = other.origin.x + other.size.width;
        final otherBottom = other.origin.y + other.size.height;
        final left = MathUtil.totalLess(other.origin.x, origin.x) ? origin.x : other.origin.x;
        final top = MathUtil.totalLess(other.origin.y, origin.y) ? origin.y : other.origin.y;
        final minRight = !MathUtil.totalLess(otherRight, right) ? right : otherRight;
        final minBottom = !MathUtil.totalLess(otherBottom, bottom) ? bottom : otherBottom;
        final width = (MathUtil.totalLess(left, minRight) ? minRight : left) - left;
        final height = (MathUtil.totalLess(top, minBottom) ? minBottom : top) - top;
        return point.x >= left
            && point.x < left + width
            && point.y >= top
            && point.y < top + height;

    }

    /**
     * The smallest bounds that contains both `this` and `other`.
     */
    public function union(other:Bounds):Bounds {

        final topLeft = origin.min(other.origin);
        final bottomRight = this.bottomRight().max(other.bottomRight());
        return fromCorners(topLeft, bottomRight);

    }

    /**
     * The space available between these bounds and the given outer bounds.
     */
    public inline function spaceWithin(outer:Bounds):Edges {

        return new Edges(
            top() - outer.top(),
            outer.right() - right(),
            outer.bottom() - bottom(),
            left() - outer.left()
        );

    }

    /**
     * Rust `Bounds * scalar`.
     */
    public inline function mul(rhs:Float):Bounds {

        return new Bounds(origin.mul(rhs), size.mul(rhs));

    }

    /**
     * Rust `Bounds / scalar`.
     */
    public inline function div(rhs:Float):Bounds {

        return new Bounds(origin.div(rhs), size.div(rhs));

    }

    /**
     * Rust `Bounds + Point`: moves the origin.
     */
    public inline function add(offset:Point):Bounds {

        return new Bounds(origin.add(offset), size);

    }

    /**
     * Rust `Bounds - Point`: moves the origin.
     */
    public inline function sub(offset:Point):Bounds {

        return new Bounds(origin.sub(offset), size);

    }

    /**
     * The y coordinate of the top edge.
     */
    public inline function top():Float {

        return origin.y;

    }

    /**
     * The y coordinate of the bottom edge.
     */
    public inline function bottom():Float {

        return origin.y + size.height;

    }

    /**
     * The x coordinate of the left edge.
     */
    public inline function left():Float {

        return origin.x;

    }

    /**
     * The x coordinate of the right edge.
     */
    public inline function right():Float {

        return origin.x + size.width;

    }

    /**
     * The top right corner point.
     */
    public inline function topRight():Point {

        return new Point(origin.x + size.width, origin.y);

    }

    /**
     * The bottom right corner point.
     */
    public inline function bottomRight():Point {

        return new Point(origin.x + size.width, origin.y + size.height);

    }

    /**
     * The bottom left corner point.
     */
    public inline function bottomLeft():Point {

        return new Point(origin.x, origin.y + size.height);

    }

    /**
     * The point of the bounds designated by the given anchor.
     */
    public function corner(corner:Anchor):Point {

        return switch corner {
            case TopLeft: origin;
            case TopRight: topRight();
            case BottomLeft: bottomLeft();
            case BottomRight: bottomRight();
            case TopCenter: topCenter();
            case BottomCenter: bottomCenter();
            case LeftCenter: leftCenter();
            case RightCenter: rightCenter();
        }

    }

    /**
     * Checks if the given point is within the bounds. The left and top
     * edges are inclusive, the right and bottom edges are exclusive.
     */
    public inline function contains(point:Point):Bool {

        return point.x >= origin.x
            && point.x < origin.x + size.width
            && point.y >= origin.y
            && point.y < origin.y + size.height;

    }

    /**
     * Checks if the origin and the bottom right corner of these bounds are
     * both contained within `other`.
     */
    public inline function isContainedWithin(other:Bounds):Bool {

        return other.contains(origin) && other.contains(bottomRight());

    }

    /**
     * Returns new bounds with `f` applied to every value of origin and size.
     */
    public inline function map(f:Float->Float):Bounds {

        return new Bounds(origin.map(f), size.map(f));

    }

    /**
     * Returns generic bounds with `f` applied to every value of origin and size.
     */
    public inline function mapOf<U>(f:Float->U):BoundsOf<U> {

        return new BoundsOf<U>(origin.mapOf(f), size.mapOf(f));

    }

    /**
     * Returns new bounds with `f` applied to the origin only.
     */
    public inline function mapOrigin(f:Float->Float):Bounds {

        return new Bounds(origin.map(f), size);

    }

    /**
     * Returns new bounds with `f` applied to the size only.
     */
    public inline function mapSize(f:Float->Float):Bounds {

        return new Bounds(origin, size.map(f));

    }

    /**
     * Converts a point to the coordinate space defined by these bounds,
     * or returns `null` if the point is outside.
     */
    public inline function localize(point:Point):Null<Point> {

        return contains(point) ? point.relativeTo(origin) : null;

    }

    /**
     * Whether the width or the height is less than or equal to zero.
     */
    public inline function isEmpty():Bool {

        return size.width <= 0 || size.height <= 0;

    }

    /**
     * Scales the bounds by a given factor, typically the display scale factor
     * (`Bounds<Pixels>` to `Bounds<ScaledPixels>`).
     */
    public inline function scale(factor:Float):Bounds {

        return new Bounds(origin.scale(factor), size.scale(factor));

    }

    /**
     * Converts the bounds from logical to physical pixels, as whole values
     * (`Bounds<Pixels>::to_device_pixels`).
     */
    public inline function toDevicePixels(factor:Float):Bounds {

        return new Bounds(origin.toDevicePixels(factor), size.toDevicePixels(factor));

    }

    /**
     * Converts the bounds from physical to logical pixels (`Bounds<DevicePixels>::to_pixels`).
     */
    public inline function toPixels(scaleFactor:Float):Bounds {

        return new Bounds(origin.toPixels(scaleFactor), size.toPixels(scaleFactor));

    }

    /**
     * Whether the size is zero (Rust trait `IsZero`).
     */
    public inline function isZero():Bool {

        return size.isZero();

    }

    /**
     * Structural equality.
     */
    public inline function equals(other:Bounds):Bool {

        return other != null && origin.equals(other.origin) && size.equals(other.size);

    }

    public function toString():String {

        return '$origin - ${bottomRight()} (size $size)';

    }

}
