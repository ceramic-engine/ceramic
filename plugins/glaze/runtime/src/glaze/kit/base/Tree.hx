// Ported from gpui-kit 0.8.1: crates/base/src/tree.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Additions without upstream equivalent (KIT-004 in docs/DEVIATIONS.md): `TreeItem.folder`, `setItems` keeping the
// selection, `toggleOnClick`, `navigationKeys`. KIT-022: `rowHeight` (rows of different heights).
package glaze.kit.base;

import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.Component;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.MouseButton;
import glaze.Range;
import glaze.Render;
import glaze.ScrollStrategy;
import glaze.Size;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.UniformListScrollHandle;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.Scrollbar.ScrollbarHandle;
import glaze.kit.base.VirtualList.VirtualListScrollHandle;

import glaze.Prelude.*;

using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;

/** The shared expansion and disabled state of a tree item (and its clones). */
class TreeItemState {

    public var expanded:Bool;

    public var disabled:Bool;

    public function new(expanded:Bool, disabled:Bool) {
        this.expanded = expanded;
        this.disabled = disabled;
    }

}

/**
 * A tree item with a stable id, display label, children, and shared state.
 *
 * Clones (`clone()`, Rust `Clone`) share the state of the original.
 */
class TreeItem {

    public var id:String;

    public var label:String;

    public var children:Array<TreeItem>;

    @:allow(glaze.kit.base)
    var state:TreeItemState;

    /** See `folder`. */
    var folderValue:Null<Bool> = null;

    public function new(id:String, label:String) {
        this.id = id;
        this.label = label;
        children = [];
        state = new TreeItemState(false, false);
    }

    /**
     * Rust `Clone`: a copy whose state (expanded, disabled) is shared, and
     * whose children are clones of these children.
     */
    public function clone():TreeItem {
        final item = new TreeItem(id, label);
        item.children = [for (child in children) child.clone()];
        item.state = state;
        item.folderValue = folderValue;
        return item;
    }

    /**
     * Says whether the item is a folder, whatever its children: an empty
     * folder stays a folder (it expands, collapses and reports it), and
     * `folder(false)` makes an item with children a leaf. Without this call
     * an item is a folder when it has children, as in gpui-kit.
     */
    public function folder(folder:Bool):TreeItem {
        folderValue = folder;
        return this;
    }

    public function child(child:TreeItem):TreeItem {
        if (child != null) children.push(child);
        return this;
    }

    public function withChildren(children:Array<TreeItem>):TreeItem {
        for (child in children) this.children.push(child);
        return this;
    }

    public function expanded(expanded:Bool):TreeItem {
        state.expanded = expanded;
        return this;
    }

    public function disabled(disabled:Bool):TreeItem {
        state.disabled = disabled;
        return this;
    }

    public inline function isFolder():Bool {
        return folderValue != null ? folderValue : children.length > 0;
    }

    public function isDisabled():Bool {
        return state.disabled;
    }

    public inline function isExpanded():Bool {
        return state.expanded;
    }

    /** Returns the target's ancestors from nearest parent to root. */
    public function ancestors(targetId:String):Null<Array<TreeItem>> {
        final path = ancestorRefs(targetId);
        return path != null ? [for (item in path) item.clone()] : null;
    }

    /**
     * Like `ancestors`, but borrows the ancestors instead of deep-cloning
     * each one's subtree.
     */
    @:allow(glaze.kit.base)
    function ancestorRefs(targetId:String):Null<Array<TreeItem>> {
        if (id == targetId) {
            return [];
        }

        for (child in children) {
            final path = child.ancestorRefs(targetId);
            if (path != null) {
                path.push(this);
                return path;
            }
        }

        return null;
    }

}

/** A flat representation of a tree item with its depth. */
class TreeEntry {

    final itemValue:TreeItem;

    final depthValue:Int;

    public function new(item:TreeItem, depth:Int) {
        itemValue = item;
        depthValue = depth;
    }

    public inline function item():TreeItem {
        return itemValue;
    }

