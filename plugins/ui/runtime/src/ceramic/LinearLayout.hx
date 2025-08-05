package ceramic;

/**
 * A flexible layout container that arranges its children in a single line,
 * either horizontally or vertically. Supports flexible sizing, spacing,
 * alignment, and "fill" behavior for responsive layouts.
 *
 * LinearLayout is the foundation for building structured UI layouts,
 * allowing children to be arranged sequentially with automatic sizing
 * based on content or available space.
 *
 * ```haxe
 * var layout = new LinearLayout();
 * layout.direction = VERTICAL;
 * layout.itemSpacing = 10;
 * layout.align = CENTER;
 *
 * // Add children with different sizing
 * var header = new TextView();
 * header.viewHeight = 50; // Fixed height
 *
 * var content = new View();
 * content.viewHeight = fill(); // Takes remaining space
 * content.flex = 2; // Takes 2x space compared to other FILL views
 *
 * layout.add(header);
 * layout.add(content);
 * ```
 *
 * @see RowLayout A horizontal-only variant
 * @see ColumnLayout A vertical-only variant
 * @see View The base class for all UI components
 */
class LinearLayout extends View {

    /**
     * The layout direction determining how children are arranged.
     * - VERTICAL: Children are stacked top-to-bottom
     * - HORIZONTAL: Children are placed left-to-right
     *
     * Changing direction automatically adjusts the alignment mode
     * to match the new orientation.
     */
    public var direction(default, set):LayoutDirection = VERTICAL;

    function set_direction(direction:LayoutDirection):LayoutDirection {
        if (this.direction == direction)
            return direction;
        if (direction == VERTICAL) {
            align = switch (align) {
                case LEFT: TOP;
                case RIGHT: BOTTOM;
                default: align;
            }
        }
        else {
            align = switch (align) {
                case TOP: LEFT;
                case BOTTOM: RIGHT;
                default: align;
            }
        }
        this.direction = direction;
        layoutDirty = true;
        return direction;
    }

    /**
     * The spacing between child views in pixels.
     * Can be a percentage value relative to the parent size along
     * the layout axis (height for vertical, width for horizontal).
     *
     * ```haxe
     * layout.itemSpacing = 10; // 10 pixels between items
     * layout.itemSpacing = PERCENT(5); // 5% of parent size
     * ```
     */
    public var itemSpacing(default, set):Float = 0;

    function set_itemSpacing(itemSpacing:Float):Float {
        if (this.itemSpacing == itemSpacing)
            return itemSpacing;
        this.itemSpacing = itemSpacing;
        layoutDirty = true;
        return itemSpacing;
    }

    /**
     * Controls how children are aligned along the layout axis.
     * - For VERTICAL layouts: TOP, CENTER, or BOTTOM
     * - For HORIZONTAL layouts: LEFT, CENTER, or RIGHT
     *
     * The alignment determines where children are positioned when
     * they don't fill the entire available space.
     */
    public var align(default, set):LayoutAlign = TOP;

    function set_align(align:LayoutAlign):LayoutAlign {
        if (this.align == align)
            return align;
        this.align = align;
        layoutDirty = true;
        return align;
    }

    /**
     * Controls how depth values are assigned to children for render ordering.
     * - INCREMENT: First child gets depth 1, second gets 2, etc.
     * - DECREMENT: First child gets highest depth, decreasing for each
     * - SAME: All children get depth 1
     * - CUSTOM: Depth values are managed manually
     *
     * @see ChildrenDepth
     */
    public var childrenDepth(default, set):ChildrenDepth = INCREMENT;

    function set_childrenDepth(childrenDepth:ChildrenDepth):ChildrenDepth {
        if (this.childrenDepth == childrenDepth)
            return childrenDepth;
        this.childrenDepth = childrenDepth;
        layoutDirty = true;
        return childrenDepth;
    }

    /**
     * Creates a new LinearLayout instance.
     * By default, the layout is transparent and arranges children vertically.
     */
    public function new() {

        super();

        transparent = true;

    }

