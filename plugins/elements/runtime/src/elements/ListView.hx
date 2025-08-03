package elements;

import ceramic.Click;
import ceramic.CollectionView;
import ceramic.CollectionViewDataSource;
import ceramic.CollectionViewItemFrame;
import ceramic.Entity;
import ceramic.Shortcuts.*;
import ceramic.View;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using ceramic.Extensions;

/**
 * A comprehensive list view with sorting, item management, and interaction features.
 * 
 * ListView provides a feature-rich interface for displaying and managing lists of data.
 * It supports various operations including sorting, item selection, locking/unlocking,
 * duplication, and deletion. The view uses a CollectionView internally for efficient
 * scrolling and item recycling.
 * 
 * Features:
 * - Dynamic item lists with automatic updates
 * - Sortable items with drag-and-drop reordering
 * - Item selection with visual feedback
 * - Lock/unlock functionality for individual items
 * - Item duplication and deletion operations
 * - Two item height modes (small and large)
 * - Scroll control with optional scrollbar
 * - Theme integration and styling
 * - Event-driven architecture for item operations
 * - Integration with WindowItem for window management
 * 
 * Example usage:
 * ```haxe
 * var items = ["Item 1", "Item 2", "Item 3"];
 * var listView = new ListView(items);
 * listView.trashable = true;
 * listView.sortable = true;
 * listView.onTrashItem(this, (index) -> {
 *     items.splice(index, 1);
 * });
 * ```
 * 
 * @see CellCollectionView
 * @see CellView
 * @see WindowItem
 */
@:allow(elements.ListViewDataSource)
class ListView extends View implements Observable {

    /** Standard height for small list items (30 pixels) */
    public static final CELL_HEIGHT_SMALL:Int = 30;

    /** Standard height for large list items (39 pixels) */
    public static final CELL_HEIGHT_LARGE:Int = 39;

/// Events

    /** Emitted when an item should be moved above another item in the list */
    @event function moveItemAboveItem(itemIndex:Int, otherItemIndex:Int);

    /** Emitted when an item should be moved below another item in the list */
    @event function moveItemBelowItem(itemIndex:Int, otherItemIndex:Int);

    /** Emitted when an item should be deleted/trashed */
    @event function trashItem(itemIndex:Int);

    /** Emitted when an item should be locked */
    @event function lockItem(itemIndex:Int);

    /** Emitted when an item should be unlocked */
    @event function unlockItem(itemIndex:Int);

    /** Emitted when an item should be duplicated */
    @event function duplicateItem(itemIndex:Int);

/// Public properties

    /** The internal collection view that handles item display and scrolling */
    public var collectionView(default, null):CellCollectionView;

    /** The data source providing item data to the collection view */
    public var dataSource(default, set):CollectionViewDataSource;
    /**
     * Sets the data source for the collection view.
     * 
     * @param dataSource The new data source
     * @return The assigned data source
     */
    function set_dataSource(dataSource:CollectionViewDataSource):CollectionViewDataSource {
        this.dataSource = dataSource;
        collectionView.dataSource = dataSource;
        return dataSource;
    }

    /** Custom theme override for this list view */
    @observe public var theme:Theme = null;

    /** The array of items to display in the list */
    @observe public var items:Array<Dynamic>;

    /** Index of the currently selected item (-1 for no selection) */
    @observe public var selectedIndex:Int = -1;

    /** Whether items can be deleted/trashed */
    @observe public var trashable:Bool = false;

    /** Whether items can be locked/unlocked */
    @observe public var lockable:Bool = false;

    /** Whether items can be duplicated */
    @observe public var duplicable:Bool = false;

    /** Whether items can be reordered via drag and drop */
    @observe public var sortable:Bool = false;

    /** Whether to use small item height (30px) instead of large (39px) */
    @observe public var smallItems:Bool = false;

    /** Whether scrolling is enabled for the list */
    @observe public var scrollEnabled:Bool = true;

    /**
     * Optional WindowItem for window-specific list management.
     * Used for coordinating list operations within a window context.
     */
    public var windowItem:WindowItem = null;

