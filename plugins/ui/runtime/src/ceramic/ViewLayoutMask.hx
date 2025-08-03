package ceramic;

/**
 * Bit mask that defines layout constraints for views.
 * 
 * Controls how views can resize during layout computation:
 * - Whether width/height can increase or decrease
 * - Flexibility in one or both dimensions
 * - Fixed size constraints
 * 
 * Layout masks are used by parent containers to communicate
 * sizing constraints to their children during layout passes.
 * 
 * @example
 * ```haxe
 * // Allow view to grow but not shrink
 * var mask = ViewLayoutMask.INCREASE;
 * 
 * // Allow flexible width only
 * var mask = ViewLayoutMask.FLEXIBLE_WIDTH;
 * 
 * // Check constraints
 * if (mask.canIncreaseWidth()) {
 *     // Width can grow
 * }
 * ```
 */
abstract ViewLayoutMask(Int) from Int to Int {

    inline public function new(value:Int) {
        this = value;
    }

    /**
     * Allow the view to increase its width beyond its natural size.
     */
    #if !completion inline #end public static var INCREASE_WIDTH = new ViewLayoutMask(1 << 0);

    /**
     * Allow the view to decrease its width below its natural size.
     */
    #if !completion inline #end public static var DECREASE_WIDTH = new ViewLayoutMask(1 << 1);

    /**
     * Allow the view to increase its height beyond its natural size.
     */
    #if !completion inline #end public static var INCREASE_HEIGHT = new ViewLayoutMask(1 << 2);

    /**
     * Allow the view to decrease its height below its natural size.
     */
    #if !completion inline #end public static var DECREASE_HEIGHT = new ViewLayoutMask(1 << 3);

    /**
     * View cannot change size in any dimension.
     * The view must maintain its exact computed size.
     */
    #if !completion inline #end public static var FIXED = new ViewLayoutMask(0);

    /**
     * View can freely resize its width (both increase and decrease).
     * Height remains constrained.
     */
    #if !completion inline #end public static var FLEXIBLE_WIDTH = new ViewLayoutMask(INCREASE_WIDTH | DECREASE_WIDTH);

    /**
     * View can freely resize its height (both increase and decrease).
     * Width remains constrained.
     */
    #if !completion inline #end public static var FLEXIBLE_HEIGHT = new ViewLayoutMask(INCREASE_HEIGHT | DECREASE_HEIGHT);

    /**
     * View can freely resize in both dimensions.
     * This is the most permissive constraint.
     */
    #if !completion inline #end public static var FLEXIBLE = new ViewLayoutMask(FLEXIBLE_WIDTH | FLEXIBLE_HEIGHT);

    /**
     * View can increase size in both dimensions but cannot shrink.
     * Useful for content that should expand to fill space.
     */
    #if !completion inline #end public static var INCREASE = new ViewLayoutMask(INCREASE_WIDTH | INCREASE_HEIGHT);

    /**
     * View can decrease size in both dimensions but cannot grow.
     * Useful for content that should shrink to fit constraints.
     */
    #if !completion inline #end public static var DECREASE = new ViewLayoutMask(DECREASE_WIDTH | DECREASE_HEIGHT);

/// Layout helpers

    /**
     * Check or set whether the view can increase its width.
     * @param value Optional: if provided, sets the flag and returns the new value
     * @return true if width can increase
     */
    inline public function canIncreaseWidth(?value:Bool) {
        if (value == null) {
            return (this & INCREASE_WIDTH) == INCREASE_WIDTH;
        } else {
            this = value ? this | INCREASE_WIDTH : this & ~(INCREASE_WIDTH);
            return value;
        }
    }

    /**
     * Check or set whether the view can decrease its width.
     * @param value Optional: if provided, sets the flag and returns the new value
     * @return true if width can decrease
     */
    inline public function canDecreaseWidth(?value:Bool) {
        if (value == null) {
            return (this & DECREASE_WIDTH) == DECREASE_WIDTH;
        } else {
            this = value ? this | DECREASE_WIDTH : this & ~(DECREASE_WIDTH);
            return value;
        }
    }

    /**
     * Check or set whether the view can increase its height.
     * @param value Optional: if provided, sets the flag and returns the new value
     * @return true if height can increase
     */
    inline public function canIncreaseHeight(?value:Bool) {
        if (value == null) {
            return (this & INCREASE_HEIGHT) == INCREASE_HEIGHT;
        } else {
            this = value ? this | INCREASE_HEIGHT : this & ~(INCREASE_HEIGHT);
            return value;
        }
    }

    /**
     * Check or set whether the view can decrease its height.
     * @param value Optional: if provided, sets the flag and returns the new value
     * @return true if height can decrease
     */
    inline public function canDecreaseHeight(?value:Bool) {
        if (value == null) {
            return (this & DECREASE_HEIGHT) == DECREASE_HEIGHT;
        } else {
            this = value ? this | DECREASE_HEIGHT : this & ~(DECREASE_HEIGHT);
            return value;
        }
    }

/// Print

    /**
     * Convert the layout mask to a human-readable string.
     * @return String representation of the mask (e.g., "FLEXIBLE", "FIXED")
     */
    function toString():String {

        if (this == INCREASE_WIDTH) return 'INCREASE_WIDTH';
        if (this == DECREASE_WIDTH) return 'DECREASE_WIDTH';
        if (this == INCREASE_HEIGHT) return 'INCREASE_HEIGHT';
        if (this == DECREASE_HEIGHT) return 'DECREASE_HEIGHT';
        if (this == FIXED) return 'FIXED';
        if (this == FLEXIBLE_WIDTH) return 'FLEXIBLE_WIDTH';
        if (this == FLEXIBLE_HEIGHT) return 'FLEXIBLE_HEIGHT';
        if (this == FLEXIBLE) return 'FLEXIBLE';
        if (this == INCREASE) return 'INCREASE';
        if (this == DECREASE) return 'DECREASE';
        return ''+this;

    }

}
