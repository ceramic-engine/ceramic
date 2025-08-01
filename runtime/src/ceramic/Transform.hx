package ceramic;

import tracker.Events;

// Portions of matrix manipulation code taken from OpenFL and PIXI

/**
 * Transform holds matrix data to make 2d rotate, translate, scale and skew transformations.
 * Angles are in degrees.
 * 
 * This class represents a 2D affine transformation matrix used for positioning,
 * rotating, scaling, and skewing visual objects. The matrix is stored in the
 * following format:
 * 
 * ```
 * | a | c | tx |
 * | b | d | ty |
 * | 0 | 0 | 1  |
 * ```
 * 
 * Where:
 * - `a` and `d` control scaling and rotation
 * - `b` and `c` control skewing and rotation  
 * - `tx` and `ty` control translation (position)
 * 
 * Example usage:
 * ```haxe
 * var transform = new Transform();
 * transform.translate(100, 50);    // Move to (100, 50)
 * transform.rotate(Math.PI / 4);   // Rotate 45 degrees
 * transform.scale(2, 2);           // Double the size
 * 
 * // Apply to a point
 * var newX = transform.transformX(10, 20);
 * var newY = transform.transformY(10, 20);
 * ```
 * 
 * The Transform class includes change tracking to optimize rendering pipelines
 * and supports decomposition into individual components (position, scale, rotation, skew).
 */
@:allow(ceramic.TransformPool)
class Transform implements Events {

    static var _decomposed1:DecomposedTransform = new DecomposedTransform();

    static var _decomposed2:DecomposedTransform = new DecomposedTransform();

/// Events

    /**
     * Emitted when any transform property changes.
     * Useful for invalidating caches or triggering re-renders.
     */
    @event public function change();

/// Properties

    var _aPrev:Float;

    var _bPrev:Float;

    var _cPrev:Float;

    var _dPrev:Float;

    var _txPrev:Float;

    var _tyPrev:Float;

    public var changedDirty:Bool;

    /**
     * The (0,0) element of the matrix, affects horizontal scaling and rotation.
     */
    public var a:Float;

    /**
     * The (1,0) element of the matrix, affects vertical skewing and rotation.
     */
    public var b:Float;

    /**
     * The (0,1) element of the matrix, affects horizontal skewing and rotation.
     */
    public var c:Float;

    /**
     * The (1,1) element of the matrix, affects vertical scaling and rotation.
     */
    public var d:Float;

    /**
     * The horizontal translation (x position) in pixels.
     */
    public var tx:Float;

    /**
     * The vertical translation (y position) in pixels.
     */
    public var ty:Float;

    /**
     * Whether the transform has changed since the last change event.
     * Call computeChanged() to update this value.
     */
    public var changed(default,null):Bool;

/// Internal

    static var _tmp = new Transform();

/// Code

    /**
     * Create a new Transform matrix.
     * @param a Horizontal scaling/rotation component (default: 1)
     * @param b Vertical skewing/rotation component (default: 0)
     * @param c Horizontal skewing/rotation component (default: 0)
     * @param d Vertical scaling/rotation component (default: 1)
     * @param tx Horizontal translation (default: 0)
     * @param ty Vertical translation (default: 0)
     */
    public function new(a:Float = 1, b:Float = 0, c:Float = 0, d:Float = 1, tx:Float = 0, ty:Float = 0) {

        this.a = a;
        this.b = b;
        this.c = c;
        this.d = d;
        this.tx = tx;
        this.ty = ty;
        _aPrev = a;
        _bPrev = b;
        _cPrev = c;
        _dPrev = d;
        _txPrev = tx;
        _tyPrev = ty;

        changed = false;
        changedDirty = false;

    }

    /**
     * Check if the transform has changed by comparing current values to previous values.
     * Updates the `changed` property. Call this before checking `changed` to ensure
     * the value is up to date.
     */
    #if !debug inline #end public function computeChanged() {

