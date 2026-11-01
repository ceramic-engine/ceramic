// Ported from gpui-kit 0.8.1: crates/component/src/list/list.rs (`init`, `ListEvent`,
// `ListOptions`, `ListState`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.list;

import gpui.AnyElement;
import gpui.App;
import gpui.AppContext;
import gpui.AvailableSpace;
import gpui.ClickEvent;
import gpui.Context;
import gpui.DefiniteLength;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.KeyBinding;
import gpui.Length;
import gpui.ListSizingBehavior;
import gpui.Model;
import gpui.OperatingSystem;
import gpui.Point;
import gpui.Render;
import gpui.ScrollStrategy;
import gpui.SizeOf;
import gpui.Subscription;
import gpui.Task;
import gpui.Unit;
import gpui.Window;
import gpui.base.Actions.Cancel as CancelAction;
import gpui.base.Actions.Confirm as ConfirmAction;
import gpui.base.Actions.SelectDown;
import gpui.base.Actions.SelectUp;
import gpui.base.IndexPath;
import gpui.base.ScrollBounce;
import gpui.base.VirtualList;
import gpui.base.VirtualList.VirtualListScrollHandle;
import gpui.base.input.InputBaseState;
import gpui.base.input.InputEvent;
import gpui.base.input.InputState;
import gpui.component.I18n;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.input.Input;
import gpui.component.list.RowsCache;
import gpui.component.scroll.Scrollbar;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.ClickEvent.ClickEventTools;
using gpui.base.StyledExt;

/**
 * Events emitted by a `ListState`.
 */
enum ListEvent {
    /** Move to select item. */
    Select(ix:IndexPath);
    /** Click on item or pressed Enter. */
    Confirm(ix:IndexPath);
    /** Pressed ESC to deselect the item. */
    Cancel;
}

/**
 * The options a `List` element hands to its state.
 */
@:allow(gpui.component)
class ListOptions {

    public var scrollBounce:Null<Bool> = null;

    public var size:Size = Medium;

    public var scrollbarVisible:Bool = true;

    public var searchPlaceholder:Null<String> = null;

    public var maxHeight:Null<Length> = null;

    public var paddingTop:Null<DefiniteLength> = null;

    public var paddingRight:Null<DefiniteLength> = null;

    public var paddingBottom:Null<DefiniteLength> = null;

    public var paddingLeft:Null<DefiniteLength> = null;

    public function new() {}

}

/**
 * The state for List.
 *
 * List required all items has the same height.
 */
@:allow(gpui.component, tests)
class ListState<D:ListDelegate> extends Model implements Render {

    /** The key context of the list. */
    public static inline final CONTEXT:String = "List";

    /**
     * Rust `list::init`: binds the list keys.
     */
    public static function init(cx:AppContext):Void {
        final context = CONTEXT;
        (cx : App).bindKeys([
            new KeyBinding("escape", new CancelAction(), context),
            new KeyBinding("enter", new ConfirmAction(false), context),
            new KeyBinding(OperatingSystem.current.isMac() ? "cmd-enter" : "ctrl-enter", new ConfirmAction(true), context),
            new KeyBinding("up", new SelectUp(), context),
            new KeyBinding("down", new SelectDown(), context),
        ]);
    }

    public final focusHandleValue:FocusHandle;

    public final queryInput:Entity<InputState>;

    var options:ListOptions = new ListOptions();

    var delegateValue:D;

    var lastQuery:Null<String> = null;

    final scrollHandle:VirtualListScrollHandle = new VirtualListScrollHandle();

    var rowsCache:RowsCache = new RowsCache();

    var selectedIndexValue:Null<IndexPath> = null;

    var itemToMeasureIndex:IndexPath = IndexPath.defaultValue();

    var deferredScrollToIndex:Null<{ix:IndexPath, strategy:ScrollStrategy}> = null;

    var mouseRightClickedIndex:Null<IndexPath> = null;

    var resetOnCancelValue:Bool = true;

    var searchableValue:Bool = false;

    var selectableValue:Bool = true;

    var searchTask:Null<Task<Unit>> = null;

