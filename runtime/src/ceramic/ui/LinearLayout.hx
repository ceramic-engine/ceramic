package ceramic.ui;

class LinearLayout extends View {

    public var direction(default,set):LayoutDirection = VERTICAL;
    function set_direction(direction:LayoutDirection):LayoutDirection {
        if (this.direction == direction) return direction;
        if (direction == VERTICAL) {
            align = switch (align) {
                case LEFT: TOP;
                case RIGHT: BOTTOM;
                default: align;
            }
        } else {
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

    public var itemSpacing(default,set):Float = 0;
    function set_itemSpacing(itemSpacing:Float):Float {
        if (this.itemSpacing == itemSpacing) return itemSpacing;
        this.itemSpacing = itemSpacing;
        layoutDirty = true;
        return itemSpacing;
    }

    public var align(default,set):LayoutAlign = TOP;
    function set_align(align:LayoutAlign):LayoutAlign {
        if (this.align == align) return align;
        this.align = align;
        layoutDirty = true;
        return align;
    }

    public function new() {

        super();

        transparent = true;

    } //new

    override function computeSize(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask, persist:Bool) {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, parentWidth);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, parentHeight);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, parentWidth);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, parentHeight);

        if (direction == VERTICAL) {
            super.computeSize(parentWidth, parentHeight, parentLayoutMask, persist);
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

            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        numChildren++;

                        // Skip 'auto' sizes
                        if (!ViewSize.isFill(view.viewHeight)) {

                            view.computeSize(computedWidth, computedHeight, layoutMask, false);

                            // Compute maximum width
                            if (view.computedWidth > maximumWidth) {
                                maximumWidth = view.computedWidth;
                            }

                            // Add height
                            childrenHeight += view.computedHeight;
                        }
                        else {
                            numFill++;
                        }
                    }
                }
            }

            // Add cumulated item spacing
            var diff = numChildren > 1 ? itemSpacing * (numChildren - 1) : 0;
            childrenHeight += diff;
            computedHeight += diff;

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
                var leftHeight = Math.max(0, computedHeight - childrenHeight - itemSpacing * Math.max(0, subviews.length - 1));
                fillHeight = leftHeight / numFill;
                if (fillHeight > 0) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewHeight)) {

                            view.computeSize(computedWidth, fillHeight, subLayoutMask, false);

                            // Compute maximum width
                            if (view.computedWidth > maximumWidth) {
                                maximumWidth = view.computedWidth;
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
                            view.computeSize(computedWidth, computedHeight, persistingLayoutMask, persist);
                        }
                    }
                }

                // Compute fill children
                if (numFill > 0 && fillHeight > 0 && subviews != null) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewHeight)) {
                            view.computeSize(computedWidth, fillHeight, subLayoutMask, persist);
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

            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        numChildren++;

                        // Skip 'auto' sizes
                        if (!ViewSize.isFill(view.viewWidth)) {

                            view.computeSize(computedWidth, computedHeight, layoutMask, false);

                            // Compute maximum height
                            if (view.computedHeight > maximumHeight) {
                                maximumHeight = view.computedHeight;
                            }

                            // Add width
                            childrenWidth += view.computedWidth;
                        }
                        else {
                            numFill++;
                        }
                    }
                }
            }

            // Add cumulated item spacing
            var diff = numChildren > 1 ? itemSpacing * (numChildren - 1) : 0;
            childrenWidth += diff;
            computedWidth += diff;

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
                var leftWidth = Math.max(0, computedWidth - childrenWidth - itemSpacing * Math.max(0, subviews.length - 1));
                fillWidth = leftWidth / numFill;
                if (fillWidth > 0) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewWidth)) {

                            view.computeSize(fillWidth, computedHeight, subLayoutMask, false);

                            // Compute maximum height
                            if (view.computedHeight > maximumHeight) {
                                maximumHeight = view.computedHeight;
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
                            view.computeSize(computedWidth, computedHeight, persistingLayoutMask, persist);
                        }
                    }
                }

                // Compute fill children
                if (numFill > 0 && fillWidth > 0 && subviews != null) {
                    for (i in 0...subviews.length) {
                        var view = subviews.unsafeGet(i);
                        if (view.active && ViewSize.isFill(view.viewWidth)) {
                            view.computeSize(fillWidth, computedHeight, subLayoutMask, persist);
                        }
                    }
                }
            }

            // Add padding
            computedWidth += paddingLeft + paddingRight;
            computedHeight += paddingTop + paddingBottom;
        }

    } //computeSize

    override function layout() {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, width);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, height);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, width);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, height);

        if (direction == VERTICAL) {

            // Compute padding
            var paddedWidth = width - paddingLeft - paddingRight;
            var paddedHeight = height - paddingTop - paddingBottom;
            var y = paddingTop;
            var h = 0.0;
            var numChildren = 0;
            var numFill = 0;
            var d = 1.0;
            var itemSpacing = ViewSize.computeWithParentSize(itemSpacing, height);

            // Layout each view
            if (subviews != null) {
                for (i in 0...subviews.length) {
                    var view = subviews.unsafeGet(i);
                    if (view.active) {
                        numChildren++;

                        if (!ViewSize.isFill(view.viewHeight)) {
                            view.computeSize(paddedWidth, paddedHeight, ViewLayoutMask.FLEXIBLE_HEIGHT, true);
                            view.x = paddingLeft;
                            view.size(
                                Math.min(paddedWidth, view.computedWidth),
                                view.computedHeight
                            );
                            h += view.computedHeight;
                        }
                        else {
                            numFill++;
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
                        view.computeSize(paddedWidth, fillHeight, ViewLayoutMask.FIXED, true);
                        view.pos(paddingLeft, 0);
                        view.size(paddedWidth, fillHeight);
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
                        view.depth = d++;
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
                            for (view in subviews) {
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

            // Compute padding
            var paddedWidth = width - paddingLeft - paddingRight;
            var paddedHeight = height - paddingTop - paddingBottom;
            var x = paddingLeft;
            var w = 0.0;
            var numChildren = 0;
            var numFill = 0;
            var d = 1.0;
            var itemSpacing = ViewSize.computeWithParentSize(itemSpacing, width);

            // Layout each view
            if (subviews != null) {
                for (view in subviews) {
                    if (view.active) {
                        numChildren++;

                        if (!ViewSize.isFill(view.viewWidth)) {
                            view.computeSize(paddedWidth, paddedHeight, ViewLayoutMask.FLEXIBLE_WIDTH, true);
                            view.y = paddingTop;
                            view.size(
                                view.computedWidth,
                                Math.min(paddedHeight, view.computedHeight)
                            );
                            w += view.computedWidth;
                        }
                        else {
                            numFill++;
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
                        view.computeSize(fillWidth, paddedHeight, ViewLayoutMask.FIXED, true);
                        view.pos(0, paddingTop);
                        view.size(fillWidth, paddedHeight);
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
                        view.depth = d++;
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

        // Compensate anchors
        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews.unsafeGet(i);
                if (view.active) {
                    view.x += view.width * view.anchorX;
                    view.y += view.height * view.anchorY;
                }
            }
        }

    } //layout

} //View