    public inline function depth():Int {
        return depthValue;
    }

    public inline function isRoot():Bool {
        return depthValue == 0;
    }

    public inline function isFolder():Bool {
        return itemValue.isFolder();
    }

    public inline function isExpanded():Bool {
        return itemValue.isExpanded();
    }

    public inline function isDisabled():Bool {
        return itemValue.isDisabled();
    }

    /** Rust `Clone` of the entry (the item is cloned, sharing its state). */
    public function clone():TreeEntry {
        return new TreeEntry(itemValue.clone(), depthValue);
    }

}

/** Event emitted by a tree when user-visible expansion state changes. */
enum TreeEvent {
    Expanded(id:String);
    Collapsed(id:String);
}

/** The interaction state supplied while rendering a visible tree entry. */
class TreeEntryState {

    final selected:Bool;

    final rightClicked:Bool;

    public function new(selected:Bool = false, rightClicked:Bool = false) {
        this.selected = selected;
        this.rightClicked = rightClicked;
    }

    public inline function isSelected():Bool {
        return selected;
    }

    public inline function isRightClicked():Bool {
        return rightClicked;
    }

    public function equals(other:TreeEntryState):Bool {
        return selected == other.selected && rightClicked == other.rightClicked;
    }

}

typedef TreeRenderItem = (Int, TreeEntry, TreeEntryState, Window, App) -> AnyElement;

/** Behavior and interaction state for a virtualized tree. */
@:allow(glaze.kit.base, glaze.kit, tests)
class TreeState extends Model implements Render {

    static inline final CONTEXT:String = TreeKeys.CONTEXT;

    /** Rust `tree::init`: binds the tree keys. */
    public static function init(cx:AppContext):Void {
        TreeKeys.init(cx);
    }

    /** Rust `tree::key_context`. */
    public static inline function keyContext():String {
        return CONTEXT;
    }

    final focusHandle:FocusHandle;

    var entries:Array<TreeEntry> = [];

    final scrollHandleValue:UniformListScrollHandle = new UniformListScrollHandle();

    var selectedIx:Null<Int> = null;

    var rightClickedIx:Null<Int> = null;

    var renderItem:TreeRenderItem = (_, _, _, _, _) -> div().intoAnyElement();

    var listStyle:StyleRefinement = new StyleRefinement();

    /** See `Tree.toggleOnClick`. */
    var toggleOnClick:Bool = true;

    /** See `Tree.navigationKeys`. */
    var navigationKeys:Bool = false;

    /** See `Tree.rowHeight`. */
    var rowHeight:Null<(ix:Int, entry:TreeEntry) -> Float> = null;

    /** The scroll handle of the list of rows of different heights (`Tree.rowHeight`). */
    final rowScrollHandleValue:VirtualListScrollHandle = new VirtualListScrollHandle();

    /** The row sizes given to the list last, reused while the heights do not change. */
    var rowSizes:Array<Size> = [];

    public function new(cx:AppContext) {
        super();
        focusHandle = (cx : App).focusHandle();
    }

    public function items(items:Array<TreeItem>):TreeState {
        replaceItems(items);
        return this;
    }

    /**
     * Replaces the items. The selection is dropped, as in gpui-kit, unless
     * `keepSelection` is true: the selected and the right clicked entries
     * are then found again by their ids (and dropped when their item is gone
     * or no longer visible).
     */
    public function setItems(items:Array<TreeItem>, cx:Context<Dynamic>, keepSelection:Bool = false):Void {
        final selectedId = keepSelection && selectedIx != null && entry(selectedIx) != null ? entry(selectedIx).item().id : null;
        final rightClickedId = keepSelection && rightClickedIx != null && entry(rightClickedIx) != null ? entry(rightClickedIx).item().id : null;
        replaceItems(items);
        selectedIx = selectedId != null ? indexOf(selectedId) : null;
        rightClickedIx = rightClickedId != null ? indexOf(rightClickedId) : null;
        cx.notify();
    }

