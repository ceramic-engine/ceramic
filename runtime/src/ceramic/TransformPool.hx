package ceramic;

using ceramic.Extensions;

/** An utility to reuse transform matrix object at application level. */
class TransformPool {

    static var availableTransforms:Array<Transform> = [];

    /** Get or create a transform. The transform object is ready to be used. */
    inline public static function get():Transform {

        return (availableTransforms.length > 0) ? availableTransforms.pop() : new Transform();

    } //get

    /** Recycle an existing transform. The transform will be cleaned up. */
    public static function recycle(transform:Transform):Void {

        transform.offChange();

        transform.a = 1;
        transform.b = 0;
        transform.c = 0;
        transform.d = 1;
        transform.tx = 0;
        transform.ty = 0;
        transform._aPrev = 1;
        transform._bPrev = 0;
        transform._cPrev = 0;
        transform._dPrev = 1;
        transform._txPrev = 0;
        transform._tyPrev = 0;

        transform.changed = false;
        transform.changedDirty = false;

        availableTransforms.push(transform);

    } //recycle

    public static function clear():Void {
        
        if (availableTransforms.length > 0) {
            availableTransforms = [];
        }

    } //clear

} //TransformPool