    var loadMoreTask:Null<Task<Unit>> = null;

    final queryInputSubscription:Subscription;

    public function new(delegate:D, window:Window, cx:Context<ListState<D>>) {
        super();
        queryInput = cx.newEntity(c -> new InputState(window, cast c).withPlaceholder(I18n.t('List.search_placeholder')));

        queryInputSubscription = cx.subscribeIn((cast queryInput : Entity<InputBaseState>), InputEvent, window, (this_, state, event, window, cx) -> this_.onQueryInputEvent(state, event, window, cx));

        focusHandleValue = cx.focusHandle();
        delegateValue = delegate;
    }

    /**
     * Sets whether the list is searchable, default is `false`.
     *
     * When `true`, there will be a search input at the top of the list.
     */
    public function searchable(searchable:Bool):ListState<D> {
        searchableValue = searchable;
        return this;
    }

    public function setSearchable(searchable:Bool, cx:Context<Dynamic>):Void {
        if (searchableValue != searchable) {
            searchableValue = searchable;
            cx.notify();
        }
    }

    /** Sets whether the list is selectable, default is true. */
    public function selectable(selectable:Bool):ListState<D> {
        selectableValue = selectable;
        return this;
    }

    /** Sets whether the list is selectable, default is true. */
    public function setSelectable(selectable:Bool, cx:Context<Dynamic>):Void {
        selectableValue = selectable;
        cx.notify();
    }

    public inline function delegate():D {
        return delegateValue;
    }

    /** Rust `delegate_mut()`. */
    public inline function delegateMut():D {
        return delegateValue;
    }

    /** Rust `list.delegate_mut().delegate = items` style replacement of the delegate. */
    public function setDelegate(delegate:D):Void {
        delegateValue = delegate;
    }

    /** Focus the list, if the list is searchable, focus the search input. */
    public function focus(window:Window, cx:App):Void {
        focusHandle(cx).focus(window, cx);
    }

    /** Return true if either the list or the search input is focused. */
    public function isFocused(window:Window, cx:App):Bool {
        return focusHandleValue.isFocused(window) || queryInput.read(cx).focusHandle.isFocused(window);
    }

    /**
     * Set the selected index of the list,
     * this will also scroll to the selected item.
     */
    public function _setSelectedIndex(ix:Null<IndexPath>, window:Window, cx:Context<Dynamic>):Void {
        if (!selectableValue) {
            return;
        }

        selectedIndexValue = ix;
        delegateValue.setSelectedIndex(ix, window, cast cx);
        scrollToSelectedItem(window, cx);
    }

    /**
     * Set the selected index of the list,
     * this method will not scroll to the selected item.
     */
    public function setSelectedIndex(ix:Null<IndexPath>, window:Window, cx:Context<Dynamic>):Void {
        selectedIndexValue = ix;
        delegateValue.setSelectedIndex(ix, window, cast cx);
    }

    public inline function selectedIndex():Null<IndexPath> {
        return selectedIndexValue;
    }

    /** Set the index of the item that has been right clicked. */
    public function setRightClickedIndex(ix:Null<IndexPath>, window:Window, cx:Context<Dynamic>):Void {
        mouseRightClickedIndex = ix;
        delegateValue.setRightClickedIndex(ix, window, cast cx);
    }

    /** Returns the index of the item that has been right clicked. */
    public inline function rightClickedIndex():Null<IndexPath> {
        return mouseRightClickedIndex;
    }

    /** Set the query text of the search input, this will trigger a search. */
    public function setQuery(query:String, window:Window, cx:Context<Dynamic>):Void {
        (cast queryInput : Entity<InputBaseState>).update(cx, (input, cx) -> {
            input.setValue(query, window, cx);
        });

        // `set_value` does not emit `InputEvent::Change`, so start the search here.
        startSearch(StringTools.trim(query), window, cx);
    }

    /**
     * Set a specific list item for measurement.
     *
     * If the item is absent, measure the first item in the first non-empty section.
     */
    public function setItemToMeasureIndex(ix:IndexPath, _:Window, cx:Context<Dynamic>):Void {
        itemToMeasureIndex = ix;
        cx.notify();
    }