    /**
     * Expands or collapses the folder at `ix`, like a click on it does
     * (for a tree whose `toggleOnClick` is off).
     */
    public function toggleExpanded(ix:Int, cx:Context<Dynamic>):Void {
        toggleExpand(ix, cx);
        cx.notify();
    }

    public inline function selectedIndex():Null<Int> {
        return selectedIx;
    }

    public function setSelectedIndex(ix:Null<Int>, cx:Context<Dynamic>):Void {
        selectedIx = ix;
        cx.notify();
    }

    public function setSelectedItem(item:Null<TreeItem>, cx:Context<Dynamic>):Void {
        if (item != null) {
            selectedIx = indexOf(item.id);
            if (selectedIx == null) {
                expandAncestors(item.id, cx);
                selectedIx = indexOf(item.id);
            }
        } else {
            selectedIx = null;
        }
        cx.notify();
    }

    public function selectedItem():Null<TreeItem> {
        final entry = selectedEntry();
        return entry != null ? entry.item() : null;
    }

    public function selectedEntry():Null<TreeEntry> {
        return selectedIx != null ? entry(selectedIx) : null;
    }

    public function entry(ix:Int):Null<TreeEntry> {
        return ix >= 0 && ix < entries.length ? entries[ix] : null;
    }

    public inline function scrollHandle():UniformListScrollHandle {
        return scrollHandleValue;
    }

    /**
     * The scroll handle of the list of rows of different heights, the one
     * in use while `Tree.rowHeight` is set (`scrollHandle()` is then idle).
     */
    public inline function rowScrollHandle():VirtualListScrollHandle {
        return rowScrollHandleValue;
    }

    /** The handle of the list in use, for a scrollbar: `rowScrollHandle()` with `Tree.rowHeight`, else `scrollHandle()`. */
    public function scrollbarHandle():ScrollbarHandle {
        return rowHeight != null ? (rowScrollHandleValue : ScrollbarHandle) : (scrollHandleValue : ScrollbarHandle);
    }

    public function scrollToItem(ix:Int, strategy:ScrollStrategy):Void {
        if (rowHeight != null) {
            rowScrollHandleValue.scrollToItem(ix, strategy);
        }
        else {
            scrollHandleValue.scrollToItem(ix, strategy);
        }
    }

    public function indexOf(id:String):Null<Int> {
        for (ix in 0...entries.length) {
            if (entries[ix].item().id == id) return ix;
        }
        return null;
    }

    public function revealItem(id:String, strategy:ScrollStrategy, cx:Context<Dynamic>):Void {
        expandAncestors(id, cx);
        final ix = indexOf(id);
        if (ix != null) {
            scrollToItem(ix, strategy);
        }
    }

    public function focus(window:Window, cx:AppContext):Void {
        focusHandle.focus(window, cx);
    }

    function replaceItems(items:Array<TreeItem>):Void {
        entries = [];
        for (item in items) {
            pushRoot(item);
        }
    }

    function expandAncestors(targetId:String, cx:Context<Dynamic>):Void {
        // Entries are in depth-first order, so the root containing the target
        // precedes every descendant entry whose subtree could also contain it.
        var ancestors:Null<Array<TreeItem>> = null;
        for (entry in entries) {
            if (!entry.isRoot()) continue;
            ancestors = entry.item().ancestorRefs(targetId);
            if (ancestors != null) break;
        }
        if (ancestors == null) ancestors = [];

        if (ancestors.length == 0) {
            return;
        }

        var i = ancestors.length - 1;
        while (i >= 0) {
            final ancestor = ancestors[i];
            if (!ancestor.isExpanded()) {
                ancestor.state.expanded = true;
                cx.emit(TreeEvent.Expanded(ancestor.id));
            }
            i--;
        }
        rebuildEntries();
    }

    /**
     * Moves an owned root item into the entries, flattening its visible
     * descendants by reference so the root's subtree is not cloned.
     */
    function pushRoot(item:TreeItem):Void {
        final children = item.isExpanded() ? item.children : [];
        if (item.isExpanded()) item.children = [];

        final ix = entries.length;
        entries.push(new TreeEntry(item, 0));
        if (children.length > 0) {
            for (child in children) {
                addEntry(child, 1);
            }
            entries[ix].item().children = children;
        }
    }

