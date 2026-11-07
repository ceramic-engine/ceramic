// Ported from gpui-kit 0.8.1: crates/base/src/motion.rs (MotionTransform)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.motion;

import glaze.Point;
import glaze.kit.base.animation.Lerp;

/**
 * A presentation-neutral bundle for coordinated paint transforms.
 * Immutable, with value semantics (`equals`).
 */
class MotionTransform {

    /** The translation, in pixels. */
    public final translation:Point;

    /** The scale on each axis (`Point<f32>`). */
    public final scale:Point;

    public final rotationRadians:Float;

    public final opacity:Float;

    public inline function new(translation:Point, scale:Point, rotationRadians:Float, opacity:Float) {
        this.translation = translation;
        this.scale = scale;
        this.rotationRadians = rotationRadians;
        this.opacity = opacity;
    }

    /**
     * No translation or rotation, a unit scale and full opacity (also Rust's `Default`).
     */
    public static function identity():MotionTransform {
        return new MotionTransform(new Point(0.0, 0.0), new Point(1.0, 1.0), 0.0, 1.0);
    }

    public static inline function defaultValue():MotionTransform {
        return identity();
    }

    /**
     * `impl Interpolate for MotionTransform`: every channel linearly.
     */
    public function interpolate(target:MotionTransform, progress:Float):MotionTransform {
        return new MotionTransform(
            Lerp.point(translation, target.translation, progress),
            new Point(Lerp.float(scale.x, target.scale.x, progress), Lerp.float(scale.y, target.scale.y, progress)),
            Lerp.float(rotationRadians, target.rotationRadians, progress),
            Lerp.float(opacity, target.opacity, progress)
        );
    }

    public function equals(other:MotionTransform):Bool {
        return other != null
            && translation.equals(other.translation)
            && scale.equals(other.scale)
            && rotationRadians == other.rotationRadians
            && opacity == other.opacity;
    }

    public function toString():String {
        return 'MotionTransform(translation: $translation, scale: $scale, rotationRadians: $rotationRadians, opacity: $opacity)';
    }

}
