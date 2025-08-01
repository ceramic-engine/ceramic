package ceramic;

using ceramic.Extensions;

/**
 * An utility to reuse transform matrix object at application level.
 * 
 * TransformPool provides object pooling for Transform instances to reduce
 * garbage collection pressure and improve performance when working with
 * many temporary transform matrices.
 * 
 * Features:
 * - Get pooled Transform instances instead of creating new ones
 * - Recycle transforms when done to return them to the pool
 * - Automatic cleanup of recycled transforms
 * - Static pool shared across the application
 * 
 * Example usage:
 * ```haxe
 * // Get a transform from the pool
 * var transform = TransformPool.get();
 * 
 * // Use the transform
 * transform.translate(100, 200);
 * visual.transform = transform;
 * 
 * // When done, recycle it back to the pool
 * TransformPool.recycle(transform);
 * ```
 * 
 * @see Transform
 */
class TransformPool {

    static var availableTransforms:Array<Transform> = [];

    /**
     * Get or create a transform. The transform object is ready to be used.
     */
    inline public static function get():Transform {

        return (availableTransforms.length > 0) ? availableTransforms.pop() : new Transform();

    }

    /**
     * Recycle an existing transform. The transform will be cleaned up.
     */
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

    }

    /**
     * Clears the pool, removing all available transforms.
     * Use this to free memory if the pool has grown too large.
     */
    public static function clear():Void {
        
        if (availableTransforms.length > 0) {
            availableTransforms = [];
        }

    }

}