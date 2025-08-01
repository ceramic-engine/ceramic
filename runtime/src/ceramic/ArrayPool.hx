package ceramic;

/**
 * A pool system for efficiently reusing arrays of fixed sizes.
 * 
 * ArrayPool reduces garbage collection pressure by reusing arrays instead of
 * creating new ones. It maintains pools of arrays organized by size ranges,
 * automatically returning arrays to the pool when they're no longer needed.
 * 
 * The pool uses predefined size buckets (10, 100, 1000, 10000, 100000) and
 * automatically selects the appropriate pool based on the requested size.
 * 
 * Example usage:
 * ```haxe
 * // Get an array from the pool
 * var pool = ArrayPool.pool(50);
 * var array = pool.get();
 * 
 * // Use the array
 * for (i in 0...50) {
 *     array[i] = i * 2;
 * }
 * 
 * // Return to pool when done
 * pool.release(array);
 * ```
 * 
 * @see ReusableArray
 */
class ArrayPool {

    static var ALLOC_STEP = 10;

/// Factory

    /** Pool for arrays up to 10 elements */
    static var dynPool10:ArrayPool = new ArrayPool(10);

    /** Pool for arrays up to 100 elements */
    static var dynPool100:ArrayPool = new ArrayPool(100);

    /** Pool for arrays up to 1,000 elements */
    static var dynPool1000:ArrayPool = new ArrayPool(1000);

    /** Pool for arrays up to 10,000 elements */
    static var dynPool10000:ArrayPool = new ArrayPool(10000);

    /** Pool for arrays up to 100,000 elements */
    static var dynPool100000:ArrayPool = new ArrayPool(100000);

    /** Flag to prevent spamming warnings about large pools */
    static var didNotifyLargePool:Bool = false;

    /**
     * Gets an appropriate array pool for the requested size.
     * Automatically selects from predefined pools based on size ranges.
     * For sizes over 100,000, creates a temporary pool (not recommended).
     * 
     * @param size The maximum size of arrays needed
     * @return An ArrayPool instance suitable for the requested size
     */
    public static function pool(size:Int):ArrayPool {

        if (size <= 10) {
            return cast dynPool10;
        }
        else if (size <= 100) {
            return cast dynPool100;
        }
        else if (size <= 1000) {
            return cast dynPool1000;
        }
        else if (size <= 10000) {
            return cast dynPool10000;
        }
        else if (size <= 100000) {
            return cast dynPool100000;
        }
        else {
            if (!didNotifyLargePool) {
                didNotifyLargePool = true;
                Timer.delay(null, 0.5, () -> {
                    didNotifyLargePool = false;
                });

                ceramic.Shortcuts.log.warning('You should avoid asking a pool for arrays with more than 100000 elements (asked: $size) because it needs allocating a temporary one-time pool each time for that.');
            }
            return new ArrayPool(size);
        }

    }

/// Properties

    /** Storage for pooled arrays */
    var arrays:ReusableArray<Any> = null;

    /** Index of the next available slot in the pool */
    var nextFree:Int = 0;

    /** The size of arrays managed by this pool */
    var arrayLengths:Int;

/// Lifecycle

    /**
     * Creates a new ArrayPool for arrays of the specified size.
     * @param arrayLengths The size of arrays this pool will manage
     */
    public function new(arrayLengths:Int) {

        this.arrayLengths = arrayLengths;

    }

/// Public API

    /**
     * Gets a reusable array from the pool.
     * The array may contain old data and should be cleared if needed.
     * @return A ReusableArray instance of the pool's configured size
     */
    public function get(#if ceramic_debug_array_pool ?pos:haxe.PosInfos #end):ReusableArray<Any> {

        #if ceramic_debug_array_pool
        haxe.Log.trace('pool.get', pos);
        #end

        if (arrays == null) arrays = new ReusableArray(ALLOC_STEP);
        else if (nextFree >= arrays.length) arrays.length += ALLOC_STEP;

        var result:ReusableArray<Any> = arrays.get(nextFree);
        if (result == null) {
            result = new ReusableArray(arrayLengths);
            arrays.set(nextFree, result);
        }
        @:privateAccess result._poolIndex = nextFree;

        // Compute next free item
        while (true) {
            nextFree++;
            if (nextFree == arrays.length) break;
            var item:ReusableArray<Any> = arrays.get(nextFree);
            if (item == null) break;
            if (@:privateAccess item._poolIndex == -1) break;
        }
        
        return cast result;

    }

    /**
     * Returns an array to the pool for reuse.
     * The array is automatically cleared (all elements set to null).
     * @param array The array to return to the pool
     */
    public function release(array:ReusableArray<Any>):Void {
        
        #if ceramic_debug_array_pool
        haxe.Log.trace('pool.release', pos);
        #end

        var poolIndex = @:privateAccess array._poolIndex;
        @:privateAccess array._poolIndex = -1;
        if (nextFree > poolIndex) nextFree = poolIndex;
        for (i in 0...array.length) {
            array.set(i, null);
        }

    }

}
