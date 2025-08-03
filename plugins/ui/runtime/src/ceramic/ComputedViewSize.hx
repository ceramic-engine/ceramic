package ceramic;

/**
 * Represents computed size information for a View during the layout process.
 * 
 * This class is used internally by the View system to pass sizing constraints
 * and computed dimensions between parent and child views during layout calculations.
 * It supports object pooling for performance optimization.
 * 
 * The NO_SIZE constant indicates that a dimension has not been computed or constrained.
 * 
 * @see View
 * @see ViewLayoutMask
 */
@:structInit
class ComputedViewSize {

    /**
     * Sentinel value indicating that a size dimension has not been set or computed.
     * This special value is used to distinguish unset dimensions from zero dimensions.
     */
    public static final NO_SIZE:Float = -2147483640;

    /**
     * Object pool for recycling ComputedViewSize instances.
     * Reduces allocation overhead during frequent layout calculations.
     */
    static var _pool:Pool<ComputedViewSize> = new Pool();

    /**
     * The layout mask from the parent view, indicating sizing constraints.
     * Determines how the child view should calculate its dimensions.
     * Default is FLEXIBLE.
     */
    public var parentLayoutMask:ViewLayoutMask = ViewLayoutMask.FLEXIBLE;

    /**
     * The width constraint from the parent view.
     * May be NO_SIZE if no width constraint is imposed.
     */
    public var parentWidth:Float = NO_SIZE;

    /**
     * The height constraint from the parent view.
     * May be NO_SIZE if no height constraint is imposed.
     */
    public var parentHeight:Float = NO_SIZE;

    /**
     * The computed width for the view after layout calculation.
     * Set by the view during its computeSize phase.
     */
    public var computedWidth:Float = NO_SIZE;

    /**
     * The computed height for the view after layout calculation.
     * Set by the view during its computeSize phase.
     */
    public var computedHeight:Float = NO_SIZE;

    /**
     * Special computed width for content fitting scenarios.
     * Used by views like TextView that need to calculate their ideal width
     * based on content before applying constraints.
     */
    public var computedFitWidth:Float = NO_SIZE;

    /**
     * Returns this instance to the object pool for reuse.
     * Should be called when the instance is no longer needed.
     */
    public function recycle() {
        _pool.recycle(this);
    }

    /**
     * Gets a ComputedViewSize instance from the object pool.
     * The instance is reset to default values before being returned.
     * 
     * @return A reset ComputedViewSize instance ready for use
     */
    public static function get():ComputedViewSize {
        if (_pool == null) {
            _pool = new Pool();
        }
        var item:ComputedViewSize = _pool.get();
        if (item == null) {
            item = {};
        }

        item.parentLayoutMask = ViewLayoutMask.FLEXIBLE;
        item.parentWidth = NO_SIZE;
        item.parentHeight = NO_SIZE;
        item.computedWidth = NO_SIZE;
        item.computedHeight = NO_SIZE;
        item.computedFitWidth = NO_SIZE;

        return item;
    }

}
