// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package gpui;

/**
 * An angle in radians.
 */
abstract Radians(Float) from Float to Float {

    public inline function new(value:Float) {

        this = value;

    }

    /**
     * `From<Percentage> for Radians`: a fraction of a full circle, so that
     * `impl Into<Radians>` arguments accept `percentage(delta)` like in Rust.
     */
    @:from static inline function fromPercentage(value:Percentage):Radians {

        return value.toRadians();

    }

    @:op(A + B) inline function add(rhs:Radians):Radians {

        return this + (rhs:Float);

    }

    @:op(A - B) inline function sub(rhs:Radians):Radians {

        return this - (rhs:Float);

    }

    @:op(A / B) inline function div(rhs:Float):Radians {

        return this / rhs;

    }

    @:op(-A) inline function neg():Radians {

        return -this;

    }

    public inline function toString():String {

        return 'Radians(' + this + ')';

    }

}
