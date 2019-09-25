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

    function toString():String {
        return '(pos=$x,$y pivot=$pivotX,$pivotY rotation=$rotation scale=${(scaleX == scaleY ? '' + scaleX : scaleX + ',' + scaleY)} skew=$skewX,$skewY)';
    }

} //DecomposedTransform
