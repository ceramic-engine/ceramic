package elements;

import ceramic.ScrollView;
import ceramic.View;
import ceramic.Filter;
import ceramic.ViewLayoutMask;
import ceramic.Shortcuts.*;

class ScrollingLayout<T:View> extends ScrollView {

    public var layoutView(default, null):T;

    public var checkChildrenOfView:View = null;

    public var filter(default, null):Filter;

    public function new(layoutView:T, withBorders:Bool = false) {

        super();

        filter = new Filter();
        add(filter);

        this.layoutView = layoutView;
        contentView.add(layoutView);

        viewSize(fill(), fill());
        transparent = true;
        contentView.transparent = true;
        //clip = this;
        scroller.allowPointerOutside = false;
        scroller.bounceMinDuration = 0;
        scroller.bounceDurationFactor = 0;
        filter.content.add(scroller);

        if (withBorders) {
            contentView.borderTopSize = 1;
            contentView.borderPosition = OUTSIDE;
            borderBottomSize = 1;
            borderPosition = INSIDE;
        }

        #if !(ios || android)
        scroller.dragEnabled = false;
        #end

        app.onPostUpdate(this, handlePostUpdate);

    }

    override function layout() {

        filter.pos(0, 0);
        filter.size(width, height);

        scroller.pos(0, 0);
        scroller.size(width, height);

        // Needed on C# target
        var layoutView:View = cast this.layoutView;

        if (direction == VERTICAL) {
            layoutView.computeSize(width, height, ViewLayoutMask.INCREASE_HEIGHT, true);
            layoutView.size(layoutView.computedWidth, Math.max(layoutView.computedHeight, height));

            if (layoutView.computedHeight - scroller.scrollY < height) {
                scroller.scrollY = layoutView.computedHeight - height;
            }

        } else {
            layoutView.computeSize(width, height, ViewLayoutMask.INCREASE_WIDTH, true);
            layoutView.size(Math.max(layoutView.computedWidth, width), layoutView.computedHeight);

            if (layoutView.computedWidth - scroller.scrollX < width) {
                scroller.scrollX = layoutView.computedWidth - width;
            }
        }

        contentView.size(layoutView.width, layoutView.height);

        scroller.scrollToBounds();

    }

    function handlePostUpdate(delta:Float) {

        if (checkChildrenOfView != null) {
            if (checkChildrenOfView.destroyed) {
                checkChildrenOfView = null;
                return;
            }
            var views = checkChildrenOfView.subviews;
            if (views == null)
                return;
            for (i in 0...views.length) {
                var view = views[i];

                var viewY = view.y;
                var viewHeight = view.height;
                if (viewY + viewHeight < scroller.scrollY || viewY > height + scroller.scrollY) {
                    view.visible = false;
                }
                else {
                    view.visible = true;
                }
            }
        }

    }

}
