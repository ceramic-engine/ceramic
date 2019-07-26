package ceramic.ui;

class StackLayout extends View {

    override function computeSize(parentWidth:Float, parentHeight:Float, parentLayoutMask:ViewLayoutMask, persist:Bool) {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, parentWidth);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, parentHeight);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, parentWidth);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, parentHeight);

        super.computeSize(parentWidth, parentHeight, parentLayoutMask, persist);

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
                    if (view.computedWidth > maximumWidth) {
                        maximumWidth = view.computedWidth;
                    }

                    // Compute maximum height
                    if (view.computedHeight > maximumHeight) {
                        maximumHeight = view.computedHeight;
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
            persistComputedSizeWithContext(parentWidth, parentHeight, parentLayoutMask);
        }

    } //computeSize

    override function layout() {

        var paddingLeft = ViewSize.computeWithParentSize(paddingLeft, width);
        var paddingTop = ViewSize.computeWithParentSize(paddingTop, height);
        var paddingRight = ViewSize.computeWithParentSize(paddingRight, width);
        var paddingBottom = ViewSize.computeWithParentSize(paddingBottom, height);
        var paddedWidth = width - paddingLeft - paddingRight;
        var paddedHeight = height - paddingTop - paddingBottom;
        var d = 1.0;

        // Layout each view
        if (subviews != null) {
            for (i in 0...subviews.length) {
                var view = subviews.unsafeGet(i);
                if (view.active) {

                    // Apply size
                    view.computeSizeIfNeeded(paddedWidth, paddedHeight, ViewLayoutMask.FLEXIBLE, false);
                    view.size(
                        view.computedWidth,
                        view.computedHeight
                    );

                    // Apply paddings, offsets, compensate anchors
                    view.x = view.width * view.anchorX + paddingLeft + ViewSize.computeWithParentSize(view.offsetX, paddedWidth);
                    view.y = view.height * view.anchorY + paddingTop + ViewSize.computeWithParentSize(view.offsetY, paddedHeight);

                    // Increase depth
                    view.depth = d++;
                }
            }
        }

    } //layout

} //StackLayout