    function addEntry(item:TreeItem, depth:Int):Void {
        entries.push(new TreeEntry(item.clone(), depth));
        if (item.isExpanded()) {
            for (child in item.children) {
                addEntry(child, depth + 1);
            }
        }
    }

    function toggleExpand(ix:Int, cx:Context<Dynamic>):Void {
        final entry = this.entry(ix);
        if (entry == null) {
            return;
        }
        if (!entry.isFolder()) {
            return;
        }

        final expanded = !entry.isExpanded();
        final id = entry.item().id;
        entry.item().state.expanded = expanded;
        cx.emit(expanded ? TreeEvent.Expanded(id) : TreeEvent.Collapsed(id));
        rightClickedIx = null;
        rebuildEntries();
    }

    function rebuildEntries():Void {
        final roots = [for (entry in entries) if (entry.isRoot()) entry.item()];
        entries = [];
        replaceItems(roots);
    }

    function onActionConfirm(_:Confirm, _:Window, cx:Context<Dynamic>):Void {
        final ix = selectedIx;
        final entry = ix != null ? this.entry(ix) : null;
        if (entry != null) {
            final isFolder = entry.isFolder();
            if (isFolder) {
                toggleExpand(ix, cx);
                cx.notify();
            }
        }
    }

    function onActionLeft(_:SelectLeft, _:Window, cx:Context<Dynamic>):Void {
        final ix = selectedIx;
        if (ix != null) {
            final entry = this.entry(ix);
            if (entry != null && entry.isFolder() && entry.isExpanded()) {
                toggleExpand(ix, cx);
                cx.notify();
            } else if (entry != null && navigationKeys) {
                // On a leaf or a collapsed folder, left goes to the parent.
                final parent = parentIndex(ix);
                if (parent != null) select(parent, ScrollStrategy.Top, cx);
            }
        }
    }

    /** The index of the entry holding the entry at `ix`, `null` for a root. */
    public function parentIndex(ix:Int):Null<Int> {
        final entry = this.entry(ix);
        if (entry == null) return null;
        var i = ix - 1;
        while (i >= 0) {
            if (entries[i].depth() < entry.depth()) return i;
            i--;
        }
        return null;
    }

    function select(ix:Int, strategy:ScrollStrategy, cx:Context<Dynamic>):Void {
        selectedIx = ix;
        scrollToItem(ix, strategy);
        cx.notify();
    }

    /** How many entries fit in the list, less one (ten before the first layout). */
    function pageSize():Int {
        if (this.rowHeight != null) {
            // Rows of different heights: their mean height
            if (entries.length == 0) return 10;
            final viewport:Float = rowScrollHandleValue.bounds().size.height;
            final mean:Float = rowScrollHandleValue.contentSize().height / entries.length;
            if (mean <= 0. || viewport <= 0.) return 10;
            final rows = Math.floor(viewport / mean) - 1;
            return rows > 1 ? rows : 1;
        }
        final size = scrollHandleValue.state.lastItemSize;
        if (size == null || entries.length == 0) return 10;
        final viewport:Float = size.item.height;
        final rowHeight:Float = size.contents.height / entries.length;
        if (rowHeight <= 0. || viewport <= 0.) return 10;
        final rows = Math.floor(viewport / rowHeight) - 1;
        return rows > 1 ? rows : 1;
    }

    /**
     * Home, End, PageUp and PageDown, when `navigationKeys` is on. Returns
     * whether the key was one of them.
     */
    function onNavigationKey(key:String, cx:Context<Dynamic>):Bool {
        if (!navigationKeys || entries.length == 0) return false;
        final last = entries.length - 1;
        final current = selectedIx != null ? selectedIx : 0;
        switch key {
            case 'home':
                select(0, ScrollStrategy.Top, cx);
            case 'end':
                select(last, ScrollStrategy.Bottom, cx);
            case 'pageup':
                final ix = current - pageSize();
                select(ix > 0 ? ix : 0, ScrollStrategy.Top, cx);
            case 'pagedown':
                final ix = current + pageSize();
                select(ix < last ? ix : last, ScrollStrategy.Bottom, cx);
            case _:
                return false;
        }
        return true;
    }

