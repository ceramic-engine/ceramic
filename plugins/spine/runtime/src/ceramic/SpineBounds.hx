package ceramic;

/**
 * Data structure representing the computed bounding box of a Spine animation.
 * This class provides both storage for bounds data and utilities to extract
 * bounds from a Spine instance without permanently modifying it.
 * 
 * The bounds include both dimensions (width/height) and anchor point information,
 * which together define the full bounding rectangle of the visible Spine content.
 */
class SpineBounds {

    /**
     * The horizontal anchor position (0-1 range) within the bounding box.
     * A value of 0 means the anchor is at the left edge, 0.5 is centered,
     * and 1 is at the right edge. This affects how the Spine content is
     * positioned relative to its x coordinate.
     */
    public var anchorX:Float = 0;

    /**
     * The vertical anchor position (0-1 range) within the bounding box.
     * A value of 0 means the anchor is at the top edge, 0.5 is centered,
     * and 1 is at the bottom edge. This affects how the Spine content is
     * positioned relative to its y coordinate.
     */
    public var anchorY:Float = 0;

    /**
     * The width of the bounding box in pixels.
     * This represents the horizontal extent of all visible Spine content.
     */
    public var width:Float = 0;

    /**
     * The height of the bounding box in pixels.
     * This represents the vertical extent of all visible Spine content.
     */
    public var height:Float = 0;

    /**
     * Creates a new SpineBounds instance with default values.
     * All properties are initialized to 0.
     */
    public function new() {}

    /**
     * Computes the bounding box of a Spine instance and extracts the bounds data.
     * This method temporarily modifies the Spine instance to compute accurate bounds,
     * then restores all original values, ensuring the Spine object remains unchanged.
     * 
     * This is useful when you need to know the exact dimensions of Spine content
     * without affecting its current state or visual appearance.
     * 
     * @param spine The Spine instance to compute bounds for
     * @param bounds Optional existing SpineBounds object to populate. If null, a new instance is created
     * @return The populated SpineBounds object containing the computed dimensions and anchor points
     * 
     * ```haxe
     * var spine = new Spine();
     * spine.load(spineData);
     * 
     * // Get the bounds without modifying the spine instance
     * var bounds = SpineBounds.computeAndExtractBounds(spine);
     * trace('Spine dimensions: ${bounds.width}x${bounds.height}');
     * trace('Anchor point: (${bounds.anchorX}, ${bounds.anchorY})');
     * ```
     */
    public static function computeAndExtractBounds(spine:Spine, ?bounds:SpineBounds):SpineBounds {

        if (bounds == null)
            bounds = new SpineBounds();

        // Maybe we should find another solution that doesn't mutate spine object
        var prevSkeletonOriginX = spine.skeletonOriginX;
        var prevSkeletonOriginY = spine.skeletonOriginY;
        var prevWidth = spine.width;
        var prevHeight = spine.height;
        var prevAnchorX = spine.anchorX;
        var prevAnchorY = spine.anchorY;
        var prevX = spine.x;
        var prevY = spine.y;
        @:privateAccess spine.computeBounds();
        bounds.anchorX = spine.anchorX;
        bounds.anchorY = spine.anchorY;
        bounds.width = spine.width;
        bounds.height = spine.height;
        spine.skeletonOriginX = prevSkeletonOriginX;
        spine.skeletonOriginY = prevSkeletonOriginY;
        spine.width = prevWidth;
        spine.height = prevHeight;
        spine.anchorX = prevAnchorX;
        spine.anchorY = prevAnchorY;
        spine.x = prevX;
        spine.y = prevY;

        return bounds;

    }

}
