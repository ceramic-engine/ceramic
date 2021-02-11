package ceramic;

/** Control how children depth is sorted. */
enum ChildrenDepth {

    /** Each child has a greater depth than the previous one. */
    INCREMENT;

    /** Each child has a lower depth than the previous one. */
    DECREMENT;

    /** Every children share the same depth. */
    SAME;

}
