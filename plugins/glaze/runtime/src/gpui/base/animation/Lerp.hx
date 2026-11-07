// Ported from gpui-kit 0.8.1: crates/base/src/animation.rs (trait Lerp and its impls)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.animation;

import gpui.Hsla;
import gpui.Pixels;
import gpui.Point;
import gpui.SpringMath.f32;

/**
 * Linear interpolation (Rust trait `Lerp`).
 *
 * Haxe has no trait dispatch on `f32`, `Pixels`, `Point` or `Hsla`, so the
 * implementations are typed static functions, one per Rust impl. Code that
 * interpolates a caller-chosen type takes a `gpui.base.motion.Interpolator`
 * instead (see `Interpolators`, built on these functions).
 *
 * Computed in `f32`, like the Rust code.
 */
class Lerp {

    /**
     * `impl Lerp for f32`: `from + (target - from) * t`.
     */
    public static inline function float(from:Float, target:Float, t:Float):Float {

        return f32(from + f32(f32(target - from) * t));

    }

    /**
     * `impl Lerp for Pixels`.
     */
    public static inline function pixels(from:Pixels, target:Pixels, t:Float):Pixels {

        return float(from, target, t);

    }

    /**
     * `impl Lerp for Point<Pixels>`, channel by channel.
     */
    public static function point(from:Point, target:Point, t:Float):Point {

        return new Point(float(from.x, target.x, t), float(from.y, target.y, t));

    }

    /**
     * `impl Lerp for Hsla`: interpolates each channel linearly. Intended for
     * transitions between near-grayscale UI colors (e.g. text colors), where
     * hue interpolation is irrelevant.
     */
    public static function hsla(from:Hsla, target:Hsla, t:Float):Hsla {

        return new Hsla(
            float(from.h, target.h, t),
            float(from.s, target.s, t),
            float(from.l, target.l, t),
            float(from.a, target.a, t)
        );

    }

}
