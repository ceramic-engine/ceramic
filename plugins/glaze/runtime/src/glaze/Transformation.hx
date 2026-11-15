// Ported from gpui-pre 0.3.10: src/elements/svg.rs (Transformation)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic, moved out of Svg.hx and
// extended for whole elements (origin, `fromMotion`, `intoElementMatrix`). See NOTICE.md.
package glaze;

/**
 * The fields `Transformation.fromMotion` reads: the kit's `MotionTransform`
 * has them (the core of Glaze does not depend on the kit).
 */
typedef MotionTransformLike = {
    final translation:Point;
    final scale:Point;
    final rotationRadians:Float;
}

/**
 * A transformation to apply to an SVG element (`svg().withTransformation`)
 * or, as an addition of Glaze, to a whole element and its children when
 * they are drawn (`div().transformation(...)`, translation and scale only).
 */
class Transformation {

    public final scale:Size;

    public final translate:Point;

    public final rotate:Radians;

    /**
     * The pivot of the scale, relative to the bounds of the element:
     * `(0.5, 0.5)` is its center (the default, like GPUI for SVGs), `(0, 0)`
     * its top left corner. Port addition, used by `Styled.transformation`
     * (an SVG's own transformation always turns around its center).
     */
    public final originX:Float;

    public final originY:Float;

    public function new(?scale:Size, ?translate:Point, rotate:Radians = 0.0, originX:Float = 0.5, originY:Float = 0.5) {
        this.scale = scale != null ? scale : new Size(1, 1);
        this.translate = translate != null ? translate : new Point(0, 0);
        this.rotate = rotate;
        this.originX = originX;
        this.originY = originY;
    }

    /** Create a new Transformation with the specified scale along each axis. */
    public static function scaled(scale:Size):Transformation {
        return new Transformation(scale);
    }

    /** Create a new Transformation with the specified translation. */
    public static function translated(translate:Point):Transformation {
        return new Transformation(null, translate);
    }

    /** Create a new Transformation with the specified rotation in radians. */
    public static function rotated(rotate:Radians):Transformation {
        return new Transformation(null, null, rotate);
    }

    /** Update the scaling factor of this transformation. */
    public function withScaling(scale:Size):Transformation {
        return new Transformation(scale, translate, rotate, originX, originY);
    }

    /** Update the translation value of this transformation. */
    public function withTranslation(translate:Point):Transformation {
        return new Transformation(scale, translate, rotate, originX, originY);
    }

    /** Update the rotation angle of this transformation. */
    public function withRotation(rotate:Radians):Transformation {
        return new Transformation(scale, translate, rotate, originX, originY);
    }

    /**
     * Update the pivot, relative to the bounds of the element (port
     * addition): `withOrigin(0.5, 0.5)` is the center, `withOrigin(0, 0)`
     * the top left corner.
     */
    public function withOrigin(x:Float, y:Float):Transformation {
        return new Transformation(scale, translate, rotate, x, y);
    }

    /**
     * The transformation of a motion value of the kit (`MotionTransform`:
     * translation in pixels, scale, rotation; its opacity is not part of a
     * transformation, give it to `opacity()`). Port addition.
     */
    public static function fromMotion(motion:MotionTransformLike):Transformation {
        final scale = motion.scale;
        final translation = motion.translation;
        return new Transformation(new Size(scale.x, scale.y), new Point(translation.x, translation.y), motion.rotationRadians);
    }

    /** Whether this transformation changes nothing (unit scale, no translation, no rotation). */
    public function isIdentity():Bool {
        return scale.width == 1 && scale.height == 1 && translate.x == 0 && translate.y == 0 && (rotate:Float) == 0;
    }

    public function equals(other:Transformation):Bool {
        return other != null && scale.width == other.scale.width && scale.height == other.scale.height
            && translate.x == other.translate.x && translate.y == other.translate.y && (rotate:Float) == (other.rotate:Float)
            && originX == other.originX && originY == other.originY;
    }

    /**
     * The matrix of this transformation for an element drawn in `bounds`, in
     * logical pixels (what `Window.withElementTransform` takes): the scale
     * around the origin of the transformation, then the translation. The
     * rotation is left out (a whole element cannot be rotated, see
     * `Styled.transformation`). Port addition.
     */
    public function intoElementMatrix(bounds:Bounds):TransformationMatrix {
        final pivotX = bounds.origin.x + bounds.size.width * originX;
        final pivotY = bounds.origin.y + bounds.size.height * originY;
        final sx = scale.width;
        final sy = scale.height;
        return new TransformationMatrix(sx, 0, 0, sy, pivotX - sx * pivotX + translate.x, pivotY - sy * pivotY + translate.y);
    }

    /**
     * The matrix in scaled pixels, around `center` (read it bottom up:
     * translate to the origin, scale, rotate, translate back plus the offset).
     */
    public function intoMatrix(center:Point, scaleFactor:Float):TransformationMatrix {
        return TransformationMatrix.unit()
            .translate(center.x * scaleFactor + translate.x * scaleFactor, center.y * scaleFactor + translate.y * scaleFactor)
            .rotate(rotate)
            .scale(scale.width, scale.height)
            .translate(-center.x * scaleFactor, -center.y * scaleFactor);
    }

}
