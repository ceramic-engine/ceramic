package ceramic;

import ceramic.macros.EnumAbstractMacro;

/**
 * Determines how child elements are assigned depth values in the UI hierarchy.
 * Controls the automatic depth assignment strategy for child elements within
 * containers like View and Layout components.
 *
 * @see View
 * @see LinearLayout
 * @see LayersLayout
 */
enum abstract ChildrenDepth(Int) from Int to Int {

    /**
     * Each child has a greater depth than the previous one.
     * Children are layered front-to-back, with later children appearing on top.
     * This is the most common mode for UI containers.
     * 
     * @example
     * ```haxe
     * view.childrenDepth = INCREMENT;
     * // Child 0: depth = 0
     * // Child 1: depth = 1  
     * // Child 2: depth = 2
     * ```
     */
    var INCREMENT = 1;

    /**
     * Each child has a lower depth than the previous one.
     * Children are layered back-to-front, with earlier children appearing on top.
     * Useful for reverse stacking order.
     * 
     * @example
     * ```haxe
     * view.childrenDepth = DECREMENT;
     * // Child 0: depth = 0
     * // Child 1: depth = -1
     * // Child 2: depth = -2
     * ```
     */
    var DECREMENT = -1;

    /**
     * Every child shares the same depth value.
     * All children are rendered at the same z-order level.
     * Their relative ordering is determined by their index in the children array.
     * 
     * @example
     * ```haxe
     * view.childrenDepth = SAME;
     * // All children have depth = 0
     * ```
     */
    var SAME = 0;

    /**
     * Depth values are not automatically assigned.
     * Each child's depth must be set manually.
     * Provides full control over layering when automatic assignment isn't suitable.
     * 
     * @example
     * ```haxe
     * view.childrenDepth = CUSTOM;
     * // Must set depth manually:
     * child1.depth = 10;
     * child2.depth = 5;
     * child3.depth = 15;
     * ```
     */
    var CUSTOM = 2;

    /**
     * Returns a string representation of this enum value.
     * @return The name of the enum constant (e.g., "INCREMENT", "DECREMENT", etc.)
     */
    public function toString() {
        return EnumAbstractMacro.toStringSwitch(ChildrenDepth, abstract);
    }

}
