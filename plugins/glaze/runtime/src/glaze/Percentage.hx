// Ported from gpui-pre 0.3.10: src/geometry.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust/WGSL to Haxe for Ceramic. See NOTICE.md.

package glaze;

/**
 * A percentage value, as a fraction between 0 and 1.
 */
abstract Percentage(Float) from Float to Float {

    public inline function new(value:Float) {

        this = value;

    }

    @:op(A + B) inline function add(rhs:Percentage):Percentage {

        return this + (rhs:Float);

    }

    @:op(A - B) inline function sub(rhs:Percentage):Percentage {

        return this - (rhs:Float);

    }

    @:op(A / B) inline function div(rhs:Float):Percentage {

        return this / rhs;

    }

    @:op(-A) inline function neg():Percentage {

        return -this;

    }

    /**
     * The angle of this fraction of a full circle (`From<Percentage> for Radians`).
     */
    public inline function toRadians():Radians {

        return this * Math.PI * 2.0;

    }

    public inline function toString():String {

        return 'Percentage(' + this + ')';

    }

}
