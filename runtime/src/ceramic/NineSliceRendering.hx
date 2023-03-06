package ceramic;

/**
 * Define how a slice (form a `NineSlice` object) should be rendered.
 */
enum abstract NineSliceRendering(Int) from Int to Int {

    /**
     * The slice should not be rendered at all
     */
    var NONE = 0;

    /**
     * The slice should be stretched to fill the area
     */
    var STRETCH = 1;

    /**
     * The slice should be repeated to cover the area
     */
    var REPEAT = 2;

    /**
     * The slice should be repeated and mirrored to cover the area
     */
    var MIRROR = 3;

}