    /** Scroll to the item at the given index. */
    public function scrollToItem(ix:IndexPath, strategy:ScrollStrategy, _:Window, cx:Context<Dynamic>):Void {
        if (ix.section == 0 && ix.row == 0) {
            // If the item is the first item, scroll to the top.
            final offset = scrollHandle.baseHandle().offset();
            scrollHandle.baseHandle().setOffset(new Point(offset.x, 0.));
            cx.notify();
            return;
        }
        deferredScrollToIndex = {ix: ix, strategy: strategy};
        cx.notify();
    }

    /** Get scroll handle */
    public inline function getScrollHandle():VirtualListScrollHandle {
        return scrollHandle;
    }

    public function scrollToSelectedItem(_:Window, cx:Context<Dynamic>):Void {
        if (selectedIndexValue != null) {
            deferredScrollToIndex = {ix: selectedIndexValue, strategy: ScrollStrategy.Top};
            cx.notify();
        }
    }

    function onQueryInputEvent(state:Entity<InputBaseState>, event:InputEvent, window:Window, cx:Context<ListState<D>>):Void {
        switch event {
            case Change:
                final text = StringTools.trim(state.read(cx).value());
                if (lastQuery != null && text == lastQuery) {
                    return;
                }

                startSearch(text, window, cx);
            case _:
        }
    }

    function startSearch(query:String, window:Window, cx:Context<Dynamic>):Void {
        setSearching(true, window, cx);
        final search = delegateValue.performSearch(query, window, cast cx);

        if (rowsCache.len() > 0) {
            _setSelectedIndex(IndexPath.defaultValue(), window, cx);
        } else {
            _setSelectedIndex(null, window, cx);
        }

        if (searchTask != null) searchTask.cancel();
        final ctx:Context<ListState<D>> = cast cx;
        searchTask = ctx.spawn((this_, acx) -> search.then(_ -> {
            this_.tryUpdate(acx, (this_, _) -> {
                this_.scrollHandle.scrollToItem(0, ScrollStrategy.Top);
                this_.lastQuery = query;
            });
        }).andThen(_ -> {
            // Always wait 100ms to avoid flicker
            return acx.backgroundExecutor().timer(0.1);
        }).then(_ -> {
            if (window.isDestroyed()) return;
            this_.tryUpdate(acx, (this_, cx) -> {
                this_.setSearching(false, window, cx);
            });
        }));
    }

    function setSearching(searching:Bool, window:Window, cx:Context<Dynamic>):Void {
        queryInput.update(cx, (input, cx) -> input.setLoading(searching, window, cast cx));
    }

    /**
     * Dispatch delegate's `load_more` method when the
     * visible range is near the end.
     */
    function loadMoreIfNeed(entitiesCount:Int, visibleEnd:Int, window:Window, cx:Context<Dynamic>):Void {
        // FIXME: Here need void sections items count.

        final threshold = delegateValue.loadMoreThreshold();
        // Securely handle subtract logic to prevent attempt
        // to subtract with overflow
        final saturated = entitiesCount - threshold < 0 ? 0 : entitiesCount - threshold;
        if (visibleEnd >= saturated) {
            if (!delegateValue.hasMore(cx.app)) {
                return;
            }

            final ctx:Context<ListState<D>> = cast cx;
            loadMoreTask = ctx.spawn((view, acx) -> {
                if (!window.isDestroyed()) {
                    view.tryUpdate(acx, (view, cx) -> {
                        view.delegateValue.loadMore(window, cast cx);
                    });
                }
                return Task.ready(Unit.unit);
            });
        }
    }

    /** Rust `reset_on_cancel` (crate private builder). */
    public function resetOnCancel(reset:Bool):ListState<D> {
        resetOnCancelValue = reset;
        return this;
    }

    function onActionCancel(_:CancelAction, window:Window, cx:Context<ListState<D>>):Void {
        cx.propagate();
        if (resetOnCancelValue) {
            _setSelectedIndex(null, window, cx);
        }

        delegateValue.cancel(window, cast cx);
        cx.emit(ListEvent.Cancel);
        cx.notify();
    }

