package ceramic;

/**
 * Control how children depth is sorted.
 */
enum abstract ChildrenDepth(Int) from Int to Int {

    /**
     * Each child has a greater depth than the previous one.
     */
    var INCREMENT = 1;

    /**
     * Each child has a lower depth than the previous one.
     */
    var DECREMENT = -1;

    /**
     * Every children share the same depth.
     */
    var SAME = 0;

    /**
     * Depth if not set automatically.
     */
    var CUSTOM = 2;

}
