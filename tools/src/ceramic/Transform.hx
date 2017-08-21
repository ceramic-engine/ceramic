package ceramic;

/** Decomposed transform holds rotation, translation, scale, skew and pivot informations.
    Provided by Transform.decompose() method.
    Angles are in radians. */
class DecomposedTransform {

    inline public function new() {}

    public var pivotX:Float = 0;

    public var pivotY:Float = 0;

    public var x:Float = 0;

    public var y:Float = 0;

    public var rotation:Float = 0;

    public var scaleX:Float = 1;

    public var scaleY:Float = 1;

    public var skewX:Float = 0;

    public var skewY:Float = 0;

}

// Portions of matrix manipulation code taken from OpenFL and PIXI

/** Transform holds matrix data to make 2d rotate, translate, scale and skew transformations.
    Angles are in degrees.
    Representation:
    | a | c | tx |
    | b | d | ty |
    | 0 | 0 | 1  | */
class Transform implements Events {

/// Events

    @event public function change();

/// Properties

    public var a:Float;

    public var b:Float;

    public var c:Float;

    public var d:Float;

    public var tx:Float;

    public var ty:Float;

    public var changed:Bool;

/// Internal

    static var _tmp = new Transform();

/// Code

    public function new(a:Float = 1, b:Float = 0, c:Float = 0, d:Float = 1, tx:Float = 0, ty:Float = 0) {

        this.a = a;
        this.b = b;
        this.c = c;
        this.d = d;
        this.tx = tx;
        this.ty = ty;

        changed = false;

    } //new

    inline function didEmitChange():Void {

        changed = false;

    } //didEmitChange

    inline public function clone():Transform {

        return new Transform(a, b, c, d, tx, ty);

    } //clone

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

        changed = true;

    } //concat

    inline public function copyFrom(other:Transform):Void {

        this.a = other.a;
        this.b = other.b;
        this.c = other.c;
        this.d = other.d;
        this.tx = other.tx;
        this.ty = other.ty;

    } //copyFrom

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

    } //decompose

    inline public function setFromDecomposed(decomposed:DecomposedTransform):Void {

        setFromValues(decomposed.x, decomposed.y, decomposed.pivotX, decomposed.pivotY, decomposed.scaleX, decomposed.scaleY, decomposed.rotation, decomposed.skewX, decomposed.skewY);

    } //setFromDecomposed

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

    } //setFromValues

    inline public function deltaTransformX(x:Float, y:Float):Float {

        return x * a + y * c;

    } //deltaTransformX

    inline public function deltaTransformY(x:Float, y:Float):Float {

        return x * b + y * d;

    } //deltaTransformY

    inline public function equals(transform:Transform):Bool {

        return (transform != null && tx == transform.tx && ty == transform.ty && a == transform.a && b == transform.b && c == transform.c && d == transform.d);

    } //equals

    inline public function identity():Void {

        a = 1;
        b = 0;
        c = 0;
        d = 1;
        tx = 0;
        ty = 0;

        changed = true;

    } //identity

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

        changed = true;

    } //invert

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

        changed = true;

    } //rotate

    inline public function scale(x:Float, y:Float):Void {

        a *= x;
        b *= y;

        c *= x;
        d *= y;

        tx *= x;
        ty *= y;

        changed = true;

    } //scale

    inline public function translate(x:Float, y:Float):Void {

        tx += x;
        ty += y;

        changed = true;

    } //translate

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

    } //translate

    inline public function setRotation(angle:Float, scale:Float = 1):Void {

        a = Math.cos(angle) * scale;
        c = Math.sin(angle) * scale;
        b = -c;
        d = a;

        changed = true;

    } //setRotation

    inline public function setTo(a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float):Void {

        this.a = a;
        this.b = b;
        this.c = c;
        this.d = d;
        this.tx = tx;
        this.ty = ty;

        changed = true;

    } //setTo

    public function toString():String {

        return "(a=" + a + ", b=" + b + ", c=" + c + ", d=" + d + ", tx=" + tx + ", ty=" + ty + ")";

    } //toString


    inline public function transformX(x:Float, y:Float):Float {

        return x * a + y * c + tx;

    } //transformX


    inline public function transformY(x:Float, y:Float):Float {

        return x * b + y * d + ty;

    } //transformY

} //Transform