    function onActionConfirm(confirm:ConfirmAction, window:Window, cx:Context<ListState<D>>):Void {
        if (rowsCache.len() == 0) {
            return;
        }

        final ix = selectedIndexValue;
        if (ix == null) {
            return;
        }

        delegateValue.setSelectedIndex(selectedIndexValue, window, cast cx);
        delegateValue.confirm(confirm.secondary, window, cast cx);
        cx.emit(ListEvent.Confirm(ix));
        cx.notify();
    }

    function selectItem(ix:IndexPath, window:Window, cx:Context<ListState<D>>):Void {
        if (!selectableValue) {
            return;
        }

        selectedIndexValue = ix;
        delegateValue.setSelectedIndex(ix, window, cast cx);
        scrollToSelectedItem(window, cx);
        cx.emit(ListEvent.Select(ix));
        cx.notify();
    }

    function onActionSelectPrev(_:SelectUp, window:Window, cx:Context<ListState<D>>):Void {
        if (rowsCache.len() == 0) {
            return;
        }

        final prevIx = rowsCache.prev(selectedIndexValue);
        selectItem(prevIx, window, cx);
    }

    function onActionSelectNext(_:SelectDown, window:Window, cx:Context<ListState<D>>):Void {
        if (rowsCache.len() == 0) {
            return;
        }

        final nextIx = rowsCache.next(selectedIndexValue);
        selectItem(nextIx, window, cx);
    }

    function prepareItemsIfNeeded(window:Window, cx:Context<ListState<D>>):Void {
        final sectionsCount = Std.int(Math.max(delegateValue.sectionsCount(cx.app), 1));
        var itemSize = new gpui.Size(0, 0);
        var sectionHeaderSize = new gpui.Size(0, 0);
        var sectionFooterSize = new gpui.Size(0, 0);

        // Measure the item_height and section header/footer height.
        final availableSpace = new SizeOf<AvailableSpace>(MinContent, MinContent);
        // Use the fallback for this measurement without overwriting the caller's configured index.
        final requested = itemToMeasureIndex;
        var itemToMeasure:Null<IndexPath> = null;
        if (requested.section < sectionsCount && requested.row < delegateValue.itemsCount(requested.section, cx.app)) {
            itemToMeasure = requested;
        } else {
            for (section in 0...sectionsCount) {
                if (delegateValue.itemsCount(section, cx.app) > 0) {
                    itemToMeasure = IndexPath.defaultValue().withSection(section);
                    break;
                }
            }
        }
        if (itemToMeasure != null) {
            itemSize = (renderListItem(itemToMeasure, window, cx) : AnyElement).layoutAsRoot(availableSpace, window, cx.app);
        }

        final header = delegateValue.renderSectionHeader(0, window, cast cx);
        if (header != null) {
            sectionHeaderSize = (header : AnyElement).layoutAsRoot(availableSpace, window, cx.app);
        }
        final footer = delegateValue.renderSectionFooter(0, window, cast cx);
        if (footer != null) {
            sectionFooterSize = (footer : AnyElement).layoutAsRoot(availableSpace, window, cx.app);
        }

        final measuredSize = new MeasuredEntrySize(itemSize, sectionHeaderSize, sectionFooterSize);
        final delegate = delegateValue;
        rowsCache.prepareIfNeeded(sectionsCount, measuredSize, cx.app, (sectionIx, cx) -> delegate.itemsCount(sectionIx, cx));
    }

