// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (impls of Interpolate)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.Bounds;
import glaze.Hsla;
import glaze.Point;
import glaze.Size;
import glaze.kit.base.animation.Lerp;

/**
 * The `Interpolator` of each type Rust implements `Interpolate` for.
 * `FLOAT` also stands for `Pixels` and `Rems` (Float abstracts here).
 */
class Interpolators {

    public static final FLOAT:Interpolator<Float> = new FloatInterpolator();

    public static final POINT:Interpolator<Point> = new PointInterpolator();

    public static final SIZE:Interpolator<Size> = new SizeInterpolator();

    public static final BOUNDS:Interpolator<Bounds> = new BoundsInterpolator();

    public static final HSLA:Interpolator<Hsla> = new HslaInterpolator();

    public static final MOTION_TRANSFORM:Interpolator<MotionTransform> = new MotionTransformInterpolator();

}

class FloatInterpolator implements Interpolator<Float> {

    public function new() {}

    public function interpolate(from:Float, target:Float, progress:Float):Float {
        return Lerp.float(from, target, progress);
    }

    public function equals(a:Float, b:Float):Bool {
        return a == b;
    }

}

class PointInterpolator implements Interpolator<Point> {

    public function new() {}

    public function interpolate(from:Point, target:Point, progress:Float):Point {
        return Lerp.point(from, target, progress);
    }

    public function equals(a:Point, b:Point):Bool {
        return a.equals(b);
    }

}

class SizeInterpolator implements Interpolator<Size> {

    public function new() {}

    public function interpolate(from:Size, target:Size, progress:Float):Size {
        return new Size(Lerp.float(from.width, target.width, progress), Lerp.float(from.height, target.height, progress));
    }

    public function equals(a:Size, b:Size):Bool {
        return a.equals(b);
    }

}

class BoundsInterpolator implements Interpolator<Bounds> {

    public function new() {}

    public function interpolate(from:Bounds, target:Bounds, progress:Float):Bounds {
        return new Bounds(
            Lerp.point(from.origin, target.origin, progress),
            Interpolators.SIZE.interpolate(from.size, target.size, progress)
        );
    }

    public function equals(a:Bounds, b:Bounds):Bool {
        return a.equals(b);
    }

}

class HslaInterpolator implements Interpolator<Hsla> {

    public function new() {}

    public function interpolate(from:Hsla, target:Hsla, progress:Float):Hsla {
        return Lerp.hsla(from, target, progress);
    }

    public function equals(a:Hsla, b:Hsla):Bool {
        return a.equals(b);
    }

}

class MotionTransformInterpolator implements Interpolator<MotionTransform> {

    public function new() {}

    public function interpolate(from:MotionTransform, target:MotionTransform, progress:Float):MotionTransform {
        return from.interpolate(target, progress);
    }

    public function equals(a:MotionTransform, b:MotionTransform):Bool {
        return a.equals(b);
    }

}