    /** Whether to automatically check and update item locked states */
    public var autoCheckLocked:Bool = true;

    /**
     * Creates a new ListView instance.
     * 
     * Initializes the list view with the provided items array and sets up
     * the internal collection view, data source, and automatic update handlers.
     * 
     * @param items The initial array of items to display
     */
    public function new(items:Array<Dynamic>) {

        super();

        this.items = items;

        collectionView = new CellCollectionView();
        collectionView.itemsBehavior = RECYCLE;
        collectionView.viewSize(fill(), percent(25));
        collectionView.autorun(() -> {
            var theme = this.theme;
            unobserve();
            collectionView.theme = theme;
        });
        add(collectionView);

        dataSource = new ListViewDataSource(this);

        autorun(updateFromItems);
        autorun(updateFromScrollEnabled);

        app.onUpdate(this, checkLockedIfNeeded);

    }

    /**
     * Updates scroll behavior based on the scrollEnabled property.
     * 
     * Enables or disables scrolling and scrollbar visibility based on
     * the current scrollEnabled setting.
     */
    function updateFromScrollEnabled() {

        final scrollEnabled = this.scrollEnabled;

        unobserve();

        final scroller = collectionView.scroller;
        scroller.scrollEnabled = scrollEnabled;
        scroller.scrollbar.active = scrollEnabled;

    }

    /**
     * Updates the collection view when items change.
     * 
     * Reloads the collection view data and ensures proper layout and
     * scrolling when the items array or related properties change.
     */
    function updateFromItems() {

        var items = this.items;
        var smallItems = this.smallItems;
        var scrollEnabled = this.scrollEnabled; // Needed to recompute items width

        unobserve();

        collectionView.reloadData();
        collectionView.onceLayout(this, () -> {
            collectionView.scroller.scrollToBounds();
        });
        collectionView.layoutDirty = true;

        reobserve();

    }

    /**
     * Overrides layout to properly size the collection view.
     * 
     * Ensures the collection view matches the size of this ListView.
     */
    override function layout() {

        super.layout();

        collectionView.size(width, height);

    }

    /**
     * Checks item locked states if auto-checking is enabled.
     * 
     * Called every frame to update locked states when autoCheckLocked is true.
     * 
     * @param delta Time elapsed since last frame
     */
    function checkLockedIfNeeded(delta:Float) {

        if (!autoCheckLocked)
            return;

        checkLocked();

    }

    /**
     * Called after a lock item event is emitted.
     * 
     * Triggers a check of all item locked states to update the UI.
     * 
     * @param itemIndex The index of the item that was locked
     */
    function didEmitLockItem(itemIndex:Int) {

        checkLocked();

    }

    /**
     * Called after an unlock item event is emitted.
     * 
     * Triggers a check of all item locked states to update the UI.
     * 
     * @param itemIndex The index of the item that was unlocked
     */
    function didEmitUnlockItem(itemIndex:Int) {

        checkLocked();

    }

    /**
     * Checks and updates the locked state of all visible items.
     * 
     * Iterates through all visible cell views and updates their locked
     * state based on the 'locked' property of their corresponding items.
     * Automatically deselects any item that becomes locked.
     */
    function checkLocked() {

        var items = this.items;
        if (items == null)
            return;

        var frames = collectionView.frames;
        for (i in 0...frames.length) {
            var frame = frames.unsafeGet(i);
            var view = frame.view;
            var item = items[i];
            if (item != null && view != null && !view.destroyed && view is CellView) {
                var cellView:CellView = cast view;
                var locked:Bool = false;
                if (!Std.isOfType(item, String) && Reflect.getProperty(item, 'locked') == true) {
                    locked = true;
                }
                cellView.locked = locked;
                if (locked && i == selectedIndex) {
                    selectedIndex = -1;
                }
            }
        }

    }

}

/**
 * Data source implementation for ListView's collection view.
 * 
 * Handles the interface between ListView and its internal CellCollectionView,
 * providing item data, managing cell creation and recycling, and binding
 * cell behavior to list functionality.
 * 
 * @see CollectionViewDataSource
 * @see ListView
 * @see CellView
 */