    function renderListItem(ix:IndexPath, window:Window, cx:Context<ListState<D>>):IntoElement {
        final selectable = selectableValue;
        final selected = selectedIndexValue != null ? selectedIndexValue.eqRow(ix) : false;
        final mouseRightClicked = mouseRightClickedIndex != null ? mouseRightClickedIndex.eqRow(ix) : false;
        final id = 'list-item-' + ix.toString();

        // Rust `.role(Role::ListItem)`, `.aria_position_in_set(ix.row + 1)`,
        // `.aria_size_of_set(total_items)`, `.aria_selected(selected)`: no
        // accessibility tree in the port.
        final element = div()
            .id(id)
            .wFull()
            .relative()
            .overflowHidden();
        final item = delegateValue.renderItem(ix, window, cast cx);
        if (item != null) {
            item.setSelected(selected);
            item.setSecondarySelected(mouseRightClicked);
            element.child(item);
        }
        if (selectable) {
            element.onClick(cx.listener((this_:ListState<D>, e:ClickEvent, window, cx) -> {
                this_.setRightClickedIndex(null, window, cx);
                this_.selectedIndexValue = ix;
                this_.onActionConfirm(new ConfirmAction(e.modifiers().secondary()), window, cx);
            })).onMouseDown(Right, cx.listener((this_:ListState<D>, _, window, cx) -> {
                this_.setRightClickedIndex(ix, window, cx);
                cx.notify();
            }));
        }
        return element;
    }

    function renderItems(itemsCount:Int, entitiesCount:Int, window:Window, cx:Context<ListState<D>>):IntoElement {
        final rowsCache = this.rowsCache.clone();
        final scrollbarVisible = options.scrollbarVisible;
        final scrollHandle = this.scrollHandle;
        var itemToMeasureIndex = rowsCache.positionOf(this.itemToMeasureIndex);
        if (itemToMeasureIndex == null) itemToMeasureIndex = rowsCache.firstEntryPosition();
        if (itemToMeasureIndex == null) itemToMeasureIndex = 0;

        final container = vFlex()
            .flexGrow1()
            .relative()
            .sizeFull();
        if (options.maxHeight != null) container.maxH(options.maxHeight);
        container.overflowHidden();
        if (itemsCount == 0) {
            container.child(delegateValue.renderEmpty(window, cast cx));
        }
        if (itemsCount > 0) {
            final list = VirtualList.vVirtualList(cx.entity(), "virtual-list", rowsCache.entriesSizes, (list:ListState<D>, start:Int, end:Int, window:Window, cx:Context<ListState<D>>) -> {
                list.loadMoreIfNeed(entitiesCount, end, window, cx);

                // NOTE: Here the v_virtual_list would not able to have gap_y,
                // because the section header, footer is always have rendered as a empty child item,
                // even the delegate give a None result.

                final rows:Array<IntoElement> = [];
                for (ix in start...end) {
                    final entry = rowsCache.get(ix);
                    if (entry == null) {
                        rows.push(div());
                        continue;
                    }

                    final row = div();
                    final child:Null<IntoElement> = switch entry {
                        case Entry(index): list.renderListItem(index, window, cx);
                        case SectionHeader(sectionIx): list.delegateValue.renderSectionHeader(sectionIx, window, cast cx);
                        case SectionFooter(sectionIx): list.delegateValue.renderSectionFooter(sectionIx, window, cast cx);
                    }
                    if (child != null) row.child(child);
                    rows.push(row);
                }
                return rows;
            })
                .withItemToMeasureIndex(itemToMeasureIndex);
            // Rust `.paddings(self.options.paddings.clone())`: every edge is
            // set, an unset one to zero.
            final zero:DefiniteLength = DefiniteLength.Absolute(gpui.AbsoluteLength.Pixels(0.));
            list.pt(options.paddingTop != null ? options.paddingTop : zero)
                .pb(options.paddingBottom != null ? options.paddingBottom : zero)
                .pl(options.paddingLeft != null ? options.paddingLeft : zero)
                .pr(options.paddingRight != null ? options.paddingRight : zero);
            if (options.maxHeight != null) {
                list.withSizingBehavior(ListSizingBehavior.Infer);
            }
            list.trackScroll(scrollHandle);
            final bounce = new ScrollBounce("list-scroll-bounce", scrollHandle, list);
            if (options.scrollBounce != null) bounce.enabled(options.scrollBounce);
            container.child(bounce);
        }
        if (scrollbarVisible) {
            container.child(Scrollbar.vertical(scrollHandle).viewportFromLayout());
        }
        return container;
    }

