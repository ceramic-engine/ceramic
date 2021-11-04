package elements;

import ceramic.Click;
import ceramic.CollectionView;
import ceramic.CollectionViewDataSource;
import ceramic.CollectionViewItemFrame;
import ceramic.CollectionViewItemPosition;
import ceramic.Color;
import ceramic.ReadOnlyArray;
import ceramic.View;
import elements.CellView;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

class SelectListView extends View implements CollectionViewDataSource implements Observable {

    @event function valueClick(value:String);

    public static final ITEM_HEIGHT = 26;

    public var autoScrollToValue:Bool = false;

    @observe public var value:String = null;

    @observe public var list:ReadOnlyArray<String> = [];

    @observe public var nullValueText:String = null;

    var collectionView:CellCollectionView;

    //var filter:Filter;

    public function new() {

        super();

        // filter = new Filter();
        // add(filter);

        collectionView = new CellCollectionView();
        collectionView.viewSize(fill(), fill());
        collectionView.transparent = true;
        collectionView.dataSource = this;
        collectionView.inputStyle = true;
        /*filter.content.*/add(collectionView);

        autorun(() -> {
            var size = list.length;
            if (nullValueText != null) {
                size++;
            }
            unobserve();
            collectionView.reloadData();
        });

        autorun(updateScrollFromValueIfNeeded);

        autorun(updateStyle);

    }

    function updateScrollFromValueIfNeeded() {

        var value = this.value;

        unobserve();

        if (autoScrollToValue && value != null) {
            scrollToValue(ENSURE_VISIBLE);
        }

        reobserve();

    }

    public function scrollToValue(position:CollectionViewItemPosition) {

        if (value == null || list == null) {
            collectionView.scrollToItem(0, position);
        }
        else {
            collectionView.scrollToItem(list.indexOf(value) + (nullValueText != null ? 1 : 0), position);
        }

    }

    /// Layout

    override function layout() {

        //filter.size(width, height);

        collectionView.size(width, height);

    }

    /// Data source

    /** Get the number of elements. */
    public function collectionViewSize(collectionView:CollectionView):Int {

        return list.length + (nullValueText != null ? 1 : 0);

    }

    /** Get the item frame at the requested index. */
    public function collectionViewItemFrameAtIndex(collectionView:CollectionView, itemIndex:Int, frame:CollectionViewItemFrame):Void {

        frame.width = collectionView.width;
        frame.height = ITEM_HEIGHT;

    }

    /** Called when a view is not used anymore at the given index. Lets the dataSource
        do some cleanup if needed, before this view gets reused (if it can).
        Returns `true` if the view can be reused at another index of `false` otherwise. */
    public function collectionViewReleaseItemAtIndex(collectionView:CollectionView, itemIndex:Int, view:View):Bool {

        return true;

    }

    /** Get a view at the given index. If `reusableView` is provided,
        it can be recycled as the new item to avoid creating new instances. */
    public function collectionViewItemAtIndex(collectionView:CollectionView, itemIndex:Int, reusableView:View):View {

        var cell:CellView = null;
        if (reusableView != null) {
            cell = cast reusableView;
            cell.itemIndex = itemIndex;
        }
        else {
            cell = new CellView();
            cell.inputStyle = true;
            cell.itemIndex = itemIndex;
            cell.collectionView = cast collectionView;
            bindCellView(cell);
        }

        return cell;

    }

    function bindCellView(cell:CellView):Void {

        cell.autorun(function() {

            var index = cell.itemIndex;
            if (nullValueText != null) {
                index--;
            }

            var value = index >= 0 ? list[index] : null;

            var selected = (value == this.value);

            cell.title = value != null ? value : nullValueText;
            cell.displaysEmptyValue = (value == null);
            cell.selected = selected;

        });

        var click = new Click();
        cell.component('click', click);
        click.onClick(cell, function() {

            var index = cell.itemIndex;
            if (nullValueText != null) {
                index--;
            }

            var newValue = index >= 0 ? list[index] : null;
            this.value = newValue;

            emitValueClick(newValue);

            invalidateValue();

        });

    }

    function updateStyle() {

        var theme = context.theme;

        color = Color.interpolate(theme.darkBackgroundColor, Color.BLACK, 0.1);

        borderSize = 1;
        borderColor = theme.lightBorderColor;
        borderPosition = INSIDE;
        borderDepth = 2;

    }

}