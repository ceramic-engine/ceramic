package ceramic;

/**
 * A layout container that stacks children on top of each other like layers.
 *
 * LayersLayout positions all children at the same location (with offsets applied),
 * creating a stack where each child view overlaps the previous ones. The layout
 * automatically adjusts its size to fit the largest child.
 *
 * Key features:
 * - Children are stacked with increasing depth values
 * - Container size adapts to the largest child
 * - Each child can have independent positioning via offsets
 * - Supports padding that affects all children
 *
 * Common use cases:
 * - Card stacks or overlapping UI elements
 * - Background/foreground layering
 * - Overlay containers
 * - Z-ordered visual effects
 *
 * @example
 * ```haxe
 * var layers = new LayersLayout();
 * layers.padding(20);
 *
 * // Add background layer
 * var bg = new View();
 * bg.viewSize(ViewSize.fill(), ViewSize.fill());
 * bg.transparent = false;
 * bg.color = Color.GRAY;
 * layers.add(bg);
 *
 * // Add content layer on top
 * var content = new TextView();
 * content.text = "Layered Content";
 * content.offsetX = 10; // Offset from padding
 * content.offsetY = 10;
 * layers.add(content);
 * ```
 *
 * @see View
 * @see LinearLayout for sequential layouts
 */
class LayersLayout extends View {

    /**
     * Creates a new LayersLayout.
     * The layout is transparent by default to show layered content.
     */
    public function new() {

        super();

        transparent = true;

    }

    /**
     * Computes the layout size based on the largest child dimensions.
     * The final size is the maximum width and height among all active children,
     * plus any padding.
     */
    override function computeSize(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask, persist:Bool) {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, parentWidth);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, parentHeight);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, parentWidth);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, parentHeight);

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.info('$this.computeSize($parentWidth $parentHeight $parentLayoutMask $persist) $paddingTop $paddingRight $paddingBottom $paddingLeft');
        ceramic.Shortcuts.log.pushIndent();
        #end

        super.computeSize(parentWidth, parentHeight, parentLayoutMask, persist);

        var computedWidth = computedSize.computedWidth;
        var computedHeight = computedSize.computedHeight;

        var layoutMask = ViewLayoutMask.FLEXIBLE;
        var hasExplicitWidth = !ViewSize.isAuto(viewWidth);
        var hasExplicitHeight = !ViewSize.isAuto(viewHeight);
        var maximumWidth = 0.0;
        var maximumHeight = 0.0;

        if (hasExplicitWidth) {
            computedWidth -= paddingLeft + paddingRight;
        }
        else {
            if (!parentLayoutMask.canIncreaseWidth()) {
                computedWidth -= paddingLeft + paddingRight;
            }
        }

        if (hasExplicitHeight) {
            computedHeight -= paddingTop + paddingBottom;
        }
        else {
            if (!parentLayoutMask.canIncreaseHeight()) {
                computedHeight -= paddingTop + paddingBottom;
            }
        }

        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews.unsafeGet(i);
                if (view.active) {

                    view.computeSizeIfNeeded(computedWidth, computedHeight, layoutMask, false);

                    // Compute maximum width
                    if (view.computedSize.computedWidth > maximumWidth) {
                        maximumWidth = view.computedSize.computedWidth;
                    }

                    // Compute maximum height
                    if (view.computedSize.computedHeight > maximumHeight) {
                        maximumHeight = view.computedSize.computedHeight;
                    }
                }
            }
        }

        // Update from maximum width
        if (layoutMask.canIncreaseWidth()) {
            if (maximumWidth > computedWidth) {
                computedWidth = maximumWidth;
            }
        }

        // Update from maximum height
        if (layoutMask.canIncreaseHeight()) {
            if (maximumHeight > computedHeight) {
                computedHeight = maximumHeight;
            }
        }

        // Recompute sub-sizes, but this time using the global computed height of the linear layout
        if (persist) {
            var persistingLayoutMask = layoutMask;

            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        view.computeSizeIfNeeded(computedWidth, computedHeight, persistingLayoutMask, persist);
                    }
                }
            }
        }

        // Add padding
        computedWidth += paddingLeft + paddingRight;
        computedHeight += paddingTop + paddingBottom;

        if (persist) {
            persistComputedSize(parentWidth, parentHeight, parentLayoutMask, computedWidth, computedHeight);
        }
        else {
            assignComputedSize(computedWidth, computedHeight);
        }

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.popIndent();
        ceramic.Shortcuts.log.info('/$this $computedWidth $computedHeight');
        #end

    }

    /**
     * Positions all child views within the padded area.
     * Each child is placed at the same base position (accounting for anchors),
     * with individual offsets applied. Depth values increase for each child
     * to maintain proper layering order.
     */
    override function layout() {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, width);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, height);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, width);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, height);
        var paddedWidth = width - paddingLeft - paddingRight;
        var paddedHeight = height - paddingTop - paddingBottom;
        var d = 1.0;

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.debug('$this.layout() $width $height $paddingTop $paddingRight $paddingBottom $paddingLeft');
        ceramic.Shortcuts.log.pushIndent();
        #end

        // Layout each view
        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews.unsafeGet(i);
                if (view.active) {

                    // Apply size
                    view.computeSizeIfNeeded(paddedWidth, paddedHeight, ViewLayoutMask.FLEXIBLE, false);
                    view.size(
                        view.computedSize.computedWidth,
                        view.computedSize.computedHeight
                    );

                    // Apply paddings, offsets, compensate anchors
                    view.x = view.width * view.anchorX + paddingLeft + ViewSize.computeWithParentSize(view.offsetX, paddedWidth);
                    view.y = view.height * view.anchorY + paddingTop + ViewSize.computeWithParentSize(view.offsetY, paddedHeight);

                    // Increase depth
                    view.depth = d++;
                }
            }
        }

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.popIndent();
        #end

    }

}
