// Ported from gpui-pre 0.3.10: src/scene.rs (TransformationMatrix)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * A data type representing a 2 dimensional transformation that can be applied to an element
 * (row major 2x2 rotation / scale matrix plus a translation, in scaled pixels).
 *
 * Immutable: every operation returns a new matrix.
 */
class TransformationMatrix {

    public final m00:Float;
    public final m01:Float;
    public final m10:Float;
    public final m11:Float;
    public final tx:Float;
    public final ty:Float;

    public inline function new(m00:Float = 1, m01:Float = 0, m10:Float = 0, m11:Float = 1, tx:Float = 0, ty:Float = 0) {
        this.m00 = m00;
        this.m01 = m01;
        this.m10 = m10;
        this.m11 = m11;
        this.tx = tx;
        this.ty = ty;
    }

    /** The unit matrix, has no effect. */
    public static inline function unit():TransformationMatrix {
        return new TransformationMatrix();
    }

    /** Move the origin by a given point (in scaled pixels) */
    public function translate(x:Float, y:Float):TransformationMatrix {
        return compose(new TransformationMatrix(1, 0, 0, 1, x, y));
    }

    /** Clockwise rotation in radians around the origin */
    public function rotate(angle:Radians):TransformationMatrix {
        final a:Float = angle;
        return compose(new TransformationMatrix(Math.cos(a), -Math.sin(a), Math.sin(a), Math.cos(a), 0, 0));
    }

    /** Scale around the origin */
    public function scale(width:Float, height:Float):TransformationMatrix {
        return compose(new TransformationMatrix(width, 0, 0, height, 0, 0));
    }

    public inline function isUnit():Bool {
        return m00 == 1 && m01 == 0 && m10 == 0 && m11 == 1 && tx == 0 && ty == 0;
    }

    /**
     * Perform matrix multiplication with another transformation
     * to produce a new transformation that is the result of
     * applying both transformations: first, `other`, then `this`.
     */
    public function compose(other:TransformationMatrix):TransformationMatrix {
        if (other.isUnit())
            return this;
        return new TransformationMatrix(
            m00 * other.m00 + m01 * other.m10,
            m00 * other.m01 + m01 * other.m11,
            m10 * other.m00 + m11 * other.m10,
            m10 * other.m01 + m11 * other.m11,
            tx + m00 * other.tx + m01 * other.ty,
            ty + m10 * other.tx + m11 * other.ty
        );
    }

    /**
     * Whether the matrix only scales and translates (no rotation, no
     * shear): rectangles stay upright rectangles. Port addition.
     */
    public inline function isAxisAligned():Bool {
        return m01 == 0 && m10 == 0;
    }

    /**
     * The matrix that undoes this one, or `null` when it cannot be undone
     * (a zero scale). Port addition.
     */
    public function inverse():Null<TransformationMatrix> {
        final det = m00 * m11 - m01 * m10;
        if (det == 0 || !Math.isFinite(det))
            return null;
        final i00 = m11 / det;
        final i01 = -m01 / det;
        final i10 = -m10 / det;
        final i11 = m00 / det;
        return new TransformationMatrix(i00, i01, i10, i11, -(i00 * tx + i01 * ty), -(i10 * tx + i11 * ty));
    }

    /**
     * The smallest upright bounds holding `bounds` once transformed (the
     * transformed bounds themselves when the matrix is axis aligned). Port
     * addition.
     */
    public function mapBounds(bounds:Bounds):Bounds {
        final x0 = bounds.origin.x;
        final y0 = bounds.origin.y;
        final x1 = x0 + bounds.size.width;
        final y1 = y0 + bounds.size.height;
        final ax = m00 * x0 + m01 * y0 + tx;
        final ay = m10 * x0 + m11 * y0 + ty;
        final bx = m00 * x1 + m01 * y0 + tx;
        final by = m10 * x1 + m11 * y0 + ty;
        final cx = m00 * x1 + m01 * y1 + tx;
        final cy = m10 * x1 + m11 * y1 + ty;
        final dx = m00 * x0 + m01 * y1 + tx;
        final dy = m10 * x0 + m11 * y1 + ty;
        final left = Math.min(Math.min(ax, bx), Math.min(cx, dx));
        final top = Math.min(Math.min(ay, by), Math.min(cy, dy));
        final right = Math.max(Math.max(ax, bx), Math.max(cx, dx));
        final bottom = Math.max(Math.max(ay, by), Math.max(cy, dy));
        return new Bounds(new Point(left, top), new Size(right - left, bottom - top));
    }

    /** Apply transformation to a point, mainly useful for debugging */
    public function apply(point:Point):Point {
        return new Point(tx + m00 * point.x + m01 * point.y, ty + m10 * point.x + m11 * point.y);
    }

    public function equals(other:TransformationMatrix):Bool {
        return other != null && m00 == other.m00 && m01 == other.m01 && m10 == other.m10 && m11 == other.m11 && tx == other.tx && ty == other.ty;
    }

    public function toString():String {
        return 'TransformationMatrix([[$m00, $m01], [$m10, $m11]], [$tx, $ty])';
    }

}
