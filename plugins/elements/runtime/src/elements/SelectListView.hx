package elements;

import ceramic.Click;
import ceramic.CollectionView;
import ceramic.CollectionViewDataSource;
import ceramic.CollectionViewItemFrame;
import ceramic.CollectionViewItemPosition;
import ceramic.Color;
import ceramic.Equal;
import ceramic.ReadOnlyArray;
import ceramic.View;
import elements.CellView;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

/**
 * A scrollable list view for displaying selectable items in dropdown controls.
 * 
 * SelectListView provides a virtualized list interface for selecting from a collection
 * of string options. It supports highlighting the current selection, null value handling,
 * and automatic scrolling to selected items. The view uses a CollectionView for efficient
 * rendering of large lists.
 * 
 * Key features:
 * - Virtualized scrolling for performance with large lists
 * - Current selection highlighting
 * - Support for null values with custom display text
 * - Click and touch interaction
 * - Automatic scrolling to selected items
 * - Customizable cell styling through themes
 * 
 * Usage example:
 * ```haxe
 * var listView = new SelectListView();
 * listView.list = ['Item 1', 'Item 2', 'Item 3'];
 * listView.nullValueText = 'None';
 * listView.value = 'Item 2';
 * listView.size(200, 150);
 * listView.onValueChange(this, (value, prev) -> {
 *     trace('Selected: ' + value);
 * });
 * add(listView);
 * ```
 */
class SelectListView extends View implements CollectionViewDataSource implements Observable {

    /** Custom theme override for this list view. If null, uses the global context theme */
    @observe public var theme:Theme = null;

    /** Event emitted when a value is clicked/selected */
    @event function valueClick(value:String);

    /** Height of each item in the list in pixels */
    public static final ITEM_HEIGHT = 26;

    /** Whether to automatically scroll to the selected value when it changes */
    public var autoScrollToValue:Bool = false;

    /** The currently selected value. Can be null if no value is selected */
    @observe public var value:String = null;

    /** Array of string options to display in the list */
    @observe public var list:ReadOnlyArray<String> = [];

    /** Text to display for the null/empty value option. If null, no null option is shown */
    @observe public var nullValueText:String = null;

    /** The collection view that handles virtualized scrolling and cell management */
    var collectionView:CellCollectionView;

    //var filter:Filter;

    /**
     * Creates a new SelectListView.
     * 
     * Sets up the collection view for virtualized scrolling, configures data binding,
     * and initializes automatic scrolling behavior.
     */
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

        var prevList:Array<String> = null;
        autorun(() -> {
            var list = this.list;
            if (list != prevList && (prevList == null || !Equal.arrayEqual(list.original, prevList))) {
                prevList = list.original;
                var size = list.length;
                if (nullValueText != null) {
                    size++;
                }
                unobserve();
                collectionView.reloadData();
            }
        });

        autorun(updateScrollFromValueIfNeeded);

        autorun(updateStyle);

    }

    /**
     * Updates scroll position to show the current value if auto-scrolling is enabled.
     * 
     * This is called automatically when the value changes and autoScrollToValue is true.
     */
    function updateScrollFromValueIfNeeded() {

        var value = this.value;

        unobserve();

        if (autoScrollToValue && value != null) {
            scrollToValue(ENSURE_VISIBLE);
        }

        reobserve();

    }

    /**
     * Scrolls the list to show the currently selected value.
     * 
     * @param position How to position the item (START, CENTER, END, ENSURE_VISIBLE)
     */
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

    /**
     * Returns the total number of items in the list.
     * 
     * Includes an extra item if nullValueText is set to represent the null option.
     * 
     * @param collectionView The collection view requesting the size
     * @return Total number of items including null option if applicable
     */
    public function collectionViewSize(collectionView:CollectionView):Int {

        return list.length + (nullValueText != null ? 1 : 0);

    }

    /**
     * Provides the frame (size and position) for an item at the given index.
     * 
     * All items have the same height (ITEM_HEIGHT) and fill the collection view width.
     * 
     * @param collectionView The collection view requesting the frame
     * @param itemIndex Index of the item
     * @param frame Frame object to populate with size information
     */
    public function collectionViewItemFrameAtIndex(collectionView:CollectionView, itemIndex:Int, frame:CollectionViewItemFrame):Void {

        frame.width = collectionView.width;
        frame.height = ITEM_HEIGHT;

    }

    /**
     * Called when a view is no longer needed at the given index.
     * 
     * Allows cleanup before view reuse. For SelectListView, cells can always be reused.
     * 
     * @param collectionView The collection view releasing the item
     * @param itemIndex Index of the item being released
     * @param view The view being released
     * @return true if the view can be reused, false otherwise
     */
    public function collectionViewReleaseItemAtIndex(collectionView:CollectionView, itemIndex:Int, view:View):Bool {

        return true;

    }

    /**
     * Creates or reuses a view for the item at the given index.
     * 
     * Creates CellView instances to display list items. Reuses existing views when
     * possible for performance. Binds cell data and interaction handlers.
     * 
     * @param collectionView The collection view requesting the item
     * @param itemIndex Index of the item
     * @param reusableView Existing view that can be recycled, if available
     * @return The view to display for this item
     */
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

    /**
     * Binds data and interaction handlers to a cell view.
     * 
     * Sets up automatic updates for cell content, selection state, and theme,
     * and configures click handling for value selection.
     * 
     * @param cell The cell view to bind
     */
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

        cell.autorun(function() {

            var theme = this.theme;
            unobserve();
            cell.theme = theme;

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

    /**
     * Updates the visual style of the list view based on the current theme.
     * 
     * Sets the background color, border appearance, and other visual properties
     * to match the current theme.
     */
    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        color = Color.interpolate(theme.darkBackgroundColor, Color.BLACK, 0.1);

        borderSize = 1;
        borderColor = theme.lightBorderColor;
        borderPosition = INSIDE;
        borderDepth = 2;

    }

}