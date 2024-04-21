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

@:allow(elements.ListViewDataSource)
class ListView extends View implements Observable {

    public static final CELL_HEIGHT_SMALL:Int = 30;

    public static final CELL_HEIGHT_LARGE:Int = 39;

    @event function moveItemAboveItem(itemIndex:Int, otherItemIndex:Int);

    @event function moveItemBelowItem(itemIndex:Int, otherItemIndex:Int);

    @event function trashItem(itemIndex:Int);

    @event function lockItem(itemIndex:Int);

    @event function unlockItem(itemIndex:Int);

    @event function duplicateItem(itemIndex:Int);

    public var collectionView(default, null):CellCollectionView;

    public var dataSource(default, set):CollectionViewDataSource;
    function set_dataSource(dataSource:CollectionViewDataSource):CollectionViewDataSource {
        this.dataSource = dataSource;
        collectionView.dataSource = dataSource;
        return dataSource;
    }

    @observe public var theme:Theme = null;

    @observe public var items:Array<Dynamic>;

    @observe public var selectedIndex:Int = -1;

    @observe public var trashable:Bool = false;

    @observe public var lockable:Bool = false;

    @observe public var duplicable:Bool = false;

    @observe public var sortable:Bool = false;

    @observe public var smallItems:Bool = false;

    @observe public var scrollEnabled:Bool = true;

    public var autoCheckLocked:Bool = true;

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

    function updateFromScrollEnabled() {

        final scrollEnabled = this.scrollEnabled;

        unobserve();

        final scroller = collectionView.scroller;
        scroller.scrollEnabled = scrollEnabled;
        scroller.scrollbar.active = scrollEnabled;

    }

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

    override function layout() {

        super.layout();

        collectionView.size(width, height);

    }

    function checkLockedIfNeeded(delta:Float) {

        if (!autoCheckLocked)
            return;

        checkLocked();

    }

    function didEmitLockItem(itemIndex:Int) {

        checkLocked();

    }

    function didEmitUnlockItem(itemIndex:Int) {

        checkLocked();

    }

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

class ListViewDataSource implements CollectionViewDataSource {

    var listView:ListView;

    public function new(listView:ListView) {

        this.listView = listView;

    }

    /** Get the number of elements. */
    public function collectionViewSize(collectionView:CollectionView):Int {

        return listView.items != null ? listView.items.length : 0;

    }

    /** Get the item frame at the requested index. */
    public function collectionViewItemFrameAtIndex(collectionView:CollectionView, itemIndex:Int, frame:CollectionViewItemFrame):Void {

        frame.width = collectionView.width - (listView.scrollEnabled ? 12 : 0);
        frame.height = listView.smallItems ? ListView.CELL_HEIGHT_SMALL : ListView.CELL_HEIGHT_LARGE; // TODO adapt depending on kind of list item

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
            cell.itemIndex = itemIndex;
            cell.collectionView = cast collectionView;
            bindCellView(cell);
        }

        return cell;

    }

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

    function handleCellDraggingChange(dragging:Bool, wasDragging:Bool) {

        updateItemsBehaviorFromDragging();

    }

    function handleCellDestroy(destroyed:Entity) {

        updateItemsBehaviorFromDragging();

    }

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
