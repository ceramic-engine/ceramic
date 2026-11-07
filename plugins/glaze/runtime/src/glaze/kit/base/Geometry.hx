// Ported from gpui-kit 0.8.1: crates/base/src/geometry.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

import glaze.AbsoluteLength;
import glaze.Axis;
import glaze.Length;
import glaze.Pixels;

using glaze.DefiniteLengthTools;

/**
 * Module of the geometry helpers: `Placement`, `Side`, `AxisExt` and
 * `LengthExt`. Rust's serializable `Edges<T>` is `glaze.EdgesOf<T>` here.
 */
class Geometry {}

/**
 * A enum for defining the placement of the element.
 *
 * See also `Side` if you need to define the left, right side.
 */
enum abstract Placement(Int) to Int {

    var Top;
    var Bottom;
    var Left;
    var Right;

    public inline function isHorizontal():Bool {
        return this == Left || this == Right;
    }

    public inline function isVertical():Bool {
        return this == Top || this == Bottom;
    }

    public inline function axis():Axis {
        return isVertical() ? Axis.Vertical : Axis.Horizontal;
    }

    public function toString():String {
        return switch (cast this : Placement) {
            case Top: 'Top';
            case Bottom: 'Bottom';
            case Left: 'Left';
            case Right: 'Right';
        }
    }

}

/**
 * A enum for defining the side of the element.
 *
 * See also `Placement` if you need to define the 4 edges.
 */
enum abstract Side(Int) to Int {

    var Left;
    var Right;

    /** Returns true if the side is left. */
    public inline function isLeft():Bool {
        return this == Left;
    }

    /** Returns true if the side is right. */
    public inline function isRight():Bool {
        return this == Right;
    }

}

/**
 * Extends `Axis` with utility methods (`using glaze.kit.base.Geometry.AxisExt;`).
 */
class AxisExt {

    public static inline function isHorizontal(self:Axis):Bool {
        return self == Axis.Horizontal;
    }

    public static inline function isVertical(self:Axis):Bool {
        return self == Axis.Vertical;
    }

}

/**
 * Extends `Length` with utility methods (`using glaze.kit.base.Geometry.LengthExt;`).
 */
class LengthExt {

    /**
     * Converts the `Length` to `Pixels` based on a given `baseSize` and `remSize`.
     * If the `Length` is `Auto`, it returns null.
     */
    public static function toPixelsOrNull(self:Length, baseSize:AbsoluteLength, remSize:Pixels):Null<Pixels> {
        return switch self {
            case Auto: null;
            case Definite(len): len.toPixels(baseSize, remSize);
        }
    }

}
