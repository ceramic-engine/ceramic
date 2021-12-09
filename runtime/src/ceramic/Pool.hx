package ceramic;

using ceramic.Extensions;

/**
 * A generic object pool utility.
 */
class Pool<T> {

    var availableItems:Array<T> = [];

    public function new() {}

    /**
     * Get an available item if any is ready to be used or `null` if none is available.
     */
    inline public function get():T {

        return (availableItems.length > 0) ? availableItems.pop() : null;

    }

    /**
     * Recycle an existing item so that it can be reused later
     */
    public function recycle(item:T):Void {

        availableItems.push(item);

    }

    public function clear():Void {

        if (availableItems.length > 0) {
            availableItems = [];
        }

    }

}