    /**
     * Computes the size of this layout based on its children and constraints.
     * Handles both fixed and flexible (FILL) sized children, respecting padding
     * and spacing. The computation differs based on layout direction.
     *
     * @param parentWidth Available width from parent
     * @param parentHeight Available height from parent
     * @param parentLayoutMask Constraints from parent layout
     * @param persist Whether to save computed sizes for layout phase
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

        var computedWidth = ComputedViewSize.NO_SIZE;
        var computedHeight = ComputedViewSize.NO_SIZE;

        if (direction == VERTICAL) {
            super.computeSize(parentWidth, parentHeight, parentLayoutMask, persist);
            computedWidth = computedSize.computedWidth;
            computedHeight = computedSize.computedHeight;

            var layoutMask = ViewLayoutMask.FLEXIBLE_HEIGHT;
            var hasExplicitWidth = !ViewSize.isAuto(viewWidth);
            var hasExplicitHeight = !ViewSize.isAuto(viewHeight);
            if (hasExplicitHeight) {
                parentLayoutMask.canIncreaseHeight(false);
                parentLayoutMask.canDecreaseHeight(false);
            }
            var childrenHeight = 0.0;
            var maximumWidth = 0.0;
            var numChildren = 0;
            var numFill = 0;
            var itemSpacing = ViewSize.computeWithParentSize(itemSpacing, parentHeight);

            if (hasExplicitWidth) {
                computedWidth -= paddingLeft + paddingRight;
            }
            else {
                if (parentLayoutMask.canIncreaseWidth()) {
                    layoutMask.canIncreaseWidth(true);
                }
                if (parentLayoutMask.canDecreaseWidth()) {
                    layoutMask.canDecreaseWidth(true);
                }
                if (!parentLayoutMask.canIncreaseWidth()) {
                    computedWidth -= paddingLeft + paddingRight;
                }
            }

            if (hasExplicitHeight) {
                computedHeight -= paddingTop + paddingBottom;
            }
            else if (!parentLayoutMask.canIncreaseHeight()) {
                computedHeight -= paddingTop + paddingBottom;
            }
            else if (computedHeight > 0) {
                computedHeight -= paddingTop + paddingBottom;
            }

            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        numChildren++;

                        // Skip 'auto' sizes
                        if (!ViewSize.isFill(view.viewHeight)) {

                            view.computeSizeIfNeeded(computedWidth, computedHeight, layoutMask, false);

                            // Compute maximum width
                            if (view.computedSize.computedWidth > maximumWidth) {
                                maximumWidth = view.computedSize.computedWidth;
                            }

                            // Add height
                            childrenHeight += view.computedSize.computedHeight;
                        }
                        else {
                            numFill += view.flex;
                        }
                    }
                }
            }

            // Add cumulated item spacing
            var diff = numChildren > 1 ? itemSpacing * (numChildren - 1) : 0;
            childrenHeight += diff;

            // Compute fill views
            var fillHeight = 0.0;
            var subLayoutMask = layoutMask;
            if (hasExplicitWidth) {
                subLayoutMask.canIncreaseWidth(false);
            }
            subLayoutMask.canDecreaseWidth(false);
            subLayoutMask.canIncreaseHeight(false);
            subLayoutMask.canDecreaseHeight(false);
            if (numFill > 0) {
                var leftHeight = Math.max(0, computedHeight - childrenHeight);
                fillHeight = leftHeight / numFill;
                if (fillHeight > 0) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewHeight)) {

                            view.computeSizeIfNeeded(computedWidth, fillHeight * view.flex, subLayoutMask, false);

                            // Compute maximum width
                            if (view.computedSize.computedWidth > maximumWidth) {
                                maximumWidth = view.computedSize.computedWidth;
                            }
                        }
                    }
                }

                childrenHeight = computedHeight;
            }

            // Update from maximum width
            if (layoutMask.canIncreaseWidth()) {
                if (maximumWidth > computedWidth) {
                    computedWidth = maximumWidth;
                }
            }

            // If children height > computed height, update it
            if (childrenHeight > computedHeight) {
                computedHeight = childrenHeight;
            }

            // Recompute sub-sizes, but this time using the global computed height of the linear layout
            if (persist) {
                var persistingLayoutMask = layoutMask;
                persistingLayoutMask.canDecreaseWidth(false);

                if (subviews != null) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && !ViewSize.isFill(view.viewHeight)) {
                            view.computeSizeIfNeeded(computedWidth, computedHeight, persistingLayoutMask, persist);
                        }
                    }
                }

                // Compute fill children
                if (numFill > 0 && fillHeight > 0 && subviews != null) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewHeight)) {
                            view.computeSizeIfNeeded(computedWidth, fillHeight * view.flex, subLayoutMask, persist);
                        }
                    }
                }
            }

            // Add padding
            computedWidth += paddingLeft + paddingRight;
            computedHeight += paddingTop + paddingBottom;
        }
        else {
            super.computeSize(parentWidth, parentHeight, parentLayoutMask, persist);
            computedWidth = computedSize.computedWidth;
            computedHeight = computedSize.computedHeight;

            var layoutMask = ViewLayoutMask.FLEXIBLE_WIDTH;
            var hasExplicitWidth = !ViewSize.isAuto(viewWidth);
            var hasExplicitHeight = !ViewSize.isAuto(viewHeight);
            if (hasExplicitWidth) {
                parentLayoutMask.canIncreaseWidth(false);
                parentLayoutMask.canDecreaseWidth(false);
            }
            var childrenWidth = 0.0;
            var maximumHeight = 0.0;
            var numChildren = 0;
            var numFill = 0;
            var itemSpacing = ViewSize.computeWithParentSize(itemSpacing, parentWidth);

            if (hasExplicitHeight) {
                computedHeight -= paddingTop + paddingBottom;
            }
            else {
                if (parentLayoutMask.canIncreaseHeight()) {
                    layoutMask.canIncreaseHeight(true);
                }
                if (parentLayoutMask.canDecreaseHeight()) {
                    layoutMask.canDecreaseHeight(true);
                }
                if (!parentLayoutMask.canIncreaseHeight()) {
                    computedHeight -= paddingTop + paddingBottom;
                }
            }

            if (hasExplicitWidth) {
                computedWidth -= paddingLeft + paddingRight;
            }
            else if (!parentLayoutMask.canIncreaseWidth()) {
                computedWidth -= paddingLeft + paddingRight;
            }
            else if (computedWidth > 0) {
                computedWidth -= paddingLeft + paddingRight;
            }

            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        numChildren++;

                        // Skip 'auto' sizes
                        if (!ViewSize.isFill(view.viewWidth)) {

                            view.computeSizeIfNeeded(computedWidth, computedHeight, layoutMask, false);

                            // Compute maximum height
                            if (view.computedSize.computedHeight > maximumHeight) {
                                maximumHeight = view.computedSize.computedHeight;
                            }

                            // Add width
                            childrenWidth += view.computedSize.computedWidth;
                        }
                        else {
                            numFill += view.flex;
                        }
                    }
                }
            }

            // Add cumulated item spacing
            var diff = numChildren > 1 ? itemSpacing * (numChildren - 1) : 0;
            childrenWidth += diff;

            // Compute fill views
            var fillWidth = 0.0;
            var subLayoutMask = layoutMask;
            if (hasExplicitHeight) {
                subLayoutMask.canIncreaseHeight(false);
            }
            subLayoutMask.canDecreaseHeight(false);
            subLayoutMask.canIncreaseWidth(false);
            subLayoutMask.canDecreaseWidth(false);
            if (numFill > 0) {
                var leftWidth = Math.max(0, computedWidth - childrenWidth);
                fillWidth = leftWidth / numFill;
                if (fillWidth > 0) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewWidth)) {

                            view.computeSizeIfNeeded(fillWidth * view.flex, computedHeight, subLayoutMask, false);

                            // Compute maximum height
                            if (view.computedSize.computedHeight > maximumHeight) {
                                maximumHeight = view.computedSize.computedHeight;
                            }
                        }
                    }
                }

                childrenWidth = computedWidth;
            }

            // Update from maximum height
            if (layoutMask.canIncreaseHeight()) {
                if (maximumHeight > computedHeight) {
                    computedHeight = maximumHeight;
                }
            }

            // If children width > computed width, update it
            if (childrenWidth > computedWidth) {
                computedWidth = childrenWidth;
            }

            // Recompute sub-sizes, but this time using the global computed width of the linear layout
            if (persist) {
                var persistingLayoutMask = layoutMask;
                persistingLayoutMask.canDecreaseHeight(false);

                if (subviews != null) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && !ViewSize.isFill(view.viewWidth)) {
                            view.computeSizeIfNeeded(computedWidth, computedHeight, persistingLayoutMask, persist);
                        }
                    }
                }

                // Compute fill children
                if (numFill > 0 && fillWidth > 0 && subviews != null) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewWidth)) {
                            view.computeSizeIfNeeded(fillWidth * view.flex, computedHeight, subLayoutMask, persist);
                        }
                    }
                }
            }

            // Add padding
            computedWidth += paddingLeft + paddingRight;
            computedHeight += paddingTop + paddingBottom;
        }

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
     * Positions and sizes all child views according to the layout rules.
     * Children are arranged sequentially along the layout axis with proper
     * spacing and alignment. FILL children expand to use remaining space.
     *
     * The layout process:
     * 1. Calculates space for fixed-size children
     * 2. Distributes remaining space among FILL children based on flex values
     * 3. Positions children with spacing and alignment
     * 4. Applies depth sorting based on childrenDepth setting
     */
    override function layout() {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, width);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, height);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, width);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, height);

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.debug('$this.layout() $width $height $paddingTop $paddingRight $paddingBottom $paddingLeft');
        ceramic.Shortcuts.log.pushIndent();
        #end

        var paddedWidth = width - paddingLeft - paddingRight;
        var paddedHeight = height - paddingTop - paddingBottom;

        // Compute depth sorting fashion
        var d:Float;
        var dDiff:Float;
        var customDepth:Bool = false;
        switch (childrenDepth) {
            case INCREMENT:
                dDiff = 1;
                d = 1;
            case DECREMENT:
                dDiff = -1;
                d = subviews != null ? subviews.length : 1;
            case SAME:
                dDiff = 0;
                d = 1;
            case CUSTOM:
                dDiff = 0;
                d = 1;
                customDepth = true;
        }

        if (direction == VERTICAL) {

            var y = paddingTop;
            var h = 0.0;
            var numChildren = 0;
            var numFill = 0;

            var itemSpacing = ViewSize.computeWithParentSize(itemSpacing, height);

            // Layout each view
            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        numChildren++;

                        if (!ViewSize.isFill(view.viewHeight)) {
                            view.computeSizeIfNeeded(paddedWidth, paddedHeight, ViewLayoutMask.FLEXIBLE_HEIGHT, true);
                            view.x = paddingLeft;
                            view.size(
                                Math.min(paddedWidth, view.computedSize.computedWidth),
                                view.computedSize.computedHeight
                            );
                            h += view.computedSize.computedHeight;
                        }
                        else {
                            numFill += view.flex;
                        }
                    }
                }
            }

            // Compute fill views
            if (numFill > 0) {
                var diff = numChildren > 1 ? itemSpacing * (numChildren - 1) : 0;
                var leftHeight = Math.max(0, paddedHeight - h) - diff;
                var fillHeight = leftHeight / numFill;
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active && ViewSize.isFill(view.viewHeight)) {
                        view.computeSizeIfNeeded(paddedWidth, fillHeight * view.flex, ViewLayoutMask.FIXED, true);
                        view.pos(paddingLeft, 0);
                        view.size(paddedWidth, fillHeight * view.flex);
                    }
                }
                h = paddedHeight;
            }

            // Compute all y positions
            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        // Add item spacing on all items except the first one
                        if (i > 0) {
                            y += itemSpacing;
                            h += itemSpacing;
                        }

                        view.y = y;
                        if (view.height + y > paddedHeight + paddingTop) {
                            view.height = Math.max(0, paddedHeight + paddingTop - y);
                        }
                        y += view.height;

                        // Set depth
                        if (!customDepth) {
                            view.depth = d;
                            d += dDiff;
                        }
                    }
                }
            }

            y += paddingBottom;

            // Adjust children position if content is centered or bottom aligned
            var diff = paddedHeight - h;
            if (diff > 0) {
                switch (align) {
                    case CENTER | BOTTOM:
                        if (align == CENTER) {
                            // Center
                            diff = Math.round(diff * 0.5);
                        }

                        // Update every children y
                        if (subviews != null) {
                            for (i in 0...subviews.length) {
                                var view = subviews.unsafeGet(i);
                                if (view.active) {
                                    view.y += diff;
                                }
                            }
                        }

                    default:
                }
            }

        }
        else {

            var x = paddingLeft;
            var w = 0.0;
            var numChildren = 0;
            var numFill = 0;

            var itemSpacing = ViewSize.computeWithParentSize(itemSpacing, width);

            // Layout each view
            if (subviews != null) {
                for (view in subviews) {
                    if (view.active) {
                        numChildren++;

                        if (!ViewSize.isFill(view.viewWidth)) {
                            view.computeSizeIfNeeded(paddedWidth, paddedHeight, ViewLayoutMask.FLEXIBLE_WIDTH, true);
                            view.y = paddingTop;
                            view.size(
                                view.computedSize.computedWidth,
                                Math.min(paddedHeight, view.computedSize.computedHeight)
                            );
                            w += view.computedSize.computedWidth;
                        }
                        else {
                            numFill += view.flex;
                        }
                    }
                }
            }

            // Compute fill views
            if (numFill > 0) {
                var diff = numChildren > 1 ? itemSpacing * (numChildren - 1) : 0;
                var leftWidth = Math.max(0, paddedWidth - w) - diff;
                var fillWidth = leftWidth / numFill;
                for (view in subviews) {
                    if (view.active && ViewSize.isFill(view.viewWidth)) {
                        view.computeSizeIfNeeded(fillWidth * view.flex, paddedHeight, ViewLayoutMask.FIXED, true);
                        view.pos(0, paddingTop);
                        view.size(fillWidth * view.flex, paddedHeight);
                    }
                }
                w = paddedWidth;
            }

            // Compute all y positions
            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        // Add item spacing on all items except the first one
                        if (i > 0) {
                            x += itemSpacing;
                            w += itemSpacing;
                        }

                        view.x = x;
                        if (view.width + x > paddedWidth + paddingLeft) {
                            view.width = Math.max(0, paddedWidth + paddingLeft - x);
                        }
                        x += view.width;

                        // Set depth
                        if (!customDepth) {
                            view.depth = d;
                            d += dDiff;
                        }
                    }
                }
            }

            x += paddingRight;

            // Adjust children position if content is centered or bottom aligned
            var diff = paddedWidth - w;
            if (diff > 0) {
                switch (align) {
                    case CENTER | RIGHT:
                        if (align == CENTER) {
                            // Center
                            diff = Math.round(diff * 0.5);
                        }

                        // Update every children x
                        if (subviews != null) {
                            for (i in 0...subviews.length) {
                                var view = subviews.unsafeGet(i);
                                if (view.active) {
                                    view.x += diff;
                                }
                            }
                        }

                    default:
                }
            }
        }

        // Compensate anchors and apply offsets
        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews.unsafeGet(i);
                if (view.active) {
                    view.x += view.width * view.anchorX + ViewSize.computeWithParentSize(view.offsetX, paddedWidth);
                    view.y += view.height * view.anchorY + ViewSize.computeWithParentSize(view.offsetY, paddedHeight);
                }
            }
        }

        #if ceramic_debug_layout
        ceramic.Shortcuts.log.popIndent();
        #end

    }

}
