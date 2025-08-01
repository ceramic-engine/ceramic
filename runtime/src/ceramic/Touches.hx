package ceramic;

/**
 * A collection of active touch points for multi-touch handling.
 * 
 * Touches provides an efficient way to access and iterate over all
 * current touch points on the screen. It's implemented as an abstract
 * over IntMap for performance, mapping touch indices to Touch objects.
 * 
 * This collection is typically accessed through screen.touches and is
 * automatically updated by the input system.
 * 
 * Example usage:
 * ```haxe
 * // Access a specific touch by index
 * var touch = screen.touches.get(0);
 * 
 * // Iterate over all active touches
 * for (touch in screen.touches) {
 *     trace('Touch ${touch.index} at ${touch.x}, ${touch.y}');
 * }
 * ```
 * 
 * @see Touch
 * @see Screen
 * @see TouchesIterator
 */
abstract Touches(IntMap<Touch>) {

    /**
     * Creates a new Touches collection.
     * Initialized with a capacity of 8 touches (suitable for most devices).
     */
    inline public function new() {

        this = new IntMap<Touch>(8, 0.5, false);

    }

    /**
     * Gets a touch by its index.
     * @param touchIndex The index of the touch to retrieve
     * @return The Touch object, or null if not found
     */
    inline public function get(touchIndex:Int):Touch {

        return this.get(touchIndex);

    }

    /**
     * Sets or updates a touch in the collection.
     * @param touchIndex The index of the touch
     * @param touch The Touch object to store
     */
    inline public function set(touchIndex:Int, touch:Touch):Void {

        this.set(touchIndex, touch);

    }

    /**
     * Returns an iterator for iterating over all active touches.
     * Allows using for-in loops with the touches collection.
     * @return A TouchesIterator instance
     */
	inline public function iterator():TouchesIterator {

        return new TouchesIterator(this);

    }

}

