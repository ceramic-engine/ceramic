package ceramic;

using ceramic.Extensions;

/**
 * Iterator for the Touches collection.
 * 
 * TouchesIterator enables for-in loop iteration over active touch points.
 * It automatically skips null entries in the underlying IntMap for
 * efficient iteration over only valid touches.
 * 
 * This iterator is created automatically when using for-in loops with
 * a Touches collection and should not be instantiated directly.
 * 
 * @see Touches
 * @see Touch
 */
class TouchesIterator {

    var intMap:IntMap<Touch>;

    var i:Int;

    var len:Int;

    @:allow(ceramic.Touches)
    inline private function new(intMap:IntMap<Touch>) {

        this.intMap = intMap;
        i = 0;
        len = this.intMap.values.length;

    }

    /**
     * Checks if there are more touches to iterate over.
     * Automatically skips null entries in the collection.
     * @return True if there are more touches available
     */
    inline public function hasNext():Bool {

        // Skip null items
        while (i < len && intMap.values.get(i) == null) {
            i++;
        }

        return i < len;
    }

    /**
     * Returns the next touch in the iteration.
     * @return The next Touch object
     */
    inline public function next():Touch {

        var n = i++;
        return intMap.values.get(n);

    }

}