class ListViewDataSource implements CollectionViewDataSource {

    /** Reference to the parent ListView */
    var listView:ListView;

    /**
     * Creates a new data source for the specified ListView.
     * 
     * @param listView The ListView this data source serves
     */
    public function new(listView:ListView) {

        this.listView = listView;

    }

    /**
     * Returns the number of items in the collection.
     * 
     * @param collectionView The requesting collection view
     * @return The number of items in the ListView's items array
     */
    public function collectionViewSize(collectionView:CollectionView):Int {

        return listView.items != null ? listView.items.length : 0;

    }

    /**
     * Configures the frame dimensions for an item at the specified index.
     * 
     * Sets the width to fill the collection view (minus scrollbar space if enabled)
     * and height based on the smallItems setting.
     * 
     * @param collectionView The requesting collection view
     * @param itemIndex The index of the item
     * @param frame The frame to configure
     */
    public function collectionViewItemFrameAtIndex(collectionView:CollectionView, itemIndex:Int, frame:CollectionViewItemFrame):Void {

        frame.width = collectionView.width - (listView.scrollEnabled ? 12 : 0);
        frame.height = listView.smallItems ? ListView.CELL_HEIGHT_SMALL : ListView.CELL_HEIGHT_LARGE; // TODO adapt depending on kind of list item

    }

    /**
     * Called when a view is no longer needed at the given index.
     * 
     * Allows cleanup before view reuse. Currently always returns true
     * to allow cell recycling for optimal performance.
     * 
     * @param collectionView The requesting collection view
     * @param itemIndex The index where the view was used
     * @param view The view being released
     * @return `true` if the view can be reused, `false` otherwise
     */
    public function collectionViewReleaseItemAtIndex(collectionView:CollectionView, itemIndex:Int, view:View):Bool {

        return true;

    }

    /**
     * Creates or recycles a view for the item at the specified index.
     * 
     * If a reusable view is provided, it's recycled and updated with the new
     * item index. Otherwise, a new CellView is created and fully configured.
     * 
     * @param collectionView The requesting collection view
     * @param itemIndex The index of the item to display
     * @param reusableView Optional view to recycle
     * @return A configured CellView for the item
     */
    public function collectionViewItemAtIndex(collectionView:CollectionView, itemIndex:Int, reusableView:View):View {

        var cell:CellView = null;
        if (reusableView != null) {
            cell = cast reusableView;
            cell.itemIndex = itemIndex;
        }
        else {
            cell = new CellView();
            cell.itemIndex = itemIndex;
            cell.collectionView = cast collectionView;
            bindCellView(cell);
        }

        return cell;

    }

