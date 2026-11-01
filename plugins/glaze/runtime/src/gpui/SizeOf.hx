// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * Generic version of `Size`, for non numeric values
 * (`Size<Length>`, `Size<AbsoluteLength>`, `Size<AvailableSpace>`...).
 *
 * Methods that Rust defines on `Size<Length>` live in `SizeOfLength`.
 *
 * Immutable: every operation returns a new instance.
 */
class SizeOf<T> {

    /**
     * The width component of the size.
     */
    public final width:T;

    /**
     * The height component of the size.
     */
    public final height:T;

    public inline function new(width:T, height:T) {

        this.width = width;
        this.height = height;

    }

    /**
     * Returns a new size with `f` applied to the width and height.
     */
    public inline function map<U>(f:T->U):SizeOf<U> {

        return new SizeOf<U>(f(width), f(height));

    }

    /**
     * Returns a numeric size with `f` applied to the width and height.
     */
    public inline function mapToSize(f:T->Float):Size {

        return new Size(f(width), f(height));

    }

    /**
     * Returns the value along the given axis (Rust trait `Along`).
     */
    public inline function along(axis:Axis):T {

        return axis == Horizontal ? width : height;

    }

    /**
     * Returns a new size with `f` applied to the value along the given axis (Rust trait `Along`).
     */
    public inline function applyAlong(axis:Axis, f:T->T):SizeOf<T> {

        return axis == Horizontal ? new SizeOf<T>(f(width), height) : new SizeOf<T>(width, f(height));

    }

    /**
     * Structural equality. `eq` compares two values (default: `==`).
     */
    public function equals(other:SizeOf<T>, ?eq:T->T->Bool):Bool {

        if (other == null) return false;
        if (eq == null) return width == other.width && height == other.height;
        return eq(width, other.width) && eq(height, other.height);

    }

    public function toString():String {

        return '$width × $height';

    }

}
