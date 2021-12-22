package elements;

import ceramic.CollectionView;
import ceramic.Filter;
import ceramic.Shortcuts.*;
import elements.Context.context;
import elements.Scrollbar;
import tracker.Observable;

class CellCollectionView extends CollectionView implements Observable {

    @observe public var scrolling(default,null):Bool = false;

    @observe public var inputStyle:Bool = false;

    var filter:Filter;

    public function new() {

        super();

        filter = new Filter();
        add(filter);

        viewSize(fill(), fill());
        transparent = false;
        contentView.transparent = true;
        contentView.borderPosition = OUTSIDE;
        borderPosition = INSIDE;
        scroller.allowPointerOutside = false;
        scroller.scrollbar = new Scrollbar();
        filter.textureFilter = NEAREST;
        filter.content.add(scroller);

        #if !(ios || android)
        scroller.dragEnabled = false;
        #end

        contentView.onLayout(this, updateBorderDepth);

        autorun(updateStyle);

        app.onUpdate(this, updateScrollingFlag);

    }

    function updateScrollingFlag(delta:Float) {

        scrolling = (scroller.status != IDLE);

    }

    override function layout() {

        filter.pos(0, 0);
        filter.size(width, height);

        super.layout();

    }

    function updateBorderDepth() {

        borderDepth = contentView.children.length + 10;

    }

    function updateStyle() {

        var theme = context.theme;

        if (inputStyle) {
            transparent = true;
            contentView.borderTopSize = 1;
            borderBottomSize = 1;
            borderTopSize = 1;
            borderBottomColor = theme.lightBorderColor;
        }
        else {
            transparent = false;
            color = theme.darkBackgroundColor;
            borderSize = 0;
            contentView.borderTopSize = 1;
            borderBottomSize = 1;
            borderTopSize = 0;
            borderBottomColor = theme.mediumBorderColor;
        }

        contentView.borderTopColor = theme.mediumBorderColor;
        contentView.borderBottomColor = theme.mediumBorderColor;

    }

}
