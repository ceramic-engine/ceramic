// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * Generic version of `Bounds`, for non numeric values.
 *
 * Immutable: every operation returns a new instance.
 */
class BoundsOf<T> {

    /**
     * The origin point of this area.
     */
    public final origin:PointOf<T>;

    /**
     * The size of the rectangle.
     */
    public final size:SizeOf<T>;

    public inline function new(origin:PointOf<T>, size:SizeOf<T>) {

        this.origin = origin;
        this.size = size;

    }

    /**
     * Returns new bounds with `f` applied to every value of origin and size.
     */
    public inline function map<U>(f:(T) -> U):BoundsOf<U> {

        return new BoundsOf<U>(origin.map(f), size.map(f));

    }

    /**
     * Returns numeric bounds with `f` applied to every value of origin and size.
     */
    public inline function mapToBounds(f:(T) -> Float):Bounds {

        return new Bounds(origin.mapToPoint(f), size.mapToSize(f));

    }

    /**
     * Returns new bounds with `f` applied to the origin only.
     */
    public inline function mapOrigin(f:(T) -> T):BoundsOf<T> {

        return new BoundsOf<T>(origin.map(f), size);

    }

    /**
     * Returns new bounds with `f` applied to the size only.
     */
    public inline function mapSize(f:(T) -> T):BoundsOf<T> {

        return new BoundsOf<T>(origin, size.map(f));

    }

    /**
     * Structural equality. `eq` compares two values (default: `==`).
     */
    public function equals(other:BoundsOf<T>, ?eq:(T, T) -> Bool):Bool {

        return other != null && origin.equals(other.origin, eq) && size.equals(other.size, eq);

    }

    public function toString():String {

        return '$origin (size $size)';

    }

}
