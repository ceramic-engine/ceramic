// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (trait Interpolate, with PartialEq)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

/**
 * Interpolates and compares values of one type, for the motion functions
 * that animate a caller-chosen type (Rust `T: Interpolate + PartialEq`).
 *
 * Design: Rust implements `Interpolate` on the value types themselves
 * (`f32`, `Pixels`, `Point`, `Size`, `Bounds`, `Hsla`, `MotionTransform`).
 * Haxe cannot add an interface to `Float` or to the geometry classes, and a
 * structural typedef would go through `Dynamic` on hxcpp, so the behaviour is
 * a separate object passed next to the value. `Interpolators` holds one
 * instance per Rust impl (`Interpolators.FLOAT`, `POINT`, `SIZE`, `BOUNDS`,
 * `HSLA`, `MOTION_TRANSFORM`); implement this interface for other types.
 * Functions that only animate a `Float` (`Motion.transition`) need none.
 */
interface Interpolator<T> {

    /**
     * The value at `progress` (usually eased, possibly outside `0..1`) between
     * `from` and `target`.
     */
    function interpolate(from:T, target:T, progress:Float):T;

    /**
     * Structural equality (Rust `PartialEq`), used to detect a changed target.
     */
    function equals(a:T, b:T):Bool;

}