    function onActionRight(_:SelectRight, _:Window, cx:Context<Dynamic>):Void {
        final ix = selectedIx;
        if (ix != null) {
            final entry = this.entry(ix);
            if (entry != null && entry.isFolder() && !entry.isExpanded()) {
                toggleExpand(ix, cx);
                cx.notify();
            }
        }
    }

    function onActionUp(_:SelectUp, _:Window, cx:Context<Dynamic>):Void {
        var ix = selectedIx != null ? selectedIx : 0;
        ix = ix > 0 ? ix - 1 : (entries.length > 0 ? entries.length - 1 : 0);
        selectedIx = ix;
        scrollToItem(ix, ScrollStrategy.Top);
        cx.notify();
    }

    function onActionDown(_:SelectDown, _:Window, cx:Context<Dynamic>):Void {
        var ix = selectedIx != null ? selectedIx : 0;
        ix = ix + 1 < entries.length ? ix + 1 : 0;
        selectedIx = ix;
        scrollToItem(ix, ScrollStrategy.Bottom);
        cx.notify();
    }

    function onEntryClick(ix:Int, cx:Context<Dynamic>, clickCount:Int = 1):Void {
        selectedIx = ix;
        // Without the toggle on a single click, a double click toggles.
        if (toggleOnClick || clickCount == 2) toggleExpand(ix, cx);
        cx.notify();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<TreeState> = cast cx;
        final renderItem = this.renderItem;
        final process = cx.processor((state:TreeState, range:Range, window:Window, cx:Context<TreeState>) -> {
            final items:Array<IntoElement> = [];
            for (ix in range.start...range.end) {
                final entry = state.entries[ix];
                final entryState = new TreeEntryState(ix == state.selectedIx, ix == state.rightClickedIx);
                // Rust `.role(Role::TreeItem)`, `.aria_label(label)`,
                // `.aria_selected(selected)`, `.aria_expanded(expanded)` for
                // folders: no accessibility tree in the port.
                final element = div()
                    .id(ix)
                    .testSupport()
                    .child(renderItem(ix, entry, entryState, window, cx.app));
                if (!entry.isDisabled()) {
                    // Select and toggle on a full click, like `List` and `Table`
                    // rows, so a press that is dragged away leaves the entry alone.
                    element.onClick(cx.listener((state:TreeState, event:glaze.ClickEvent, _, cx) -> {
                        state.onEntryClick(ix, cx, glaze.ClickEvent.ClickEventTools.clickCount(event));
                    }))
                        .onMouseDown(MouseButton.Right, cx.listener((state:TreeState, _, _, cx) -> {
                            state.rightClickedIx = ix;
                            cx.notify();
                        }));
                }
                items.push(element);
            }
            return items;
        });
        final heights = rowHeight;
        if (heights != null) {
            // KIT-022: rows of different heights, known before layout, so
            // the list stays virtual (only the rows in view are built).
            final previous = rowSizes;
            final sizes:Array<Size> = [];
            for (ix in 0...entries.length) {
                final height = heights(ix, entries[ix]);
                final kept = ix < previous.length ? previous[ix] : null;
                sizes.push(kept != null && kept.height == height ? kept : new Size(0., height));
            }
            rowSizes = sizes;
            return glaze.kit.base.VirtualList.vVirtualList(cx.entity(), "entries", sizes,
                    (_:TreeState, start:Int, end:Int, window:Window, cx:Context<TreeState>) -> process(new Range(start, end), window, cx.app))
                .trackScroll(rowScrollHandleValue)
                .refineStyle(listStyle);
        }
        return uniformList("entries", entries.length, (start, end, window, app) -> process(new Range(start, end), window, app))
            .trackScroll(scrollHandleValue)
            .refineStyle(listStyle);
    }

}