    /** Rust `Focusable::focus_handle`. */
    public function focusHandle(cx:App):FocusHandle {
        if (searchableValue) {
            return queryInput.read(cx).focusHandle;
        } else {
            return focusHandleValue;
        }
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<ListState<D>> = cast cx;
        prepareItemsIfNeeded(window, cx);

        // Scroll to the selected item if it is set.
        if (deferredScrollToIndex != null) {
            final deferred = deferredScrollToIndex;
            deferredScrollToIndex = null;
            final itemIx = rowsCache.positionOf(deferred.ix);
            if (itemIx != null) {
                scrollHandle.scrollToItem(itemIx, deferred.strategy);
            }
        }

        final loading = delegate().loading(cx.app);
        var queryInput:Null<Entity<InputState>> = null;
        if (searchableValue) {
            // sync placeholder
            if (options.searchPlaceholder != null) {
                final placeholder = options.searchPlaceholder;
                (cast this.queryInput : Entity<InputBaseState>).update(cx, (input, cx) -> {
                    input.setPlaceholder(placeholder, window, cx);
                });
            }
            queryInput = this.queryInput;
        }

        final loadingView:Null<AnyElement> = loading ? (delegateValue.renderLoading(window, cast cx) : AnyElement) : null;
        var initialView:Null<AnyElement> = null;
        if (queryInput != null) {
            if (queryInput.read(cx).value().length == 0) {
                initialView = delegateValue.renderInitial(window, cast cx);
            }
        }
        final itemsCount = rowsCache.itemsCount();
        final entitiesCount = rowsCache.len();
        final mouseRightClickedIndex = this.mouseRightClickedIndex;
        final theme = Theme.global(cx);

        // Rust `.role(Role::List)`: no accessibility tree in the port.
        final root = vFlex()
            .keyContext(CONTEXT)
            .id("list-state")
            .trackFocus(focusHandleValue)
            .sizeFull()
            .relative()
            .overflowHidden();
        if (queryInput != null) {
            final wrapper = div();
            switch options.size {
                case Small: wrapper.px1p5();
                case _: wrapper.px2();
            }
            root.child(wrapper
                .borderB1()
                .borderColor(theme.border)
                .child(new Input(queryInput)
                    .withSize(options.size)
                    .prefix(new Icon(IconName.Search).textColor(theme.mutedForeground))
                    .cleanable(true)
                    .p0()
                    .appearance(false)));
        }
        if (!loading) {
            root.onAction(CancelAction, cx.listener(onActionCancelListener))
                .onAction(ConfirmAction, cx.listener(onActionConfirmListener))
                .onAction(SelectDown, cx.listener(onActionSelectNextListener))
                .onAction(SelectUp, cx.listener(onActionSelectPrevListener));
            if (initialView != null) {
                root.child(initialView);
            } else {
                root.child(renderItems(itemsCount, entitiesCount, window, cx));
            }
            // Click out to cancel right clicked row
            if (mouseRightClickedIndex != null) {
                root.onMouseDownOut(cx.listener((this_:ListState<D>, _, window, cx) -> {
                    this_.setRightClickedIndex(null, window, cx);
                    cx.notify();
                }));
            }
        }
        if (loadingView != null) root.child(loadingView);
        return root;
    }

    static function onActionCancelListener<D:ListDelegate>(this_:ListState<D>, action:CancelAction, window:Window, cx:Context<ListState<D>>):Void {
        this_.onActionCancel(action, window, cx);
    }

    static function onActionConfirmListener<D:ListDelegate>(this_:ListState<D>, action:ConfirmAction, window:Window, cx:Context<ListState<D>>):Void {
        this_.onActionConfirm(action, window, cx);
    }

    static function onActionSelectNextListener<D:ListDelegate>(this_:ListState<D>, action:SelectDown, window:Window, cx:Context<ListState<D>>):Void {
        this_.onActionSelectNext(action, window, cx);
    }

    static function onActionSelectPrevListener<D:ListDelegate>(this_:ListState<D>, action:SelectUp, window:Window, cx:Context<ListState<D>>):Void {
        this_.onActionSelectPrev(action, window, cx);
    }

}
