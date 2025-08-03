package ceramic;

/**
 * A flow-based layout for CollectionView that arranges items in rows or columns.
 * 
 * Items flow from left to right (vertical scrolling) or top to bottom (horizontal scrolling),
 * wrapping to the next row/column when they exceed the container bounds.
 * 
 * Features:
 * - Automatic row/column wrapping
 * - Configurable item spacing
 * - Start/end insets for padding
 * - Item sizing constraints
 * - Efficient visibility culling
 * 
 * @example
 * ```haxe
 * var layout = new CollectionViewFlowLayout();
 * layout.itemSpacingX = 10;
 * layout.itemSpacingY = 10;
 * layout.insetStart = 20;
 * layout.insetEnd = 20;
 * 
 * // Make items take 50% of container width
 * layout.itemSizing = 0.5;
 * 
 * collectionView.collectionViewLayout = layout;
 * ```
 * 
 * @see CollectionView
 * @see CollectionViewLayout
 */
class CollectionViewFlowLayout implements CollectionViewLayout {

    /**
     * Controls item sizing relative to container dimensions.
     * - For vertical scrolling: Controls item width (0.0-1.0 = percentage of container width)
     * - For horizontal scrolling: Controls item height (0.0-1.0 = percentage of container height)
     * - Values <= 0: No sizing constraint applied
     * Default is -1.0 (no constraint).
     */
    public var itemSizing:Float = -1.0;

    /**
     * Padding at the start of the scrollable content.
     * - For vertical scrolling: Top padding
     * - For horizontal scrolling: Left padding
     * Default is 0.0.
     */
    public var insetStart:Float = 0.0;

    /**
     * Padding at the end of the scrollable content.
     * - For vertical scrolling: Bottom padding
     * - For horizontal scrolling: Right padding
     * Default is 0.0.
     */
    public var insetEnd:Float = 0.0;

    /**
     * Horizontal spacing between items in pixels.
     * Default is 0.0.
     */
    public var itemSpacingX:Float = 0.0;

    /**
     * Vertical spacing between items in pixels.
     * Default is 0.0.
     */
    public var itemSpacingY:Float = 0.0;

    /**
     * Extra margin beyond the visible area for pre-rendering items.
     * Items within this margin will be considered visible to reduce pop-in.
     * Larger values improve smoothness but use more memory.
     * Default is 0.0.
     */
    public var visibleOutset:Float = 0.0;

    /**
     * When true, all items are considered visible regardless of scroll position.
     * Useful for small collections where culling overhead exceeds rendering cost.
     * Default is false.
     */
    public var allItemsVisible:Bool = false;

    /**
     * Creates a new flow layout with default settings.
     */
    public function new() {

    }

    /**
     * Performs the layout calculation for all items.
     * Arranges items in a flow pattern, wrapping to new rows/columns as needed.
     * Also calculates the total content size for scrolling.
     * 
     * @param collectionView The collection view being laid out
     * @param frames Array of item frames to position (x, y will be set)
     */
    public function collectionViewLayout(collectionView:CollectionView, frames:ReadOnlyArray<CollectionViewItemFrame>):Void {

        var x = 0.0;
        var y = 0.0;
        var maxX = 0.0;
        var maxY = 0.0;

        var direction = collectionView.direction;
        var width = collectionView.width;
        var height = collectionView.height;

        if (direction == VERTICAL) {

            y += insetStart;
            maxY = y;

            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);

                // Fit item width
                if (itemSizing > 0) {
                    frame.width = Math.min(width, width * itemSizing);
                }
                if (x > 0 && x + frame.width > width) {
                    x = 0;
                    y = maxY + itemSpacingY;
                }
                frame.x = x;
                frame.y = y;
                maxY = Math.max(maxY, y + frame.height);
                x += frame.width + itemSpacingX;
            }

            collectionView.contentSize = maxY + insetEnd;

        }
        else { // HORIZONTAL

            x += insetStart;
            maxX = x;

            for (i in 0...frames.length) {
                var frame = frames.unsafeGet(i);

                // Fit item height
                if (itemSizing > 0) {
                    frame.height = Math.min(height, height * itemSizing);
                }
                if (y > 0 && y + frame.height > height) {
                    y = 0;
                    x = maxX + itemSpacingX;
                }
                frame.x = x;
                frame.y = y;
                maxX = Math.max(maxX, x + frame.width);
                y += frame.height + itemSpacingY;
            }

            collectionView.contentSize = maxX + insetEnd;

        }

    }

    /**
     * Determines if an item frame is within the visible area.
     * Takes into account the visibleOutset for pre-rendering nearby items.
     * 
     * @param collectionView The collection view to test against
     * @param frame The item frame to check
     * @return true if the frame is visible or within the outset margin
     */
    public function isFrameVisible(collectionView:CollectionView, frame:CollectionViewItemFrame):Bool {

        if (allItemsVisible) return true;

        if (collectionView.direction == VERTICAL) {
            var minY = -collectionView.scroller.scrollTransform.ty - visibleOutset;
            var maxY = minY + collectionView.height + visibleOutset * 2;
            return (frame.y < maxY && frame.y + frame.height >= minY);
        }
        else {
            var minX = -collectionView.scroller.scrollTransform.tx - visibleOutset;
            var maxX = minX + collectionView.width + visibleOutset * 2;
            return (frame.x < maxX && frame.x + frame.width >= minX);
        }

    }

}