/**
 * An unstyled, virtualized tree element.
 *
 * A click on an entry, a press and release on that same entry, selects it
 * and expands or collapses it when it is a folder. Click handlers in the
 * content from `Tree.item` run first, so they still see the previous
 * selection. To drag entries, use `onDrag` on that content: a press that
 * starts a drag is not a click.
 */
class Tree extends Component implements Styled {

    final id:ElementId;

    final state:Entity<TreeState>;

    final treeStyle:StyleRefinement = new StyleRefinement();

    /** Applies caller-owned presentation to the internal virtual list. */
    @prop var listStyle:StyleRefinement = new StyleRefinement();

    /** Supplies the application-owned content for each visible entry. */
    @prop var item:TreeRenderItem = (_, _, _, _, _) -> div().intoAnyElement();

    /**
     * Whether a single click on a folder expands or collapses it (default
     * true, as in gpui-kit). When false a click only selects, and a double
     * click, Enter, the left and right arrows or `TreeState.toggleExpanded`
     * toggle.
     */
    @prop var toggleOnClick:Bool = true;

    /**
     * Whether Home, End, PageUp and PageDown move the selection, and the
     * left arrow on a leaf or a collapsed folder selects its parent
     * (default false, as in gpui-kit).
     */
    @prop var navigationKeys:Bool = false;

    /**
     * The height of each row, for rows of different heights (KIT-022). Null
     * by default: every row has the height of the first one, as in gpui-kit
     * (a uniform list). When set, the function gives the height of the row
     * of an entry in pixels, the content of the row is laid out in exactly
     * that height, and the list stays virtual. The scroll handle in use is
     * then `TreeState.rowScrollHandle()` (`TreeState.scrollbarHandle()`
     * gives the one in use either way).
     */
    @prop var rowHeight:Null<(ix:Int, entry:TreeEntry) -> Float> = null;

    public function new(state:Entity<TreeState>) {
        super();
        id = ElementId.Name('tree-' + state.entityId());
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return treeStyle;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = state.read(cx).focusHandle;
        final renderItem = item;
        final listStyle = this.listStyle;
        final toggleOnClick = this.toggleOnClick;
        final navigationKeys = this.navigationKeys;
        final rowHeight = this.rowHeight;
        state.update(cx, (state, _) -> {
            state.rowHeight = rowHeight;
            state.renderItem = renderItem;
            state.listStyle = listStyle;
            state.toggleOnClick = toggleOnClick;
            state.navigationKeys = navigationKeys;
        });

        final state = this.state;
        final root = div();
        if (navigationKeys) {
            root.onKeyDown((event, _, cx) -> {
                final keystroke = event.keystroke;
                if (keystroke.modifiers.modified()) return;
                if (state.update(cx, (s, cx) -> s.onNavigationKey(keystroke.key, cx))) cx.stopPropagation();
            });
        }
        // Rust `.role(Role::Tree)`: no accessibility tree in the port.
        return root
            .id(id)
            .testSupport()
            .keyContext(TreeState.CONTEXT)
            .trackFocus(focusHandle)
            .onAction(Confirm, (e, window, cx) -> state.update(cx, (s, cx) -> s.onActionConfirm(e, window, cx)))
            .onAction(SelectLeft, (e, window, cx) -> state.update(cx, (s, cx) -> s.onActionLeft(e, window, cx)))
            .onAction(SelectRight, (e, window, cx) -> state.update(cx, (s, cx) -> s.onActionRight(e, window, cx)))
            .onAction(SelectUp, (e, window, cx) -> state.update(cx, (s, cx) -> s.onActionUp(e, window, cx)))
            .onAction(SelectDown, (e, window, cx) -> state.update(cx, (s, cx) -> s.onActionDown(e, window, cx)))
            .child(state)
            .refineStyle(treeStyle);
    }

}
