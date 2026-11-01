// Ported from gpui-kit 0.8.1: crates/base/src/tree.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.Context;
import gpui.ElementId;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Model;
import gpui.MouseButton;
import gpui.Range;
import gpui.Render;
import gpui.RenderOnce;
import gpui.ScrollStrategy;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.UniformListScrollHandle;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Actions.Confirm;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectLeft;
import gpui.base.Actions.SelectRight;
import gpui.base.Actions.SelectUp;

import gpui.Prelude.*;

using gpui.base.Observe;
using gpui.base.StyledExt;

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

    @:allow(gpui.base)
    var state:TreeItemState;

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
        return item;
    }

    public function child(child:TreeItem):TreeItem {
        children.push(child);
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
        return children.length > 0;
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
    @:allow(gpui.base)
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
@:allow(gpui.base, gpui.component, tests)
class TreeState extends Model implements Render {

    static inline final CONTEXT:String = "Tree";

    /** Rust `tree::init`: binds the tree keys. */
    public static function init(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("left", new SelectLeft(), CONTEXT),
            new KeyBinding("right", new SelectRight(), CONTEXT),
        ]);
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

    public function new(cx:AppContext) {
        super();
        focusHandle = (cx : App).focusHandle();
    }

    public function items(items:Array<TreeItem>):TreeState {
        replaceItems(items);
        return this;
    }

    public function setItems(items:Array<TreeItem>, cx:Context<Dynamic>):Void {
        replaceItems(items);
        selectedIx = null;
        rightClickedIx = null;
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

    public function scrollToItem(ix:Int, strategy:ScrollStrategy):Void {
        scrollHandleValue.scrollToItem(ix, strategy);
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
            }
        }
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
        scrollHandleValue.scrollToItem(ix, ScrollStrategy.Top);
        cx.notify();
    }

    function onActionDown(_:SelectDown, _:Window, cx:Context<Dynamic>):Void {
        var ix = selectedIx != null ? selectedIx : 0;
        ix = ix + 1 < entries.length ? ix + 1 : 0;
        selectedIx = ix;
        scrollHandleValue.scrollToItem(ix, ScrollStrategy.Bottom);
        cx.notify();
    }

    function onEntryClick(ix:Int, cx:Context<Dynamic>):Void {
        selectedIx = ix;
        toggleExpand(ix, cx);
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
                    element.onClick(cx.listener((state:TreeState, _, _, cx) -> {
                        state.onEntryClick(ix, cx);
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
class Tree implements RenderOnce implements Styled {

    final id:ElementId;

    final state:Entity<TreeState>;

    final treeStyle:StyleRefinement = new StyleRefinement();

    var listStyleValue:StyleRefinement = new StyleRefinement();

    var renderItemValue:TreeRenderItem = (_, _, _, _, _) -> div().intoAnyElement();

    public function new(state:Entity<TreeState>) {
        id = ElementId.Name('tree-' + state.entityId());
        this.state = state;
    }

    public inline function style():StyleRefinement {
        return treeStyle;
    }

    /** Supplies the application-owned content for each visible entry. */
    public function item(renderItem:TreeRenderItem):Tree {
        renderItemValue = renderItem;
        return this;
    }

    /** Applies caller-owned presentation to the internal virtual list. */
    public function listStyle(style:StyleRefinement):Tree {
        listStyleValue = style;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final focusHandle = state.read(cx).focusHandle;
        final renderItem = renderItemValue;
        final listStyle = listStyleValue;
        state.update(cx, (state, _) -> {
            state.renderItem = renderItem;
            state.listStyle = listStyle;
        });

        final state = this.state;
        // Rust `.role(Role::Tree)`: no accessibility tree in the port.
        return div()
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