        if (changedDirty) {
            changed =
                tx != _txPrev ||
                ty != _tyPrev ||
                a != _aPrev ||
                b != _bPrev ||
                c != _cPrev ||
                d != _dPrev
            ;

            changedDirty = false;
        }

    }

    inline function didEmitChange():Void {

        cleanChangedState();

    }

    /**
     * Reset the change tracking state.
     * After calling this, `changed` will be false until the transform is modified again.
     */
    inline public function cleanChangedState():Void {

        _aPrev = a;
        _bPrev = b;
        _cPrev = c;
        _dPrev = d;
        _txPrev = tx;
        _tyPrev = ty;

        changed = false;

    }

    /**
     * Create a copy of this transform.
     * @return A new Transform with the same matrix values
     */
    inline public function clone():Transform {

        return new Transform(a, b, c, d, tx, ty);

    }

    /**
     * Concatenate (multiply) this transform with another transform.
     * The result is stored in this transform. This is equivalent to:
     * `this = this * m`
     * 
     * @param m The transform to concatenate with this one
     */
    inline public function concat(m:Transform):Void {

        var a1 = a * m.a + b * m.c;
        b = a * m.b + b * m.d;
        a = a1;

        var c1 = c * m.a + d * m.c;
        d = c * m.b + d * m.d;

        c = c1;

        var tx1 = tx * m.a + ty * m.c + m.tx;
        ty = tx * m.b + ty * m.d + m.ty;
        tx = tx1;

        changedDirty = true;

    }

    /**
     * Decompose the transform matrix into its component parts.
     * Extracts position, scale, rotation, and skew from the matrix.
     * 
     * @param output Optional DecomposedTransform to store the result (creates new if null)
     * @return The decomposed transform containing x, y, scaleX, scaleY, rotation, skewX, skewY
     */
    inline public function decompose(?output:DecomposedTransform):DecomposedTransform {

        if (output == null) output = new DecomposedTransform();

        output.pivotX = 0;
        output.pivotY = 0;

        output.skewX = -Math.atan2(-c, d);
        output.skewY = Math.atan2(b, a);

        var delta = Math.abs(output.skewX + output.skewY);

        if (delta < 0.00001) {
            
            output.rotation = output.skewY;

            if (a < 0 && d >= 0) {
                output.rotation += output.rotation <= 0 ? Math.PI : -Math.PI;
            }

            output.skewX = 0;
            output.skewY = 0;

        }

        output.scaleX = Math.sqrt((a * a) + (b * b));
        output.scaleY = Math.sqrt((c * c) + (d * d));

        output.x = tx;
        output.y = ty;

        return output;

    }

    /**
     * Set this transform from decomposed values.
     * Rebuilds the matrix from position, scale, rotation, and skew components.
     * 
     * @param decomposed The decomposed transform values to apply
     */
    inline public function setFromDecomposed(decomposed:DecomposedTransform):Void {

        setFromValues(decomposed.x, decomposed.y, decomposed.scaleX, decomposed.scaleY, decomposed.rotation, decomposed.skewX, decomposed.skewY, decomposed.pivotX, decomposed.pivotY);

    }

    /**
     * Set this transform from individual component values.
     * Rebuilds the matrix from position, scale, rotation, skew, and pivot.
     * 
     * @param x X position
     * @param y Y position
     * @param scaleX Horizontal scale factor
     * @param scaleY Vertical scale factor
     * @param rotation Rotation angle in radians
     * @param skewX Horizontal skew angle in radians
     * @param skewY Vertical skew angle in radians
     * @param pivotX X coordinate of the pivot point
     * @param pivotY Y coordinate of the pivot point
     */
    inline public function setFromValues(x:Float = 0, y:Float = 0, scaleX:Float = 1, scaleY:Float = 1, rotation:Float = 0, skewX:Float = 0, skewY:Float = 0, pivotX:Float = 0, pivotY:Float = 0):Void {

        identity();
        translate(-pivotX, -pivotY);
        if (skewX != 0) c = skewX * Math.PI / 180.0;
        if (skewY != 0) b = skewY * Math.PI / 180.0;
        if (rotation != 0) rotate(rotation * Math.PI / 180.0);
        translate(pivotX, pivotY);
        if (scaleX != 1.0 || scaleY != 1.0) scale(scaleX, scaleY);
        translate(
            x - pivotX * scaleX,
            y - pivotY * scaleY
        );

    }

    /**
     * Set this transform by interpolating between two other transforms.
     * Useful for animations and transitions.
     * 
     * @param transform1 The starting transform (used when ratio = 0)
     * @param transform2 The ending transform (used when ratio = 1)
     * @param ratio The interpolation factor (0 to 1)
     */
    inline public function setFromInterpolated(transform1:Transform, transform2:Transform, ratio:Float):Void {

        if (ratio == 0) {
            setToTransform(transform1);
        }
        else if (ratio == 1) {
            setToTransform(transform2);
        }
        else {
            transform1.decompose(_decomposed1);
            transform2.decompose(_decomposed2);
            _decomposed1.pivotX = _decomposed1.pivotX + (_decomposed2.pivotX - _decomposed1.pivotX) * ratio;
            _decomposed1.pivotY = _decomposed1.pivotY + (_decomposed2.pivotY - _decomposed1.pivotY) * ratio;
            _decomposed1.rotation = _decomposed1.rotation + (_decomposed2.rotation - _decomposed1.rotation) * ratio;
            _decomposed1.scaleX = _decomposed1.scaleX + (_decomposed2.scaleX - _decomposed1.scaleX) * ratio;
            _decomposed1.scaleY = _decomposed1.scaleY + (_decomposed2.scaleY - _decomposed1.scaleY) * ratio;
            _decomposed1.skewX = _decomposed1.skewX + (_decomposed2.skewX - _decomposed1.skewX) * ratio;
            _decomposed1.skewY = _decomposed1.skewY + (_decomposed2.skewY - _decomposed1.skewY) * ratio;
            _decomposed1.x = _decomposed1.x + (_decomposed2.x - _decomposed1.x) * ratio;
            _decomposed1.y = _decomposed1.y + (_decomposed2.y - _decomposed1.y) * ratio;
            setFromDecomposed(_decomposed1);
        }

    }

    /**
     * Transform a vector's X component without translation.
     * Useful for transforming directions or deltas.
     * 
     * @param x The X component of the vector
     * @param y The Y component of the vector
     * @return The transformed X component
     */
    inline public function deltaTransformX(x:Float, y:Float):Float {

        return x * a + y * c;

    }

    /**
     * Transform a vector's Y component without translation.
     * Useful for transforming directions or deltas.
     * 
     * @param x The X component of the vector
     * @param y The Y component of the vector
     * @return The transformed Y component
     */
    inline public function deltaTransformY(x:Float, y:Float):Float {

        return x * b + y * d;

    }

    /**
     * Check if this transform equals another transform.
     * Compares all matrix elements for exact equality.
     * 
     * @param transform The transform to compare with
     * @return true if all matrix elements are equal
     */
    inline public function equals(transform:Transform):Bool {

        return (transform != null && tx == transform.tx && ty == transform.ty && a == transform.a && b == transform.b && c == transform.c && d == transform.d);

    }

    /**
     * Reset this transform to the identity matrix.
     * The identity matrix has no translation, rotation, scale, or skew.
     * Equivalent to: a=1, b=0, c=0, d=1, tx=0, ty=0
     */
    inline public function identity():Void {

        a = 1;
        b = 0;
        c = 0;
        d = 1;
        tx = 0;
        ty = 0;

        changedDirty = true;

    }

    /**
     * Invert this transform matrix.
     * The inverted matrix can be used to reverse transformations.
     * If the matrix is not invertible (determinant = 0), sets to a degenerate state.
     */
    inline public function invert():Void {

        var norm = a * d - b * c;

        if (norm == 0) {

            a = b = c = d = 0;
            tx = -tx;
            ty = -ty;

        } else {

            norm = 1.0 / norm;
            var a1 = d * norm;
            d = a * norm;
            a = a1;
            b *= -norm;
            c *= -norm;

            var tx1 = - a * tx - c * ty;
            ty = - b * tx - d * ty;
            tx = tx1;

        }

        changedDirty = true;

    }

    /**
     * Rotate the transform by the specified angle.
     * The rotation is applied relative to the current transform.
     * 
     * @param angle The rotation angle in radians (use degrees * Math.PI / 180 to convert)
     */
    inline public function rotate(angle:Float):Void {

        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        var a1 = a * cos - b * sin;
        b = a * sin + b * cos;
        a = a1;

        var c1 = c * cos - d * sin;
        d = c * sin + d * cos;
        c = c1;

        var tx1 = tx * cos - ty * sin;
        ty = tx * sin + ty * cos;
        tx = tx1;

        changedDirty = true;

    }

    /**
     * Scale the transform by the specified factors.
     * The scaling is applied relative to the current transform.
     * 
     * @param x Horizontal scale factor
     * @param y Vertical scale factor
     */
    inline public function scale(x:Float, y:Float):Void {

        a *= x;
        b *= y;

        c *= x;
        d *= y;

        tx *= x;
        ty *= y;

        changedDirty = true;

    }

    /**
     * Translate (move) the transform by the specified offset.
     * The translation is applied relative to the current transform.
     * 
     * @param x Horizontal offset in pixels
     * @param y Vertical offset in pixels
     */
    inline public function translate(x:Float, y:Float):Void {

        tx += x;
        ty += y;

        changedDirty = true;

    }

    /**
     * Apply skew transformation.
     * Skewing shears the coordinate space along the X and Y axes.
     * 
     * @param skewX Horizontal skew angle in radians
     * @param skewY Vertical skew angle in radians
     */
    inline public function skew(skewX:Float, skewY:Float):Void {

        _tmp.identity();

        var sr = 0; // sin(0)
        var cr = 1; // cos(0)
        var cy = Math.cos(skewY);
        var sy = Math.sin(skewY);
        var nsx = -Math.sin(skewX);
        var cx = Math.cos(skewX);

        var a = cr;
        var b = sr;
        var c = -sr;
        var d = cr;

        _tmp.a = (cy * a) + (sy * c);
        _tmp.b = (cy * b) + (sy * d);
        _tmp.c = (nsx * a) + (cx * c);
        _tmp.d = (nsx * b) + (cx * d);

        concat(_tmp);

    }

    /**
     * Set the rotation and uniform scale directly.
     * This replaces the current rotation and scale, discarding any skew.
     * 
     * @param angle The rotation angle in radians
     * @param scale Uniform scale factor (default: 1)
     */
    inline public function setRotation(angle:Float, scale:Float = 1):Void {

        a = Math.cos(angle) * scale;
        c = Math.sin(angle) * scale;
        b = -c;
        d = a;

        changedDirty = true;

    }

    /**
     * Set all matrix values directly.
     * 
     * @param a Horizontal scaling/rotation component
     * @param b Vertical skewing/rotation component
     * @param c Horizontal skewing/rotation component
     * @param d Vertical scaling/rotation component
     * @param tx Horizontal translation
     * @param ty Vertical translation
     */
    inline public function setTo(a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float):Void {

        this.a = a;
        this.b = b;
        this.c = c;
        this.d = d;
        this.tx = tx;
        this.ty = ty;

        changedDirty = true;

    }

    /**
     * Copy all values from another transform.
     * 
     * @param transform The transform to copy from
     */
    inline public function setToTransform(transform:Transform):Void {

        this.a = transform.a;
        this.b = transform.b;
        this.c = transform.c;
        this.d = transform.d;
        this.tx = transform.tx;
        this.ty = transform.ty;

        changedDirty = true;

    }

    /**
     * Get a string representation of the transform.
     * Includes both matrix values and decomposed components.
     * 
     * @return String representation for debugging
     */
    public function toString():String {

        decompose(_decomposed1);
        return "(a=" + a + ", b=" + b + ", c=" + c + ", d=" + d + ", tx=" + tx + ", ty=" + ty + " " + _decomposed1 + ")";

    }


    /**
     * Transform a point's X coordinate.
     * Applies the full transformation including translation.
     * 
     * @param x The X coordinate of the point
     * @param y The Y coordinate of the point
     * @return The transformed X coordinate
     */
    inline public function transformX(x:Float, y:Float):Float {

        return x * a + y * c + tx;

    }


    /**
     * Transform a point's Y coordinate.
     * Applies the full transformation including translation.
     * 
     * @param x The X coordinate of the point
     * @param y The Y coordinate of the point
     * @return The transformed Y coordinate
     */
    inline public function transformY(x:Float, y:Float):Float {

        return x * b + y * d + ty;

    }

}