    /**
     * Binds data and behavior to a CellView.
     * 
     * Sets up automatic data binding, theme updates, click handling,
     * drag-and-drop behavior, and action handlers (trash, lock, duplicate)
     * for the cell based on ListView configuration.
     * 
     * @param cell The CellView to bind
     */
    function bindCellView(cell:CellView):Void {

        cell.autorun(function() {

            var items = listView.items;
            var item:Dynamic = items != null ? items[cell.itemIndex] : null;
            if (item == null)
                return;

            if (Std.isOfType(item, String)) {
                cell.title = item;
                cell.subTitle = null;
                cell.locked = false;
            }
            else {
                cell.title = Reflect.getProperty(item, 'title');
                cell.subTitle = listView.smallItems ? null : Reflect.getProperty(item, 'subTitle');
                cell.locked = (Reflect.getProperty(item, 'locked') == true);
            }
            cell.selected = (cell.itemIndex == listView.selectedIndex);

        });

        cell.autorun(function() {

            var theme = listView.theme;
            unobserve();
            cell.theme = theme;

        });


        var click = new Click();
        cell.component('click', click);
        click.onClick(cell, function() {

            if (cell.locked)
                return;

            if (listView.selectedIndex != cell.itemIndex) {
                listView.selectedIndex = cell.itemIndex;
            }
            else {
                listView.selectedIndex = -1;
            }

        });

        cell.autorun(function() {

            var sortable = listView.sortable;

            unobserve();

            if (sortable) {
                cell.bindDragDrop(click, function(itemIndex) {
                    if (itemIndex != cell.itemIndex) {
                        var items = listView.items;
                        var item:Dynamic = items != null ? items[cell.itemIndex] : null;
                        if (item == null)
                            return;
                        var otherItem:Dynamic = items != null ? items[itemIndex] : null;
                        if (otherItem == null)
                            return;

                        if (itemIndex > cell.itemIndex) {
                            listView.emitMoveItemAboveItem(cell.itemIndex, itemIndex);
                        }
                        else {
                            listView.emitMoveItemBelowItem(cell.itemIndex, itemIndex);
                        }
                    }
                });
            }
            else {
                cell.unbindDragDrop();
            }

            reobserve();

        });

        cell.autorun(function() {

            var trashable = listView.trashable;

            unobserve();

            if (trashable) {
                cell.handleTrash = function() {
                    var items = listView.items;
                    var item:Dynamic = items != null ? items[cell.itemIndex] : null;
                    if (item == null)
                        return;
                    listView.emitTrashItem(cell.itemIndex);
                };
            }
            else {
                cell.handleTrash = null;
            }

            reobserve();

        });

        cell.autorun(function() {

            var lockable = listView.lockable;

            unobserve();

            if (lockable) {
                cell.handleLock = function() {
                    var items = listView.items;
                    var item:Dynamic = items != null ? items[cell.itemIndex] : null;
                    if (item == null || Std.isOfType(item, String))
                        return;
                    var locked = (item.locked != true);
                    item.locked = locked;
                    if (locked)
                        listView.emitLockItem(cell.itemIndex);
                    else
                        listView.emitUnlockItem(cell.itemIndex);
                };
            }
            else {
                cell.handleLock = null;
            }

            reobserve();

        });

        cell.autorun(function() {

            var duplicable = listView.duplicable;

            unobserve();

            if (duplicable) {
                cell.handleDuplicate = function() {
                    var items = listView.items;
                    var item:Dynamic = items != null ? items[cell.itemIndex] : null;
                    if (item == null)
                        return;
                    listView.emitDuplicateItem(cell.itemIndex);
                };
            }
            else {
                cell.handleDuplicate = null;
            }

            reobserve();

        });

        cell.onDraggingChange(listView, handleCellDraggingChange);
        cell.onDestroy(listView, handleCellDestroy);

    }

    /**
     * Handles changes in cell dragging state.
     * 
     * Updates the collection view's items behavior to prevent recycling
     * during drag operations for smoother interaction.
     * 
     * @param dragging Current dragging state
     * @param wasDragging Previous dragging state
     */
    function handleCellDraggingChange(dragging:Bool, wasDragging:Bool) {

        updateItemsBehaviorFromDragging();

    }

    /**
     * Handles cell destruction.
     * 
     * Updates items behavior when a cell is destroyed to ensure
     * proper state management.
     * 
     * @param destroyed The destroyed entity
     */
    function handleCellDestroy(destroyed:Entity) {

        updateItemsBehaviorFromDragging();

    }

    /**
     * Updates collection view behavior based on dragging state.
     * 
     * Switches between LAZY and RECYCLE behaviors:
     * - LAZY: When any cell is being dragged (prevents recycling)
     * - RECYCLE: When no cells are being dragged (allows recycling)
     * 
     * This ensures smooth drag interactions while maintaining performance.
     */
    function updateItemsBehaviorFromDragging() {

        var frames = listView.collectionView.frames;
        var anyDragging = false;
        for (i in 0...frames.length) {
            var frame = frames.unsafeGet(i);
            var view = frame.view;
            if (view != null && !view.destroyed && view is CellView) {
                var cellView:CellView = cast view;
                if (cellView.dragging) {
                    anyDragging = true;
                    break;
                }
            }
        }

        listView.collectionView.itemsBehavior = anyDragging ? LAZY : RECYCLE;

    }

}
